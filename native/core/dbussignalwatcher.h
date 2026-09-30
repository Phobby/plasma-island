// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QDBusMessage>
#include <QObject>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

/*
 * Forwards a D-Bus signal to QML. `service` and `path` may be empty to match
 * any sender / object (e.g. every KDE Connect device).
 */
class DBusSignalWatcher : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool systemBus MEMBER m_systemBus NOTIFY configChanged)
    Q_PROPERTY(QString service MEMBER m_service NOTIFY configChanged)
    Q_PROPERTY(QString path MEMBER m_path NOTIFY configChanged)
    Q_PROPERTY(QString iface MEMBER m_iface NOTIFY configChanged)
    Q_PROPERTY(QString member MEMBER m_member NOTIFY configChanged)
    Q_PROPERTY(bool connected READ isConnected NOTIFY connectedChanged)

public:
    explicit DBusSignalWatcher(QObject *parent = nullptr);
    ~DBusSignalWatcher() override;
    bool isConnected() const { return m_connected; }

Q_SIGNALS:
    void configChanged();
    void connectedChanged();
    void triggered(const QVariantList &arguments, const QString &path, const QString &sender);

private Q_SLOTS:
    void onMessage(const QDBusMessage &message);

private:
    void reconnect();
    void disconnectCurrent();

    bool m_systemBus = false;
    QString m_service, m_path, m_iface, m_member;
    bool m_connected = false;
    // What we are currently connected with (to disconnect exactly that).
    bool m_curSystem = false;
    QString m_curService, m_curPath, m_curIface, m_curMember;
};
