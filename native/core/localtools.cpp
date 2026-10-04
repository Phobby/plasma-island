// SPDX-License-Identifier: GPL-2.0-or-later
#include "localtools.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QSaveFile>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QSqlRecord>
#include <QStandardPaths>
#include <QTimer>
#include <QUuid>

namespace
{
QString expand(const QString &path)
{
    return path.startsWith(QLatin1String("~/")) ? QDir::homePath() + path.mid(1) : path;
}
}

LocalTools::LocalTools(QObject *parent)
    : QObject(parent)
{
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &LocalTools::pathChanged);
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, &LocalTools::pathChanged);
}

QString LocalTools::findExecutable(const QString &name) const
{
    const QString found = QStandardPaths::findExecutable(name);
    if (!found.isEmpty()) {
        return found;
    }
    // plasmashell's PATH does not always include it.
    const QFileInfo local(QDir::homePath() + QLatin1String("/.local/bin/") + name);
    return local.isExecutable() && !local.isDir() ? local.absoluteFilePath() : QString();
}

QString LocalTools::dataHome() const
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
}

QString LocalTools::readTextFile(const QString &path, int maxBytes) const
{
    QFile file(expand(path));
    if (!file.open(QIODevice::ReadOnly)) {
        return QString();
    }
    return QString::fromUtf8(file.read(qMax(0, maxBytes)));
}

double LocalTools::fileSize(const QString &path) const
{
    const QFileInfo info(expand(path));
    return info.isFile() ? double(info.size()) : -1;
}

bool LocalTools::writeTextFile(const QString &path, const QString &text) const
{
    const QString full = expand(path);
    if (!QDir().mkpath(QFileInfo(full).absolutePath())) {
        return false;
    }
    // Written beside it and moved over it: never a half-written file.
    QSaveFile file(full);
    if (!file.open(QIODevice::WriteOnly)) {
        return false;
    }
    const QByteArray bytes = text.toUtf8();
    return file.write(bytes) == bytes.size() && file.commit();
}

bool LocalTools::removeFile(const QString &path) const
{
    const QFileInfo info(expand(path));
    return info.isFile() && QFile::remove(info.absoluteFilePath());
}

QStringList LocalTools::listFiles(const QString &directory, const QString &suffix) const
{
    QStringList names;
    const QDir dir(expand(directory));
    if (!dir.exists()) {
        return names;
    }
    for (const QString &name : dir.entryList(QDir::Files | QDir::Readable, QDir::Name)) {
        if (suffix.isEmpty() || name.endsWith(suffix)) {
            names.append(name);
        }
    }
    return names;
}

void LocalTools::run(const QString &program, const QStringList &arguments, const QJSValue &callback)
{
    start(program, arguments, nullptr, callback);
}

void LocalTools::runWithInput(const QString &program, const QStringList &arguments, const QString &input, const QJSValue &callback)
{
    const QByteArray bytes = input.toUtf8();
    start(program, arguments, &bytes, callback);
}

void LocalTools::start(const QString &program, const QStringList &arguments, const QByteArray *input, const QJSValue &callback)
{
    auto *process = new QProcess(this);
    auto *answered = new bool(false);
    const auto answer = [process, answered, callback](int code) {
        if (*answered) {
            return;
        }
        *answered = true;
        QJSValue cb = callback;
        if (cb.isCallable()) {
            cb.call({QJSValue(code), QJSValue(QString::fromUtf8(process->readAllStandardOutput())),
                     QJSValue(QString::fromUtf8(process->readAllStandardError()))});
        }
        process->deleteLater();
    };
    connect(process, &QObject::destroyed, this, [answered] { delete answered; });
    connect(process, &QProcess::finished, this, [answer](int code, QProcess::ExitStatus status) {
        answer(status == QProcess::NormalExit ? code : -1);
    });
    connect(process, &QProcess::errorOccurred, this, [answer](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            answer(-1);
        }
    });
    // A command that hangs must not pile up.
    QTimer::singleShot(15000, process, [process, answer] {
        process->kill();
        answer(-1);
    });
    process->setProgram(program);
    process->setArguments(arguments);
    if (input) {
        const QByteArray bytes = *input;
        connect(process, &QProcess::started, process, [process, bytes] {
            process->write(bytes);
            process->closeWriteChannel();
        });
    } else {
        process->setStandardInputFile(QProcess::nullDevice());
    }
    process->start();
}

QVariantList LocalTools::sqliteQuery(const QString &databasePath, const QString &sql) const
{
    QVariantList rows;
    const QString path = expand(databasePath);
    if (!QFileInfo::exists(path)) {
        return rows;
    }
    const QString name = QStringLiteral("dynamicisland-") + QUuid::createUuid().toString(QUuid::Id128);
    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), name);
        db.setDatabaseName(path);
        db.setConnectOptions(QStringLiteral("QSQLITE_OPEN_READONLY;QSQLITE_BUSY_TIMEOUT=1000"));
        if (db.open()) {
            QSqlQuery query(db);
            query.setForwardOnly(true);
            if (query.exec(sql)) {
                while (query.next()) {
                    const QSqlRecord record = query.record();
                    QVariantMap row;
                    for (int i = 0; i < record.count(); ++i) {
                        row.insert(record.fieldName(i), record.value(i));
                    }
                    rows.append(row);
                }
            }
            query.finish();
            db.close();
        }
    }
    QSqlDatabase::removeDatabase(name);
    return rows;
}

QStringList LocalTools::watchedPaths() const
{
    return m_paths;
}

void LocalTools::setWatchedPaths(const QStringList &paths)
{
    if (paths == m_paths) {
        return;
    }
    m_paths = paths;
    if (!m_watcher.directories().isEmpty()) {
        m_watcher.removePaths(m_watcher.directories());
    }
    if (!m_watcher.files().isEmpty()) {
        m_watcher.removePaths(m_watcher.files());
    }
    for (const QString &path : paths) {
        const QString full = expand(path);
        if (QFileInfo::exists(full)) {
            m_watcher.addPath(full);
        }
    }
    Q_EMIT watchedPathsChanged();
}
