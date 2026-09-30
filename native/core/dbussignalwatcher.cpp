// SPDX-License-Identifier: GPL-2.0-or-later
#include "dbussignalwatcher.h"

#include <QDBusConnection>
#include <QTimer>

DBusSignalWatcher::DBusSignalWatcher(QObject *parent)
    : QObject(parent)
{
    connect(this, &DBusSignalWatcher::configChanged, this, [this] {
        QTimer::singleShot(0, this, &DBusSignalWatcher::reconnect);
    });
}

DBusSignalWatcher::~DBusSignalWatcher()
{
    disconnectCurrent();
}

static QDBusConnection busFor(bool system)
{
    return system ? QDBusConnection::systemBus() : QDBusConnection::sessionBus();
}

void DBusSignalWatcher::disconnectCurrent()
{
    if (!m_connected) {
        return;
    }
    busFor(m_curSystem).disconnect(m_curService, m_curPath, m_curIface, m_curMember, this, SLOT(onMessage(QDBusMessage)));
    m_connected = false;
    Q_EMIT connectedChanged();
}

void DBusSignalWatcher::reconnect()
{
    disconnectCurrent();
    if (m_iface.isEmpty() || m_member.isEmpty()) {
        return;
    }
    m_curSystem = m_systemBus;
    m_curService = m_service;
    m_curPath = m_path;
    m_curIface = m_iface;
    m_curMember = m_member;
    m_connected = busFor(m_curSystem).connect(m_curService, m_curPath, m_curIface, m_curMember, this, SLOT(onMessage(QDBusMessage)));
    Q_EMIT connectedChanged();
}

void DBusSignalWatcher::onMessage(const QDBusMessage &message)
{
    Q_EMIT triggered(message.arguments(), message.path(), message.service());
}
