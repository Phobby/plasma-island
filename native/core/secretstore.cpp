// SPDX-License-Identifier: GPL-2.0-or-later
#include "secretstore.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>

namespace
{
const QString s_service = QStringLiteral("org.kde.kwalletd6");
const QString s_path = QStringLiteral("/modules/kwalletd6");
const QString s_iface = QStringLiteral("org.kde.KWallet");
const QString s_wallet = QStringLiteral("kdewallet");
const QString s_folder = QStringLiteral("Dynamic Island");
const QString s_app = QStringLiteral("org.phobby.dynamicisland");
// Unlocking the wallet waits for the user.
const int s_timeout = 5 * 60 * 1000;
}

SecretStore::SecretStore(QObject *parent)
    : QObject(parent)
{
}

void SecretStore::invoke(const QString &method, const QVariantList &arguments, const std::function<void(bool, const QVariant &)> &done)
{
    QDBusMessage msg = QDBusMessage::createMethodCall(s_service, s_path, s_iface, method);
    msg.setArguments(arguments);
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg, s_timeout), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [done](QDBusPendingCallWatcher *w) {
        w->deleteLater();
        const QDBusMessage reply = w->reply();
        const bool ok = reply.type() == QDBusMessage::ReplyMessage && !reply.arguments().isEmpty();
        done(ok, ok ? reply.arguments().constFirst() : QVariant());
    });
}

void SecretStore::run(const QString &method, const QVariantList &arguments, bool createFolder, const std::function<void(bool, const QVariant &)> &done)
{
    invoke(QStringLiteral("open"), {s_wallet, QVariant::fromValue<qlonglong>(0), s_app}, [=, this](bool ok, const QVariant &value) {
        const int handle = ok ? value.toInt() : -1;
        if (handle < 0) {
            done(false, QVariant());
            return;
        }
        const auto call = [=, this](bool, const QVariant &) {
            QVariantList all{handle, s_folder};
            all.append(arguments);
            all.append(s_app);
            invoke(method, all, done);
        };
        if (createFolder) {
            // Fails harmlessly when the folder already exists.
            invoke(QStringLiteral("createFolder"), {handle, s_folder, s_app}, call);
        } else {
            call(true, QVariant());
        }
    });
}

void SecretStore::answer(QJSValue callback, bool ok, const QString &value)
{
    if (callback.isCallable()) {
        callback.call({QJSValue(ok), QJSValue(value)});
    }
}

void SecretStore::read(const QString &key, const QJSValue &callback)
{
    run(QStringLiteral("readPassword"), {key}, false, [callback](bool ok, const QVariant &value) {
        answer(callback, ok, value.toString());
    });
}

void SecretStore::write(const QString &key, const QString &value, const QJSValue &callback)
{
    run(QStringLiteral("writePassword"), {key, value}, true, [callback](bool ok, const QVariant &result) {
        answer(callback, ok && result.toInt() == 0);
    });
}

void SecretStore::remove(const QString &key, const QJSValue &callback)
{
    run(QStringLiteral("removeEntry"), {key}, false, [callback](bool ok, const QVariant &result) {
        answer(callback, ok && result.toInt() == 0);
    });
}
