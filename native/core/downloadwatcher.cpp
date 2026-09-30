// SPDX-License-Identifier: GPL-2.0-or-later
#include "downloadwatcher.h"

#include <QDir>
#include <QFileInfo>
#include <QStandardPaths>

static const QStringList s_suffixes = {QStringLiteral(".part"), QStringLiteral(".crdownload"), QStringLiteral(".download"), QStringLiteral(".partial")};

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

void DownloadWatcher::rewatch()
{
    if (!m_watcher.directories().isEmpty()) {
        m_watcher.removePaths(m_watcher.directories());
    }
    m_partials.clear();
    m_sampler.stop();
    if (m_enabled) {
        QStringList dirs = m_directories;
        if (dirs.isEmpty()) {
            dirs << QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
        }
        for (const QString &d : std::as_const(dirs)) {
            if (QFileInfo(d).isDir()) {
                m_watcher.addPath(d);
            }
        }
        scan();
    }
    Q_EMIT directoriesChanged();
}

QString DownloadWatcher::finalPathFor(const QString &partialPath)
{
    for (const QString &s : s_suffixes) {
        if (partialPath.endsWith(s)) {
            return partialPath.chopped(s.size());
        }
    }
    return partialPath;
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

void DownloadWatcher::scan()
{
    QHash<QString, bool> present;
    for (const QString &d : m_watcher.directories()) {
        const QDir dir(d);
        QStringList filters;
        for (const QString &s : s_suffixes) {
            filters << QLatin1Char('*') + s;
        }
        const auto files = dir.entryInfoList(filters, QDir::Files | QDir::Hidden);
        for (const QFileInfo &fi : files) {
            const QString path = fi.absoluteFilePath();
            present.insert(path, true);
            if (!m_partials.contains(path)) {
                Partial p;
                p.finalPath = finalPathFor(path);
                p.bytes = fi.size();
                p.clock.start();
                m_partials.insert(path, p);
                QString app = applicationFor(path);
                if (app.isEmpty()) {
                    app = path.endsWith(QLatin1String(".crdownload")) ? QStringLiteral("Chromium") : QString();
                }
                Q_EMIT started(path, QFileInfo(p.finalPath).fileName(), app);
            }
        }
    }
    // Partial files that went away: renamed to the final name (done) or deleted (cancelled).
    for (auto it = m_partials.begin(); it != m_partials.end();) {
        if (!present.contains(it.key())) {
            const QFileInfo final(it->finalPath);
            const bool success = final.exists() && final.size() > 0;
            Q_EMIT finished(it.key(), it->finalPath, success);
            it = m_partials.erase(it);
        } else {
            ++it;
        }
    }
    if (m_partials.isEmpty()) {
        m_sampler.stop();
    } else if (!m_sampler.isActive()) {
        m_sampler.start();
    }
}

void DownloadWatcher::sample()
{
    for (auto it = m_partials.begin(); it != m_partials.end(); ++it) {
        const qint64 size = QFileInfo(it.key()).size();
        const qint64 ms = qMax<qint64>(1, it->clock.restart());
        const qint64 instant = qMax<qint64>(0, (size - it->bytes) * 1000 / ms);
        // Smooth the rate a little so the text does not jump every second.
        it->speed = it->speed == 0 ? instant : (it->speed * 2 + instant) / 3;
        it->bytes = size;
        Q_EMIT progress(it.key(), size, it->speed);
    }
    // inotify may miss a rename between two samples on some filesystems.
    scan();
}
