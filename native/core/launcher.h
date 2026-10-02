// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QJSValue>
#include <QObject>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

/*
 * Small helpers QML cannot do on its own: start a detached program, make an
 * asynchronous D-Bus method call (result handed to an optional callback) and
 * tell which of some paths exist (to notice installed applications).
 */
class Launcher : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit Launcher(QObject *parent = nullptr);

    Q_INVOKABLE bool startDetached(const QString &program, const QStringList &arguments = {});
    // The given paths that exist; a leading "~/" is the home directory.
    Q_INVOKABLE QStringList existingPaths(const QStringList &paths) const;
    Q_INVOKABLE void call(bool systemBus, const QString &service, const QString &path, const QString &iface, const QString &method,
                          const QVariantList &arguments = {}, const QJSValue &callback = QJSValue());
};
