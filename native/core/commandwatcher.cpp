// SPDX-License-Identifier: GPL-2.0-or-later
#include "commandwatcher.h"

#include <QDateTime>
#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QUrl>

#include <unistd.h>

CommandWatcher::CommandWatcher(QObject *parent)
    : QObject(parent)
{
    connect(&m_timer, &QTimer::timeout, this, &CommandWatcher::scan);
}

void CommandWatcher::setEnabled(bool enabled)
{
    if (m_enabled == enabled) {
        return;
    }
    m_enabled = enabled;
    Q_EMIT enabledChanged();
    if (enabled) {
        m_timer.start(m_idleInterval);
        QTimer::singleShot(0, this, &CommandWatcher::scan);
    } else {
        m_timer.stop();
        const bool had = !m_tracked.isEmpty();
        m_tracked.clear();
        m_ignored.clear();
        if (had) {
            Q_EMIT countChanged();
        }
    }
}

void CommandWatcher::setCommands(const QVariantList &commands)
{
    m_commandList = commands;
    m_commands.clear();
    for (const QVariant &v : commands) {
        const QVariantMap m = v.toMap();
        const QString name = m.value(QStringLiteral("name")).toString().trimmed();
        if (name.isEmpty()) {
            continue;
        }
        Command c;
        c.kind = m.value(QStringLiteral("kind"), QStringLiteral("download")).toString();
        c.actions = m.value(QStringLiteral("actions")).toStringList();
        m_commands.insert(name, c);
    }
    m_ignored.clear();
    Q_EMIT commandsChanged();
}

QVariantMap CommandWatcher::describeAddress(const QString &address)
{
    QVariantMap out;
    QString host, path;
    static const QRegularExpression scp(QStringLiteral("^(?:[^@/\\s]+@)?([A-Za-z0-9.-]+):(?!/)([^\\s]+)$"));
    if (address.contains(QLatin1String("://"))) {
        const QUrl url(address);
        host = url.host();
        path = url.path();
    } else {
        const auto m = scp.match(address);
        if (!m.hasMatch()) {
            return out;
        }
        host = m.captured(1);
        path = m.captured(2);
    }
    if (host.isEmpty()) {
        return out;
    }
    out.insert(QStringLiteral("host"), host);
    // The last two parts of the path name a repository ("owner/repo"); nothing else of it is kept.
    QStringList parts = path.split(QLatin1Char('/'), Qt::SkipEmptyParts);
    if (!parts.isEmpty()) {
        QString last = parts.takeLast();
        if (last.endsWith(QLatin1String(".git"))) {
            last.chop(4);
        }
        out.insert(QStringLiteral("name"), last);
        out.insert(QStringLiteral("repo"), parts.isEmpty() ? last : parts.last() + QLatin1Char('/') + last);
    }
    return out;
}

bool CommandWatcher::readProcess(int pid, Process &p) const
{
    QFile stat(QStringLiteral("%1/%2/stat").arg(m_procRoot).arg(pid));
    if (!stat.open(QIODevice::ReadOnly)) {
        return false;
    }
    const QByteArray line = stat.readAll();
    // "pid (name with ) and spaces) S ppid pgrp session tty_nr … starttime(22)"
    const int open = line.indexOf('('), close = line.lastIndexOf(')');
    if (open < 0 || close < open) {
        return false;
    }
    const QList<QByteArray> rest = line.mid(close + 2).split(' ');
    if (rest.size() < 20) {
        return false;
    }
    p.pid = pid;
    p.name = QString::fromUtf8(line.mid(open + 1, close - open - 1));
    p.parent = rest.at(1).toInt();
    p.tty = rest.at(4).toInt();
    p.startTime = rest.at(19).toULongLong();
    return true;
}

// Never leaves this file: see the note on command lines in the header.
QStringList CommandWatcher::arguments(int pid) const
{
    QFile file(QStringLiteral("%1/%2/cmdline").arg(m_procRoot).arg(pid));
    if (!file.open(QIODevice::ReadOnly)) {
        return {};
    }
    QStringList out;
    const QList<QByteArray> parts = file.read(16384).split('\0');
    for (const QByteArray &part : parts) {
        out << QString::fromUtf8(part);
    }
    while (!out.isEmpty() && out.last().isEmpty()) {
        out.removeLast();
    }
    return out;
}

static bool isOption(const QString &a) { return a.startsWith(QLatin1Char('-')); }

