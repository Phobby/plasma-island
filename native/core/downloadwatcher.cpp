// SPDX-License-Identifier: GPL-2.0-or-later
#include "downloadwatcher.h"

#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QUrl>

#include <sys/stat.h>
#include <sys/xattr.h>

static const QStringList s_suffixes = {QStringLiteral(".part"), QStringLiteral(".crdownload"), QStringLiteral(".opdownload"),
                                       QStringLiteral(".download"), QStringLiteral(".partial")};

static bool isPartialName(const QString &name)
{
    for (const QString &s : s_suffixes) {
        if (name.endsWith(s)) {
            return true;
        }
    }
    return false;
}

static QString withoutSuffix(const QString &name)
{
    for (const QString &s : s_suffixes) {
        if (name.endsWith(s)) {
            return name.chopped(s.size());
        }
    }
    return name;
}

static quint64 inodeOf(const QString &path, qint64 *size = nullptr)
{
    struct stat st;
    if (::lstat(QFile::encodeName(path).constData(), &st) != 0 || !S_ISREG(st.st_mode)) {
        return 0;
    }
    if (size) {
        *size = st.st_size;
    }
    return st.st_ino;
}

DownloadWatcher::DownloadWatcher(QObject *parent)
    : QObject(parent)
{
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &DownloadWatcher::scan);
    m_sampler.setInterval(1000);
    connect(&m_sampler, &QTimer::timeout, this, &DownloadWatcher::sample);
    QTimer::singleShot(0, this, &DownloadWatcher::rewatch);
}

void DownloadWatcher::setEnabled(bool enabled)
{
    if (m_enabled == enabled) {
        return;
    }
    m_enabled = enabled;
    Q_EMIT enabledChanged();
    rewatch();
}

void DownloadWatcher::setDirectories(const QStringList &dirs)
{
    if (m_directories == dirs) {
        return;
    }
    m_directories = dirs;
    rewatch();
}

void DownloadWatcher::setSampleInterval(int ms)
{
    ms = qMax(50, ms);
    if (ms == m_sampler.interval()) {
        return;
    }
    m_sampler.setInterval(ms);
    Q_EMIT sampleIntervalChanged();
}

void DownloadWatcher::rewatch()
{
    if (!m_watcher.directories().isEmpty()) {
        m_watcher.removePaths(m_watcher.directories());
    }
    const bool had = !m_partials.isEmpty();
    m_partials.clear();
    m_sampler.stop();
    if (had) {
        Q_EMIT countChanged();
    }
    if (m_enabled) {
        QStringList dirs = m_directories;
        if (dirs.isEmpty()) {
            dirs << QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
        }
        for (QString d : std::as_const(dirs)) {
            if (d == QLatin1String("~") || d.startsWith(QLatin1String("~/"))) {
                d = QDir::homePath() + d.mid(1);
            }
            if (QFileInfo(d).isDir()) {
                m_watcher.addPath(QDir(d).absolutePath());
            }
        }
        scan();
    }
    Q_EMIT directoriesChanged();
}

QString DownloadWatcher::displayName(const QString &directory, const QString &partialName)
{
    const QString name = withoutSuffix(partialName);
    static const QRegularExpression unconfirmed(QStringLiteral("^Unconfirmed \\d+$"));
    if (unconfirmed.match(name).hasMatch()) {
        return {};
    }
    // Firefox: "name.<8 random characters>.ext.part" beside an empty "name.ext"
    static const QRegularExpression token(QStringLiteral("^(.+)\\.[A-Za-z0-9_-]{8}(\\.[^.]+)?$"));
    const auto m = token.match(name);
    if (m.hasMatch()) {
        const QString plain = m.captured(1) + m.captured(2);
        if (QFileInfo::exists(QDir(directory).filePath(plain))) {
            return plain;
        }
    }
    return name;
}

QString DownloadWatcher::originHost(const QString &path)
{
    char buffer[4096];
    const ssize_t n = ::getxattr(QFile::encodeName(path).constData(), "user.xdg.origin.url", buffer, sizeof(buffer));
    if (n <= 0) {
        return {};
    }
    // Only the host is taken; the rest of the address (path, query, credentials) is dropped here.
    return QUrl(QString::fromUtf8(buffer, n).trimmed()).host();
}

// Which process has the file open (e.g. "zen", "firefox", "chrome").
QString DownloadWatcher::applicationFor(const QString &path)
{
    const QString canonical = QFileInfo(path).absoluteFilePath();
    const QDir proc(QStringLiteral("/proc"));
    const auto pids = proc.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &pid : pids) {
        bool ok = false;
        pid.toInt(&ok);
        if (!ok) {
            continue;
        }
        const QDir fdDir(QStringLiteral("/proc/%1/fd").arg(pid));
        // fd entries are symlinks; list them without following (other users'
        // processes simply fail to list).
        const auto fds = fdDir.entryList(QDir::AllEntries | QDir::System | QDir::Hidden | QDir::NoDotAndDotDot);
        for (const QString &fd : fds) {
            if (QFile::symLinkTarget(fdDir.filePath(fd)) == canonical) {
                QFile comm(QStringLiteral("/proc/%1/comm").arg(pid));
                if (comm.open(QIODevice::ReadOnly)) {
                    QString name = QString::fromUtf8(comm.readAll()).trimmed();
                    // Firefox-family child processes are named after their role.
                    if (name == QLatin1String("Socket Process") || name == QLatin1String("Web Content") || name.isEmpty()) {
                        continue;
                    }
                    return name;
                }
            }
        }
    }
    return {};
}

