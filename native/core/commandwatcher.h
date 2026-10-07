// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QHash>
#include <QObject>
#include <QSet>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

/*
 * Downloads made by commands (apt, git clone, wget, curl, pip…), seen from
 * outside: nothing is installed, wrapped or asked of the network. /proc is
 * read every `idleInterval` ms for the commands of `commands`, and every
 * `activeInterval` ms while one of them runs. Nothing is ever stopped.
 *
 * What can be known, by kind (tried on Ubuntu 26.04):
 *   packages  apt, apt-get, aptitude, also under sudo. Root's /proc/<pid>/io
 *             and apt's "partial" folders cannot be read by a user, so there
 *             is no byte-exact progress: the stage comes from apt's child
 *             processes (its download methods, dpkg) and the bytes from the
 *             package files that have arrived in /var/cache/apt/archives.
 *             How it ended is taken from apt's own records: the stamp of a
 *             successful update, the entry in /var/log/apt/history.log (an
 *             "Error:" line = failed). No record: "unknown".
 *   clone     git clone: the bytes are the size of the pack being received
 *             (<target>/.git/objects/pack/tmp_pack_*). Ended with
 *             <target>/.git/HEAD there: done; the target gone: failed (git
 *             removes it, also when interrupted); else unknown.
 *   download  wget, curl, aria2c, yt-dlp, pip, npm…, of the same user: the
 *             bytes are what the process has written (wchar of
 *             /proc/<pid>/io; with curl and wget this was the file's size to
 *             the byte). How it ended cannot be seen: "unknown".
 * The total is never known here, so no percentage and no remaining time.
 *
 * A command line can carry a password or a token. It is read to find the
 * sub-command, the host and the repository's name and is then dropped: no
 * signal, property or log of this class ever holds an argument as it was.
 *
 * A process without a controlling terminal was not started by the user at a
 * prompt (unattended-upgrades, a cron job): left out unless `showBackground`.
 *
 * `procRoot` and `systemRoot` exist for the tests (a made-up /proc and /var).
 */
class CommandWatcher : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool enabled READ isEnabled WRITE setEnabled NOTIFY enabledChanged)
    // [{ name, kind: "packages" | "clone" | "download", actions: [sub-commands] (none: any) }]
    Q_PROPERTY(QVariantList commands READ commands WRITE setCommands NOTIFY commandsChanged)
    Q_PROPERTY(bool showBackground MEMBER m_showBackground NOTIFY showBackgroundChanged)
    Q_PROPERTY(int idleInterval MEMBER m_idleInterval NOTIFY intervalsChanged)
    Q_PROPERTY(int activeInterval MEMBER m_activeInterval NOTIFY intervalsChanged)
    Q_PROPERTY(QString procRoot MEMBER m_procRoot NOTIFY rootsChanged)
    Q_PROPERTY(QString systemRoot MEMBER m_systemRoot NOTIFY rootsChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    // How long the last look at /proc took (µs), for measuring.
    Q_PROPERTY(int lastScanMicroseconds MEMBER m_lastScan NOTIFY scanned)

public:
    explicit CommandWatcher(QObject *parent = nullptr);

    bool isEnabled() const { return m_enabled; }
    void setEnabled(bool enabled);
    QVariantList commands() const { return m_commandList; }
    void setCommands(const QVariantList &commands);
    int count() const { return m_tracked.size(); }

    Q_INVOKABLE void scan();
    // "https://user:token@host/owner/repo.git?x=1" → { host: "host", repo: "owner/repo" }; "git@host:owner/repo.git" too.
    Q_INVOKABLE static QVariantMap describeAddress(const QString &address);

Q_SIGNALS:
    void enabledChanged();
    void commandsChanged();
    void showBackgroundChanged();
    void intervalsChanged();
    void rootsChanged();
    void countChanged();
    void scanned();
    // info: { name, kind, action, host, repo, background (bool), own (bool: the user's own process) }
    void started(const QString &id, const QVariantMap &info);
    // stage: "" | "lists" | "download" | "install"
    void progress(const QString &id, qint64 bytes, qint64 speed, const QString &stage);
    // outcome: "done" | "failed" | "unknown". path: a folder to open, where there is one.
    void finished(const QString &id, const QString &outcome, qint64 bytes, const QString &path);

private:
    struct Command {
        QString kind;
        QStringList actions;
    };
    struct Tracked {
        QString id;
        int pid = 0;
        quint64 startTime = 0;
        QString name, kind, action;
        bool own = false;
        QString target;             // clone: the folder it is made in
        qint64 base = -1;           // download: wchar when first seen
        qint64 bytes = 0;
        double speed = 0;
        qint64 lastSample = 0;      // ms
        qint64 startedAt = 0;       // ms since epoch
        QString stage;
        // packages: what apt's records were when it started
        QSet<QString> archives;
        qint64 historySize = 0;
        qint64 stamp = 0;
    };
    struct Process {
        int pid = 0, parent = 0, tty = 0;
        quint64 startTime = 0;
        QString name;
    };

    bool readProcess(int pid, Process &p) const;
    QStringList arguments(int pid) const;
    void consider(const Process &p);
    void update(Tracked &t, const QList<Process> &all);
    QString outcome(const Tracked &t) const;
    QString sys(const char *path) const { return m_systemRoot + QLatin1String(path); }
    qint64 archiveBytes(const Tracked &t) const;

    bool m_enabled = false;
    bool m_showBackground = false;
    int m_idleInterval = 3000;
    int m_activeInterval = 1000;
    int m_lastScan = 0;
    QString m_procRoot = QStringLiteral("/proc");
    QString m_systemRoot;
    QVariantList m_commandList;
    QHash<QString, Command> m_commands;
    QSet<QByteArray> m_names;       // their names as /proc has them, for the look at every process
    QList<Tracked> m_tracked;
    QSet<QString> m_ignored;        // "pid:starttime" of matching processes that are not shown
    quint64 m_next = 1;
    QTimer m_timer;
};
