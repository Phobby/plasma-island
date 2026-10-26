// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QFileSystemWatcher>
#include <QJSValue>
#include <QObject>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

/*
 * What a local, account-less notes app (BetterNotes) needs and QML cannot do:
 * find its command, run it and read what it prints, read a small text file
 * (a .desktop entry), read its SQLite database (strictly read-only) and
 * notice when its files change. Its own command writes the notes
 * (`betternotes update … --body -` reads the content from standard input).
 *
 * Also the island's own small files under the user's data directory (theme
 * files, what the suggestions learned, a kept AI chat): written, listed and
 * deleted here.
 */
class LocalTools : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    // Files or directories to watch; `pathChanged()` fires when one changes.
    Q_PROPERTY(QStringList watchedPaths READ watchedPaths WRITE setWatchedPaths NOTIFY watchedPathsChanged)
    // Paths the user gave for commands ({ name: path }), looked at before anything else, for every
    // command the shell finds or starts (the island's setting commandPaths; userpaths.h).
    Q_PROPERTY(QVariantMap commandPaths READ commandPaths WRITE setCommandPaths NOTIFY commandPathsChanged)

public:
    explicit LocalTools(QObject *parent = nullptr);

    // Full path of a command: on the PATH, else in one of the folders a user's own commands are
    // installed to (~/.local/bin, npm's, nvm's, bun's…: userpaths.h); "" if there is none.
    // `home`: only those folders, under this folder instead of the user's home (for tests).
    Q_INVOKABLE QString findExecutable(const QString &name, const QString &home = QString()) const;
    // Where a command is and how it was found ({ path, via, given, givenUsable }: userpaths.h); with
    // `useGiven`, `given` is tried instead of the path set for it (a path being typed in the settings).
    Q_INVOKABLE QVariantMap locate(const QString &name, const QString &given = QString(), bool useGiven = false) const;
    // Every folder a command is looked for in, in order.
    Q_INVOKABLE QStringList searchedDirectories() const;
    // What a report about the island needs to say about this computer: { qt, os, kernel, session,
    // host, user, home } (the last three only so that they can be left out of what is copied).
    Q_INVOKABLE QVariantMap systemInfo() const;
    // The user's data directory ($XDG_DATA_HOME, else ~/.local/share).
    Q_INVOKABLE QString dataHome() const;
    // An environment variable of the shell's ("" when it is not set): hidden switches for looking
    // at things (DYNAMICISLAND_CAT_GALLERY).
    Q_INVOKABLE QString environment(const QString &name) const;
    // The first `maxBytes` of a text file ("~/" = home); "" if it cannot be read.
    Q_INVOKABLE QString readTextFile(const QString &path, int maxBytes = 65536) const;
    // Size of a file in bytes; -1 if there is none.
    Q_INVOKABLE double fileSize(const QString &path) const;
    // Writes a text file (UTF-8) in one piece, making its directory; false if it could not.
    Q_INVOKABLE bool writeTextFile(const QString &path, const QString &text) const;
    // The same, readable and writable by the owner only (a kept AI chat).
    Q_INVOKABLE bool writePrivateFile(const QString &path, const QString &text) const;
    // Deletes a file; false if there was none or it could not be deleted.
    Q_INVOKABLE bool removeFile(const QString &path) const;
    // Names of the files in a directory that end with `suffix`, sorted; [] if there is no such directory.
    Q_INVOKABLE QStringList listFiles(const QString &directory, const QString &suffix = QString()) const;
    // Runs a program without a shell; callback(exitCode, stdout, stderr), exitCode -1 = could not run / timed out.
    Q_INVOKABLE void run(const QString &program, const QStringList &arguments, const QJSValue &callback);
    // The same, with `input` (UTF-8) on the program's standard input.
    Q_INVOKABLE void runWithInput(const QString &program, const QStringList &arguments, const QString &input, const QJSValue &callback);
    // run() in a directory of its own, made (for the owner only) when it is missing: for a command
    // that must never look at the directory the shell happens to be in.
    Q_INVOKABLE void runIn(const QString &directory, const QString &program, const QStringList &arguments, const QJSValue &callback);
    // run() with a time limit of its own (milliseconds) instead of the usual 15 s: a cloud may answer slowly.
    Q_INVOKABLE void runFor(int milliseconds, const QString &program, const QStringList &arguments, const QJSValue &callback);
    // Rows of a SELECT on an SQLite file opened read-only, as a list of { column: value }.
    // An empty list also means "could not be read".
    Q_INVOKABLE QVariantList sqliteQuery(const QString &databasePath, const QString &sql) const;

    QStringList watchedPaths() const;
    void setWatchedPaths(const QStringList &paths);
    QVariantMap commandPaths() const;
    void setCommandPaths(const QVariantMap &paths);

Q_SIGNALS:
    void watchedPathsChanged();
    void commandPathsChanged();
    void pathChanged();

private:
    void start(const QString &program, const QStringList &arguments, const QByteArray *input, const QJSValue &callback, const QString &directory = QString(),
               int milliseconds = 15000);
    bool write(const QString &path, const QString &text, bool ownerOnly) const;

    QFileSystemWatcher m_watcher;
    QStringList m_paths;
};
