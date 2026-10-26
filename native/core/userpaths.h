// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QProcessEnvironment>
#include <QString>
#include <QStringList>
#include <QVariantMap>

/*
 * Where a user's own commands are, beyond the PATH plasmashell was started
 * with. A shell adds folders to its PATH in its own start-up files (nvm, a
 * prefix of npm, bun, Volta, Homebrew…): a command installed that way is there
 * in every terminal and unknown to the desktop shell. These are the folders
 * such tools use; only they are looked into, no shell is started to ask.
 */
namespace UserPaths
{
// The folders that exist, in the order they are looked into. `home`: instead of the user's home (for tests).
QStringList binDirectories(const QString &home = QString());
// The full path of `name`: a path the user gave for it (setCommandPaths), else on the PATH, else in
// one of binDirectories(), else an AppImage of that name in appImageDirectories(). "" = not found.
QString findExecutable(const QString &name, const QString &home = QString());
// The same, and how it was found, for a settings page that says so: { path, via ("setting", "path",
// "folder", "appimage" or ""), given (the path the user gave, "" = none), givenUsable (it is an
// executable file) }. `given`: a path to try first instead of the one set with setCommandPaths.
QVariantMap locate(const QString &name, const QString &given = QString(), bool useGiven = false);
// Where AppImages are usually kept (~/Applications, ~/AppImages, ~/.local/share/AppImages, ~/.local/bin).
QStringList appImageDirectories(const QString &home = QString());
// Every folder that is looked into, in order: the PATH's, then binDirectories(), then the AppImage folders.
QStringList searchedDirectories();
// Paths the user gave for commands ({ name: path }, "~/" = home), looked at first; the island's
// setting (commandPaths), for the whole shell.
void setCommandPaths(const QVariantMap &paths);
QVariantMap commandPaths();
// The environment a command found there is started with: its own folder comes first on the
// PATH, so that a script finds the interpreter that was installed beside it (node, for one).
QProcessEnvironment environmentFor(const QString &program);
}