void CommandWatcher::consider(const Process &p)
{
    const QString key = QStringLiteral("%1:%2").arg(p.pid).arg(p.startTime);
    if (m_ignored.contains(key)) {
        return;
    }
    QStringList args = arguments(p.pid);
    QString name = p.name;
    // A script: the process is named after what runs it ("node …/npm-cli.js", "python3 /usr/bin/pip").
    static const QRegularExpression runner(QStringLiteral("^(python[0-9.]*|node|nodejs)$"));
    if (!m_commands.contains(name)) {
        if (args.size() < 2 || !runner.match(name).hasMatch()) {
            return;
        }
        QString script = QFileInfo(args.at(1)).fileName();
        script.remove(QRegularExpression(QStringLiteral("(-cli)?\\.(js|py)$")));
        if (!m_commands.contains(script)) {
            return;
        }
        name = script;
        args.removeFirst();
    }
    const Command command = m_commands.value(name);
    args.removeFirst();

    Tracked t;
    t.name = name;
    t.kind = command.kind;
    QVariantMap where;
    if (t.kind == QLatin1String("clone")) {
        // git [-c x] [-C dir] clone [options] <address> [<folder>]
        static const QStringList gitValued = {QStringLiteral("-c"), QStringLiteral("-C"), QStringLiteral("--git-dir"), QStringLiteral("--work-tree"),
                                              QStringLiteral("--namespace"), QStringLiteral("--exec-path")};
        static const QStringList cloneValued = {QStringLiteral("-b"), QStringLiteral("--branch"), QStringLiteral("-o"), QStringLiteral("--origin"),
                                                QStringLiteral("-u"), QStringLiteral("--upload-pack"), QStringLiteral("--reference"),
                                                QStringLiteral("--reference-if-able"), QStringLiteral("--separate-git-dir"), QStringLiteral("--depth"),
                                                QStringLiteral("--template"), QStringLiteral("-c"), QStringLiteral("--config"), QStringLiteral("-j"),
                                                QStringLiteral("--jobs"), QStringLiteral("--shallow-since"), QStringLiteral("--shallow-exclude"),
                                                QStringLiteral("--filter"), QStringLiteral("--bundle-uri"), QStringLiteral("--revision")};
        int i = 0;
        QString startDir;
        for (; i < args.size() && isOption(args.at(i)); ++i) {
            if (gitValued.contains(args.at(i))) {
                if (args.at(i) == QLatin1String("-C") && i + 1 < args.size()) {
                    startDir = args.at(i + 1);
                }
                ++i;
            }
        }
        if (i >= args.size() || args.at(i) != QLatin1String("clone")) {
            m_ignored.insert(key);      // git's own helpers (index-pack, remote-https), other sub-commands
            return;
        }
        t.action = QStringLiteral("clone");
        QStringList plain;
        for (++i; i < args.size(); ++i) {
            if (args.at(i) == QLatin1String("--")) {
                continue;
            }
            if (isOption(args.at(i))) {
                if (cloneValued.contains(args.at(i))) {
                    ++i;
                }
                continue;
            }
            plain << args.at(i);
        }
        if (plain.isEmpty()) {
            m_ignored.insert(key);
            return;
        }
        where = describeAddress(plain.at(0));
        QString folder = plain.size() > 1 ? plain.at(1) : where.value(QStringLiteral("name")).toString();
        if (folder.isEmpty()) {
            folder = QFileInfo(plain.at(0)).fileName();     // a local path
            if (folder.endsWith(QLatin1String(".git"))) {
                folder.chop(4);
            }
        }
        QString cwd = QFile::symLinkTarget(QStringLiteral("%1/%2/cwd").arg(m_procRoot).arg(p.pid));
        if (!startDir.isEmpty()) {
            cwd = QDir(cwd).absoluteFilePath(startDir);
        }
        if (!cwd.isEmpty() && !folder.isEmpty()) {
            t.target = QDir::cleanPath(QDir(cwd).absoluteFilePath(folder));
        }
    } else {
        // the sub-command: the first argument that is not an option
        for (const QString &a : std::as_const(args)) {
            if (!isOption(a)) {
                t.action = a.contains(QLatin1String("://")) || a.contains(QLatin1Char('/')) || a.contains(QLatin1Char('@')) ? QString() : a;
                break;
            }
        }
        if (!command.actions.isEmpty() && !command.actions.contains(t.action)) {
            m_ignored.insert(key);      // "apt list", "pip --version"…
            return;
        }
        // Only a sub-command that was asked for by name is passed on: anything else might be
        // the value of an option (a password, say).
        if (command.actions.isEmpty()) {
            t.action.clear();
        }
        if (t.kind != QLatin1String("packages")) {
            for (const QString &a : std::as_const(args)) {
                if (a.contains(QLatin1String("://"))) {
                    where = describeAddress(a.mid(qMax(0, a.indexOf(QRegularExpression(QStringLiteral("[a-z][a-z0-9+.-]*://"))))));
                    break;
                }
            }
        }
    }
    args.clear();

    const bool background = p.tty == 0;
    if (background && !m_showBackground) {
        m_ignored.insert(key);
        return;
    }
    t.id = QString::number(m_next++);
    t.pid = p.pid;
    t.startTime = p.startTime;
    t.own = QFileInfo(QStringLiteral("%1/%2").arg(m_procRoot).arg(p.pid)).ownerId() == ::getuid();
    t.startedAt = QDateTime::currentMSecsSinceEpoch();
    t.lastSample = t.startedAt;
    if (t.kind == QLatin1String("packages")) {
        const auto debs = QDir(sys("/var/cache/apt/archives")).entryList({QStringLiteral("*.deb")}, QDir::Files);
        t.archives = QSet<QString>(debs.begin(), debs.end());
        t.historySize = QFileInfo(sys("/var/log/apt/history.log")).size();
        t.stamp = QFileInfo(sys("/var/lib/apt/periodic/update-success-stamp")).lastModified().toMSecsSinceEpoch();
    }
    m_tracked.append(t);

    QVariantMap info;
    info.insert(QStringLiteral("name"), t.name);
    info.insert(QStringLiteral("kind"), t.kind);
    info.insert(QStringLiteral("action"), t.action);
    info.insert(QStringLiteral("host"), where.value(QStringLiteral("host")).toString());
    info.insert(QStringLiteral("repo"), t.kind == QLatin1String("clone") ? where.value(QStringLiteral("repo")).toString() : QString());
    info.insert(QStringLiteral("background"), background);
    info.insert(QStringLiteral("own"), t.own);
    Q_EMIT started(t.id, info);
}

