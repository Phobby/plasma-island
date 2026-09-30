// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QElapsedTimer>
#include <QFileSystemWatcher>
#include <QHash>
#include <QObject>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

/*
 * Browser downloads that never become KDE jobs (e.g. Flatpak browsers, which
 * cannot reach Plasma Browser Integration): watches download folders for
 * partial files — Firefox/Zen/LibreWolf "*.part", Chromium/Chrome/Brave/Edge
 * "*.crdownload", Safari-style "*.download", "*.partial" — and reports their
 * growth. Browsers don't write the final size anywhere, so there is no
 * percentage or ETA here, only downloaded bytes and speed.
 *
 * Event driven: QFileSystemWatcher (inotify) on the folders; file sizes are
 * sampled once per second only while a partial file exists.
 */
class DownloadWatcher : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool enabled READ isEnabled WRITE setEnabled NOTIFY enabledChanged)
    // Empty = the XDG download folder.
    Q_PROPERTY(QStringList directories READ directories WRITE setDirectories NOTIFY directoriesChanged)
    Q_PROPERTY(QStringList watchedDirectories READ watchedDirectories NOTIFY directoriesChanged)

public:
    explicit DownloadWatcher(QObject *parent = nullptr);

    bool isEnabled() const { return m_enabled; }
    void setEnabled(bool enabled);
    QStringList directories() const { return m_directories; }
    void setDirectories(const QStringList &dirs);
    QStringList watchedDirectories() const { return m_watcher.directories(); }

Q_SIGNALS:
    void enabledChanged();
    void directoriesChanged();
    // id = partial file path
    void started(const QString &id, const QString &fileName, const QString &application);
    void progress(const QString &id, qint64 bytes, qint64 speed);
    void finished(const QString &id, const QString &finalPath, bool success);

private:
    struct Partial {
        QString finalPath;
        qint64 bytes = 0;
        qint64 speed = 0;
        QElapsedTimer clock;
    };

    void rewatch();
    void scan();
    void sample();
    static QString finalPathFor(const QString &partialPath);
    static QString applicationFor(const QString &path);

    bool m_enabled = true;
    QStringList m_directories;
    QFileSystemWatcher m_watcher;
    QHash<QString, Partial> m_partials;
    QTimer m_sampler;
};