void DownloadWatcher::end(Partial &p, const QString &finalPath, const QString &outcome)
{
    qint64 size = p.bytes;
    if (outcome == QLatin1String("done")) {
        inodeOf(finalPath, &size);
    }
    Q_EMIT finished(p.id, finalPath, outcome, size, outcome == QLatin1String("done") ? originHost(finalPath) : QString());
}

void DownloadWatcher::scan()
{
    const int before = m_partials.size();
    // The partial files that are there now, by their file (inode).
    QHash<quint64, QString> partialFiles;
    const QStringList dirs = m_watcher.directories();
    for (const QString &d : dirs) {
        QStringList filters;
        for (const QString &s : s_suffixes) {
            filters << QLatin1Char('*') + s;
        }
        const auto files = QDir(d).entryInfoList(filters, QDir::Files | QDir::Hidden);
        for (const QFileInfo &fi : files) {
            const quint64 inode = inodeOf(fi.absoluteFilePath());
            if (inode != 0) {
                partialFiles.insert(inode, fi.absoluteFilePath());
            }
        }
    }

    for (auto it = m_partials.begin(); it != m_partials.end();) {
        Partial &p = *it;
        const QString directory = QFileInfo(p.path).absolutePath();
        const auto still = partialFiles.constFind(p.inode);
        if (still != partialFiles.constEnd()) {
            // there, perhaps under another partial name
            if (*still != p.path) {
                p.path = *still;
            }
            p.gone.invalidate();
            const QString name = displayName(directory, QFileInfo(p.path).fileName());
            if (name != p.name) {
                p.name = name;
                Q_EMIT renamed(p.id, name);
            }
            partialFiles.remove(p.inode);
            ++it;
            continue;
        }
        // Not a partial file any more. The same file under another name: that is the download.
        QString final;
        QFileInfoList others;
        if (dirs.contains(directory)) {
            others = QDir(directory).entryInfoList(QDir::Files | QDir::Hidden);
        }
        for (const QFileInfo &fi : std::as_const(others)) {
            if (!isPartialName(fi.fileName()) && inodeOf(fi.absoluteFilePath()) == p.inode) {
                final = fi.absoluteFilePath();
                break;
            }
        }
        if (final.isEmpty()) {
            // Written anew under its final name? A file of at least the size seen, not older than
            // the download, named like it ("name.ext", "name(1).ext", "name (1).ext").
            const QFileInfo shown(p.name);
            const QString stem = shown.completeBaseName(), ext = shown.suffix().isEmpty() ? QString() : QLatin1Char('.') + shown.suffix();
            const QRegularExpression like(QLatin1Char('^') + QRegularExpression::escape(stem) + QStringLiteral("( ?\\(\\d+\\))?")
                                          + QRegularExpression::escape(ext) + QLatin1Char('$'));
            for (const QFileInfo &fi : std::as_const(others)) {
                if (!p.name.isEmpty() && !isPartialName(fi.fileName()) && fi.size() > 0 && fi.size() >= p.bytes
                    && fi.lastModified().toMSecsSinceEpoch() >= p.startedAt - 2000 && like.match(fi.fileName()).hasMatch()) {
                    final = fi.absoluteFilePath();
                    break;
                }
            }
        }
        if (!final.isEmpty()) {
            end(p, final, QStringLiteral("done"));
            it = m_partials.erase(it);
            continue;
        }
        if (!p.gone.isValid()) {
            p.gone.start();
        }
        if (p.gone.elapsed() >= m_settleTime) {
            end(p, QString(), QStringLiteral("cancelled"));
            it = m_partials.erase(it);
            continue;
        }
        ++it;
    }

    // Partial files nobody follows yet.
    for (auto it = partialFiles.constBegin(); it != partialFiles.constEnd(); ++it) {
        const QFileInfo fi(it.value());
        Partial p;
        p.id = QString::number(m_next++);
        p.path = it.value();
        p.inode = it.key();
        p.bytes = fi.size();
        p.name = displayName(fi.absolutePath(), fi.fileName());
        p.startedAt = QDateTime::currentMSecsSinceEpoch();
        p.clock.start();
        p.still.start();
        m_partials.append(p);
        QString app = applicationFor(p.path);
        if (app.isEmpty() && p.path.endsWith(QLatin1String(".crdownload"))) {
            app = QStringLiteral("Chromium");
        }
        Q_EMIT started(p.id, p.name, app);
    }

    if (m_partials.isEmpty()) {
        m_sampler.stop();
    } else if (!m_sampler.isActive()) {
        m_sampler.start();
    }
    if (m_partials.size() != before) {
        Q_EMIT countChanged();
    }
}

void DownloadWatcher::sample()
{
    for (Partial &p : m_partials) {
        if (p.gone.isValid()) {
            continue;
        }
        qint64 size = p.bytes;
        if (inodeOf(p.path, &size) == 0) {
            continue;       // renamed since the last look: scan() below finds it
        }
        const qint64 ms = qMax<qint64>(1, p.clock.restart());
        const double instant = qMax<qint64>(0, size - p.bytes) * 1000.0 / ms;
        // An exponential moving average, so the number does not jump every second.
        p.speed = p.speed <= 0 ? instant : p.speed * 0.7 + instant * 0.3;
        if (size != p.bytes) {
            p.still.restart();
        } else if (p.still.elapsed() > 3000) {
            p.speed = 0;
        }
        p.bytes = size;
        Q_EMIT progress(p.id, size, qint64(p.speed), int(p.still.elapsed() / 1000));
    }
    // inotify may miss a rename between two samples on some filesystems; and a file that
    // vanished is waited for here.
    scan();
}
