// SPDX-License-Identifier: GPL-2.0-or-later
#include "userpaths.h"

#include <QCollator>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QStandardPaths>

#include <algorithm>

namespace
{
// The `bin` folders of every version in `parent` (…/<version>/<below>), the newest version first.
QStringList versions(const QString &parent, const QString &below)
{
    QStringList names = QDir(parent).entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    QCollator order;
    order.setNumericMode(true);
    std::sort(names.begin(), names.end(), [&order](const QString &a, const QString &b) {
        return order.compare(a, b) > 0;
    });
    QStringList found;
    for (const QString &name : std::as_const(names)) {
        found << parent + QLatin1Char('/') + name + QLatin1Char('/') + below;
    }
    return found;
}

// `prefix=` of ~/.npmrc: where `npm install -g` puts its commands when the user moved them out of /usr.
QString npmPrefix(const QString &home)
{
    QFile file(home + QLatin1String("/.npmrc"));
    if (!file.open(QIODevice::ReadOnly)) {
        return QString();
    }
    static const QRegularExpression line(QStringLiteral("^\\s*prefix\\s*=\\s*\"?([^\"\\r\\n]+?)\"?\\s*$"), QRegularExpression::MultilineOption);
    const QRegularExpressionMatch match = line.match(QString::fromUtf8(file.read(65536)));
    if (!match.hasMatch()) {
        return QString();
    }
    QString prefix = match.captured(1);
    prefix.replace(QLatin1String("${HOME}"), home).replace(QLatin1String("$HOME"), home);
    if (prefix.startsWith(QLatin1String("~/"))) {
        prefix = home + prefix.mid(1);
    }
    return QDir::isAbsolutePath(prefix) ? prefix : QString();
}
}

QStringList UserPaths::binDirectories(const QString &givenHome)
{
    const QString home = givenHome.isEmpty() ? QDir::homePath() : givenHome;
    QStringList all;
    // the user's own, and the installers that put a command into the home folder
    for (const char *below : {"/.local/bin", "/bin", "/.claude/local", "/.npm-global/bin", "/.npm/bin", "/.local/share/npm/bin", "/.bun/bin",
                              "/.volta/bin", "/.yarn/bin", "/.config/yarn/global/node_modules/.bin", "/.local/share/pnpm", "/.deno/bin",
                              "/.cargo/bin", "/go/bin", "/.asdf/shims", "/.local/share/mise/shims", "/.nix-profile/bin", "/n/bin",
                              "/.local/share/flatpak/exports/bin"}) {
        all << home + QLatin1String(below);
    }
    const QString prefix = npmPrefix(home);
    if (!prefix.isEmpty()) {
        all << prefix + QLatin1String("/bin");
    }
    // Node version managers: one folder per installed version
    all << versions(home + QLatin1String("/.nvm/versions/node"), QStringLiteral("bin"));
    all << versions(home + QLatin1String("/.local/share/nvm"), QStringLiteral("bin"));
    all << versions(home + QLatin1String("/.local/share/fnm/node-versions"), QStringLiteral("installation/bin"));
    all << versions(home + QLatin1String("/.fnm/node-versions"), QStringLiteral("installation/bin"));
    if (givenHome.isEmpty()) {
        all << QStringLiteral("/home/linuxbrew/.linuxbrew/bin") << QStringLiteral("/usr/local/bin") << QStringLiteral("/snap/bin")
            << QStringLiteral("/var/lib/flatpak/exports/bin") << QStringLiteral("/nix/var/nix/profiles/default/bin");
    }
    QStringList existing;
    for (const QString &directory : std::as_const(all)) {
        if (!existing.contains(directory) && QFileInfo(directory).isDir()) {
            existing << directory;
        }
    }
    return existing;
}

QString UserPaths::findExecutable(const QString &name, const QString &home)
{
    if (name.isEmpty()) {
        return QString();
    }
    if (home.isEmpty() || name.contains(QLatin1Char('/'))) {
        const QString found = QStandardPaths::findExecutable(name);
        if (!found.isEmpty() || name.contains(QLatin1Char('/'))) {
            return found;
        }
    }
    const QStringList directories = binDirectories(home);
    for (const QString &directory : directories) {
        const QFileInfo candidate(directory + QLatin1Char('/') + name);
        if (candidate.isFile() && candidate.isExecutable()) {
            return candidate.absoluteFilePath();
        }
    }
    return QString();
}

QProcessEnvironment UserPaths::environmentFor(const QString &program)
{
    QProcessEnvironment environment = QProcessEnvironment::systemEnvironment();
    if (!QDir::isAbsolutePath(program)) {
        return environment;
    }
    // (the folder the command is in, not the one a link there leads to: its neighbours are what it was installed with)
    const QString directory = QFileInfo(program).absolutePath();
    const QString path = environment.value(QStringLiteral("PATH"));
    if (!path.split(QLatin1Char(':')).contains(directory)) {
        environment.insert(QStringLiteral("PATH"), path.isEmpty() ? directory : directory + QLatin1Char(':') + path);
    }
    return environment;
}
