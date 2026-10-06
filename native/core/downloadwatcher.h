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
 * Browser downloads that never become KDE jobs (e.g. Flatpak and Snap
 * browsers, which cannot reach Plasma Browser Integration): watches download
 * folders for partial files (Firefox/Zen/LibreWolf "*.part", Chromium/Chrome/
 * Brave/Edge "*.crdownload", Opera "*.opdownload", "*.download", "*.partial")
 * and reports their growth. Browsers don't write the final size anywhere, so
 * there is no percentage or remaining time here, only bytes and speed.
 *
 * A download is followed by the file itself (its inode), not by its name:
 * browsers rename the partial file while it is written. Seen with Zen
 * 1.22 / Firefox 157: "J-w3DTrx.bin.part" becomes "name.p6NHCVxw.bin.part"
 * 80 ms later and "name.bin" at the end; Chromium starts as
 * "Unconfirmed 123456.crdownload". A partial file that is renamed to another
 * partial name goes on; renamed to any other name it is done, under that
 * name. One that is gone with no such file is waited for (`settleTime`, for a
 * browser that writes the final file anew): a new file of at least its size
 * with a matching name ("name.bin", "name(1).bin", "name (1).bin") is the
 * download; none, and it was cancelled. Nothing here ever says "failed":
 * there is no evidence for that in a folder.
 *
 * Event driven: QFileSystemWatcher (inotify) on the folders; sizes are
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
    // How long a partial file that vanished is waited for under its final name (ms).
    Q_PROPERTY(int settleTime MEMBER m_settleTime NOTIFY settleTimeChanged)
    // How often sizes are read while something downloads (ms).
    Q_PROPERTY(int sampleInterval READ sampleInterval WRITE setSampleInterval NOTIFY sampleIntervalChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    explicit DownloadWatcher(QObject *parent = nullptr);

    bool isEnabled() const { return m_enabled; }
    void setEnabled(bool enabled);
    QStringList directories() const { return m_directories; }
    void setDirectories(const QStringList &dirs);
    QStringList watchedDirectories() const { return m_watcher.directories(); }
    int sampleInterval() const { return m_sampler.interval(); }
    void setSampleInterval(int ms);
    int count() const { return m_partials.size(); }

    // "name.p6NHCVxw.bin.part" → "name.bin" when that file is there (Firefox's placeholder);
    // "Unconfirmed 123.crdownload" → "" (not known yet); else the name without the suffix.
    static QString displayName(const QString &directory, const QString &partialName);
    // Only the host of the address a browser may have noted on the file (user.xdg.origin.url).
    Q_INVOKABLE static QString originHost(const QString &path);

Q_SIGNALS:
    void enabledChanged();
    void directoriesChanged();
    void settleTimeChanged();
    void sampleIntervalChanged();
    void countChanged();
    // id: a number of its own, the same for the whole download. fileName may be "" (not known yet).
    void started(const QString &id, const QString &fileName, const QString &application);
    void renamed(const QString &id, const QString &fileName);
    // stalled: seconds without growth (a download paused in the browser, or a slow server)
    void progress(const QString &id, qint64 bytes, qint64 speed, int stalled);
    // outcome: "done" | "cancelled". host: where it came from, when the browser noted it; else "".
    void finished(const QString &id, const QString &finalPath, const QString &outcome, qint64 bytes, const QString &host);

private:
    struct Partial {
        QString id;
        QString path;
        QString name;           // shown name
        quint64 inode = 0;
        qint64 bytes = 0;
        double speed = 0;
        qint64 startedAt = 0;   // ms since epoch
        QElapsedTimer clock;    // since the last sample
        QElapsedTimer still;    // since it last grew
        QElapsedTimer gone;     // since its file vanished (valid: waiting for the final file)
    };

    void rewatch();
    void scan();
    void sample();
    void end(Partial &p, const QString &finalPath, const QString &outcome);
    static QString applicationFor(const QString &path);

    bool m_enabled = true;
    int m_settleTime = 3000;
    quint64 m_next = 1;
    QStringList m_directories;
    QFileSystemWatcher m_watcher;
    QList<Partial> m_partials;
    QTimer m_sampler;
};
