// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QJSValue>
#include <QObject>
#include <QtQml/qqmlregistration.h>

#include <functional>

/*
 * Passwords in the user's KWallet (folder "Dynamic Island"), over D-Bus.
 * Every call is asynchronous; the callback gets (ok, value). The wallet may
 * ask the user to unlock it, so a callback can take a while.
 */
class SecretStore : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit SecretStore(QObject *parent = nullptr);

    Q_INVOKABLE void read(const QString &key, const QJSValue &callback);
    Q_INVOKABLE void write(const QString &key, const QString &value, const QJSValue &callback = QJSValue());
    Q_INVOKABLE void remove(const QString &key, const QJSValue &callback = QJSValue());

private:
    // Calls KWallet `method(handle, folder, …arguments, appid)` once the wallet is open.
    void run(const QString &method, const QVariantList &arguments, bool createFolder, const std::function<void(bool, const QVariant &)> &done);
    void invoke(const QString &method, const QVariantList &arguments, const std::function<void(bool, const QVariant &)> &done);
    static void answer(QJSValue callback, bool ok, const QString &value = QString());
};