qint64 CommandWatcher::archiveBytes(const Tracked &t) const
{
    qint64 sum = 0;
    const auto debs = QDir(sys("/var/cache/apt/archives")).entryInfoList({QStringLiteral("*.deb")}, QDir::Files);
    for (const QFileInfo &fi : debs) {
        if (!t.archives.contains(fi.fileName())) {
            sum += fi.size();
        }
    }
    return sum;
}

void CommandWatcher::update(Tracked &t, const QList<Process> &all)
{
    qint64 bytes = t.bytes;
    QString stage = t.stage;
    if (t.kind == QLatin1String("clone")) {
        if (!t.target.isEmpty()) {
            const auto packs = QDir(t.target + QLatin1String("/.git/objects/pack")).entryInfoList({QStringLiteral("tmp_pack_*")}, QDir::Files | QDir::Hidden);
            for (const QFileInfo &fi : packs) {
                bytes = qMax(bytes, fi.size());
            }
        }
    } else if (t.kind == QLatin1String("packages")) {
        // apt's children: its download methods (run as _apt), then dpkg
        static const QStringList methods = {QStringLiteral("http"), QStringLiteral("https"), QStringLiteral("mirror"), QStringLiteral("ftp"),
                                            QStringLiteral("store"), QStringLiteral("gpgv"), QStringLiteral("rred"), QStringLiteral("copy"),
                                            QStringLiteral("file")};
        QSet<int> family = {t.pid};
        bool fetching = false, installing = false;
        for (int round = 0; round < 3; ++round) {
            for (const Process &p : all) {
                if (family.contains(p.parent)) {
                    family.insert(p.pid);
                }
            }
        }
        for (const Process &p : all) {
            if (p.pid == t.pid || !family.contains(p.pid)) {
                continue;
            }
            if (p.name == QLatin1String("dpkg") || p.name.startsWith(QLatin1String("dpkg-"))) {
                installing = true;
            } else if (methods.contains(p.name)) {
                fetching = true;
            }
        }
        if (installing) {
            stage = QStringLiteral("install");
        } else if (fetching) {
            stage = t.action == QLatin1String("update") ? QStringLiteral("lists") : QStringLiteral("download");
        }
        bytes = qMax(bytes, archiveBytes(t));
    } else if (t.own) {
        QFile io(QStringLiteral("%1/%2/io").arg(m_procRoot).arg(t.pid));
        if (io.open(QIODevice::ReadOnly)) {
            const QList<QByteArray> lines = io.readAll().split('\n');
            for (const QByteArray &line : lines) {
                if (line.startsWith("wchar:")) {
                    const qint64 written = line.mid(6).trimmed().toLongLong();
                    if (t.base < 0) {
                        t.base = 0;     // (seen within its first seconds: what it wrote before counts)
                    }
                    bytes = qMax(bytes, written - t.base);
                }
            }
        }
    }
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    const qint64 ms = qMax<qint64>(1, now - t.lastSample);
    if (ms >= 200) {
        const double instant = qMax<qint64>(0, bytes - t.bytes) * 1000.0 / ms;
        t.speed = t.speed <= 0 ? instant : t.speed * 0.7 + instant * 0.3;
        if (t.speed < 1) {
            t.speed = 0;
        }
        t.lastSample = now;
        t.bytes = bytes;
    }
    t.stage = stage;
    Q_EMIT progress(t.id, t.bytes, qint64(t.speed), t.stage);
}

