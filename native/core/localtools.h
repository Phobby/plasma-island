// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QFileSystemWatcher>
#include <QJSValue>
#include <QObject>
#include <QStringList>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

/*
 * What a local, account-less notes app (BetterNotes) needs and QML cannot do:
 * find its command, run it and read what it prints, read a small text file
 * (a .desktop entry), read its SQLite database (strictly read-only) and
 * notice when its files change.
 */
class LocalTools : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    // Files or directories to watch; `pathChanged()` fires when one changes.
    Q_PROPERTY(QStringList watchedPaths READ watchedPaths WRITE setWatchedPaths NOTIFY watchedPathsChanged)

public:
    explicit LocalTools(QObject *parent = nullptr);

    // Full path of a command on the PATH or in ~/.local/bin; "" if there is none.
    Q_INVOKABLE QString findExecutable(const QString &name) const;
    // The user's data directory ($XDG_DATA_HOME, else ~/.local/share).
    Q_INVOKABLE QString dataHome() const;
    // The first `maxBytes` of a text file ("~/" = home); "" if it cannot be read.
    Q_INVOKABLE QString readTextFile(const QString &path, int maxBytes = 65536) const;
    // Runs a program without a shell; callback(exitCode, stdout, stderr), exitCode -1 = could not run / timed out.
    Q_INVOKABLE void run(const QString &program, const QStringList &arguments, const QJSValue &callback);
    // Rows of a SELECT on an SQLite file opened read-only, as a list of { column: value }.
    // An empty list also means "could not be read".
    Q_INVOKABLE QVariantList sqliteQuery(const QString &databasePath, const QString &sql) const;

    QStringList watchedPaths() const;
    void setWatchedPaths(const QStringList &paths);

Q_SIGNALS:
    void watchedPathsChanged();
    void pathChanged();

private:
    QFileSystemWatcher m_watcher;
    QStringList m_paths;
};
