// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QProcessEnvironment>
#include <QString>
#include <QStringList>

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
// The full path of `name`: on the PATH, else in one of binDirectories(). "" = not found.
QString findExecutable(const QString &name, const QString &home = QString());
// The environment a command found there is started with: its own folder comes first on the
// PATH, so that a script finds the interpreter that was installed beside it (node, for one).
QProcessEnvironment environmentFor(const QString &program);
}