QString CommandWatcher::outcome(const Tracked &t) const
{
    if (t.kind == QLatin1String("clone")) {
        if (t.target.isEmpty()) {
            return QStringLiteral("unknown");
        }
        if (QFileInfo::exists(t.target + QLatin1String("/.git/HEAD")) || QFileInfo::exists(t.target + QLatin1String("/HEAD"))) {
            return QStringLiteral("done");
        }
        return QFileInfo::exists(t.target) ? QStringLiteral("unknown") : QStringLiteral("failed");
    }
    if (t.kind == QLatin1String("packages")) {
        if (t.action == QLatin1String("update")) {
            // apt touches this stamp after an update that went through
            const qint64 stamp = QFileInfo(sys("/var/lib/apt/periodic/update-success-stamp")).lastModified().toMSecsSinceEpoch();
            return stamp > t.stamp && stamp >= t.startedAt - 2000 ? QStringLiteral("done") : QStringLiteral("unknown");
        }
        QFile history(sys("/var/log/apt/history.log"));
        if (history.size() > t.historySize && history.open(QIODevice::ReadOnly) && history.seek(t.historySize)) {
            const QByteArray added = history.read(1 << 20);
            if (added.contains("\nError:") || added.startsWith("Error:")) {
                return QStringLiteral("failed");
            }
            if (added.contains("End-Date:")) {
                return QStringLiteral("done");
            }
        }
    }
    return QStringLiteral("unknown");
}

void CommandWatcher::scan()
{
    if (!m_enabled) {
        return;
    }
    QElapsedTimer clock;
    clock.start();
    const int before = m_tracked.size();
    // While apt runs, every process is read (its children tell the stage); else only names.
    bool family = false;
    for (const Tracked &t : std::as_const(m_tracked)) {
        family = family || t.kind == QLatin1String("packages");
    }
    QList<Process> all;
    QSet<QString> alive;
    const QStringList entries = QDir(m_procRoot).entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &entry : entries) {
        bool ok = false;
        const int pid = entry.toInt(&ok);
        if (!ok) {
            continue;
        }
        Process p;
        if (!family) {
            // the cheap look first: the name only
            QFile comm(QStringLiteral("%1/%2/comm").arg(m_procRoot, entry));
            if (!comm.open(QIODevice::ReadOnly)) {
                continue;
            }
            const QString name = QString::fromUtf8(comm.readAll()).trimmed();
            static const QRegularExpression runner(QStringLiteral("^(python[0-9.]*|node|nodejs)$"));
            if (!m_commands.contains(name) && !runner.match(name).hasMatch()) {
                continue;
            }
        }
        if (!readProcess(pid, p)) {
            continue;
        }
        const QString key = QStringLiteral("%1:%2").arg(p.pid).arg(p.startTime);
        alive.insert(key);
        if (family) {
            all.append(p);
        }
        bool known = false;
        for (const Tracked &t : std::as_const(m_tracked)) {
            known = known || (t.pid == p.pid && t.startTime == p.startTime);
        }
        if (!known) {
            consider(p);
        }
    }
    m_ignored.intersect(alive);

    for (auto it = m_tracked.begin(); it != m_tracked.end();) {
        Process p;
        if (readProcess(it->pid, p) && p.startTime == it->startTime) {
            update(*it, all);
            ++it;
            continue;
        }
        // It has ended. One last look at what it left, then how it ended, from its records only.
        if (it->kind != QLatin1String("download")) {
            if (it->kind == QLatin1String("packages")) {
                it->bytes = qMax(it->bytes, archiveBytes(*it));
            }
        }
        const QString how = outcome(*it);
        Q_EMIT finished(it->id, how, it->bytes, it->kind == QLatin1String("clone") && how == QLatin1String("done") ? it->target : QString());
        it = m_tracked.erase(it);
    }

    const int interval = m_tracked.isEmpty() ? m_idleInterval : m_activeInterval;
    if (m_timer.interval() != interval) {
        m_timer.start(interval);
    }
    if (m_tracked.size() != before) {
        Q_EMIT countChanged();
    }
    m_lastScan = int(clock.nsecsElapsed() / 1000);
    Q_EMIT scanned();
}
