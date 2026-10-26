// SPDX-License-Identifier: GPL-2.0-or-later
#include "userpaths.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QVersionNumber>

#include <algorithm>

namespace
{
// The `bin` folders of every version in `parent` (…/<version>/<below>), the newest version first.
QStringList versions(const QString &parent, const QString &below)
{
    QStringList names = QDir(parent).entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    // Collation's numeric mode is not supported by every locale (notably C).
    // Version components must be compared as numbers regardless of the desktop locale.
    std::sort(names.begin(), names.end(), [](const QString &a, const QString &b) {
        const auto version = [](const QString &name) {
            return QVersionNumber::fromString(name.startsWith(QLatin1Char('v')) ? name.mid(1) : name);
        };
        const int order = QVersionNumber::compare(version(a), version(b));
        return order != 0 ? order > 0 : a > b;
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

namespace
{
QVariantMap s_given;

QString expandHome(const QString &path)
{
    return path.startsWith(QLatin1String("~/")) ? QDir::homePath() + path.mid(1) : path;
}

bool usable(const QString &path)
{
    const QFileInfo info(path);
    return info.isFile() && info.isExecutable();
}

// An AppImage of that name: "Name-1.2-x86_64.AppImage", "name.AppImage" (case is not looked at).
QString appImage(const QString &name, const QString &home)
{
    const QString lower = name.toLower();
    for (const QString &directory : UserPaths::appImageDirectories(home)) {
        const QFileInfoList files = QDir(directory).entryInfoList(QDir::Files | QDir::Executable, QDir::Name | QDir::Reversed);
        for (const QFileInfo &file : files) {
            const QString base = file.fileName().toLower();
            if (base.endsWith(QLatin1String(".appimage")) && base.startsWith(lower)
                && (base.length() == lower.length() + 9 || !base.at(lower.length()).isLetterOrNumber())) {
                return file.absoluteFilePath();
            }
        }
    }
    return QString();
}
}

void UserPaths::setCommandPaths(const QVariantMap &paths)
{
    s_given = paths;
}

QVariantMap UserPaths::commandPaths()
{
    return s_given;
}

QStringList UserPaths::appImageDirectories(const QString &givenHome)
{
    const QString home = givenHome.isEmpty() ? QDir::homePath() : givenHome;
    QStringList existing;
    for (const char *below : {"/Applications", "/AppImages", "/.local/share/AppImages", "/.local/bin"}) {
        const QString directory = home + QLatin1String(below);
        if (QFileInfo(directory).isDir()) {
            existing << directory;
        }
    }
    return existing;
}

QStringList UserPaths::searchedDirectories()
{
    QStringList all = qEnvironmentVariable("PATH").split(QLatin1Char(':'), Qt::SkipEmptyParts);
    for (const QString &directory : binDirectories() + appImageDirectories()) {
        if (!all.contains(directory)) {
            all << directory;
        }
    }
    return all;
}

QVariantMap UserPaths::locate(const QString &name, const QString &given, bool useGiven)
{
    const QString wanted = useGiven ? given : s_given.value(name).toString();
    QVariantMap out{{QStringLiteral("given"), wanted}, {QStringLiteral("givenUsable"), false}};
    if (!wanted.isEmpty()) {
        const QString path = expandHome(wanted);
        if (usable(path)) {
            out[QStringLiteral("givenUsable")] = true;
            out[QStringLiteral("path")] = QFileInfo(path).absoluteFilePath();
            out[QStringLiteral("via")] = QStringLiteral("setting");
            return out;
        }
    }
    QString found = name.isEmpty() || name.contains(QLatin1Char('/')) ? QString() : QStandardPaths::findExecutable(name);
    QString via = QStringLiteral("path");
    if (found.isEmpty() && !name.isEmpty() && !name.contains(QLatin1Char('/'))) {
        for (const QString &directory : binDirectories()) {
            if (usable(directory + QLatin1Char('/') + name)) {
                found = directory + QLatin1Char('/') + name;
                via = QStringLiteral("folder");
                break;
            }
        }
    }
    if (found.isEmpty() && !name.isEmpty() && !name.contains(QLatin1Char('/'))) {
        found = appImage(name, QString());
        via = QStringLiteral("appimage");
    }
    out[QStringLiteral("path")] = found;
    out[QStringLiteral("via")] = found.isEmpty() ? QString() : via;
    return out;
}

QString UserPaths::findExecutable(const QString &name, const QString &home)
{
    if (name.isEmpty()) {
        return QString();
    }
    // (a path the user gave for it comes first; not for tests, which give a home of their own)
    if (home.isEmpty() && !name.contains(QLatin1Char('/'))) {
        const QString given = expandHome(s_given.value(name).toString());
        if (!given.isEmpty() && usable(given)) {
            return QFileInfo(given).absoluteFilePath();
        }
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
    return name.contains(QLatin1Char('/')) ? QString() : appImage(name, home);
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
