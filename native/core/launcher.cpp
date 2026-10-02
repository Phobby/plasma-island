// SPDX-License-Identifier: GPL-2.0-or-later
#include "launcher.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDir>
#include <QFileInfo>
#include <QProcess>
#include <QQmlEngine>

Launcher::Launcher(QObject *parent)
    : QObject(parent)
{
}

bool Launcher::startDetached(const QString &program, const QStringList &arguments)
{
    return QProcess::startDetached(program, arguments);
}

QStringList Launcher::existingPaths(const QStringList &paths) const
{
    QStringList found;
    for (const QString &path : paths) {
        const QString full = path.startsWith(QLatin1String("~/")) ? QDir::homePath() + path.mid(1) : path;
        if (QFileInfo::exists(full)) {
            found.append(path);
        }
    }
    return found;
}

void Launcher::call(bool systemBus, const QString &service, const QString &path, const QString &iface, const QString &method,
                    const QVariantList &arguments, const QJSValue &callback)
{
    QDBusMessage msg = QDBusMessage::createMethodCall(service, path, iface, method);
    msg.setArguments(arguments);
    QDBusConnection bus = systemBus ? QDBusConnection::systemBus() : QDBusConnection::sessionBus();
    auto *watcher = new QDBusPendingCallWatcher(bus.asyncCall(msg), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, callback](QDBusPendingCallWatcher *w) {
        w->deleteLater();
        if (!callback.isCallable()) {
            return;
        }
        const QDBusMessage reply = w->reply();
        QJSValue cb = callback;
        if (reply.type() == QDBusMessage::ErrorMessage) {
            cb.call({QJSValue(reply.errorMessage()), QJSValue()});
        } else {
            QQmlEngine *engine = qmlEngine(this);
            QJSValue values = engine ? engine->toScriptValue(reply.arguments()) : QJSValue();
            cb.call({QJSValue(), values});
        }
    });
}
