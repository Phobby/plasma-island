// SPDX-License-Identifier: GPL-2.0-or-later
#include "updateschecker.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>

static const QString s_service = QStringLiteral("org.freedesktop.PackageKit");
static const QString s_path = QStringLiteral("/org/freedesktop/PackageKit");
static const QString s_txIface = QStringLiteral("org.freedesktop.PackageKit.Transaction");

// PackageKit enums (pk-enum.h)
static constexpr uint PK_INFO_ENUM_SECURITY = 8;
static constexpr uint PK_INFO_ENUM_BLOCKED = 13;
static constexpr quint64 PK_FILTER_NONE = 1 << 1;

UpdatesChecker::UpdatesChecker(QObject *parent)
    : QObject(parent)
{
    m_timer.setSingleShot(false);
    connect(&m_timer, &QTimer::timeout, this, &UpdatesChecker::refresh);
    connect(this, &UpdatesChecker::intervalChanged, this, [this] {
        m_timer.setInterval(qMax(15, m_intervalMinutes) * 60 * 1000);
    });
    m_timer.setInterval(m_intervalMinutes * 60 * 1000);

    QDBusConnection::systemBus().connect(s_service, s_path, s_service, QStringLiteral("UpdatesChanged"), this, SLOT(onUpdatesChanged()));
    // Don't compete with the login rush.
    QTimer::singleShot(20 * 1000, this, [this] {
        if (m_enabled) {
            refresh();
            m_timer.start();
        }
    });
}

void UpdatesChecker::setEnabled(bool enabled)
{
    if (m_enabled == enabled) {
        return;
    }
    m_enabled = enabled;
    Q_EMIT enabledChanged();
    if (enabled) {
        refresh();
        m_timer.start();
    } else {
        m_timer.stop();
    }
}

void UpdatesChecker::setAvailable(bool available)
{
    if (m_available != available) {
        m_available = available;
        Q_EMIT availableChanged();
    }
}

void UpdatesChecker::onUpdatesChanged()
{
    if (m_enabled) {
        refresh();
    }
}

void UpdatesChecker::refresh()
{
    if (m_running) {
        return;
    }
    m_running = true;
    auto bus = QDBusConnection::systemBus();
    const QDBusMessage create = QDBusMessage::createMethodCall(s_service, s_path, s_service, QStringLiteral("CreateTransaction"));
    auto *watcher = new QDBusPendingCallWatcher(bus.asyncCall(create), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
        w->deleteLater();
        QDBusPendingReply<QDBusObjectPath> reply = *w;
        if (reply.isError()) {
            m_running = false;
            setAvailable(false);
            return;
        }
        setAvailable(true);
        m_transaction = reply.value().path();
        m_pending = m_pendingSecurity = 0;
        auto bus = QDBusConnection::systemBus();
        bus.connect(s_service, m_transaction, s_txIface, QStringLiteral("Package"), this, SLOT(onPackage(uint, QString, QString)));
        bus.connect(s_service, m_transaction, s_txIface, QStringLiteral("Finished"), this, SLOT(onFinished(uint, uint)));
        QDBusMessage get = QDBusMessage::createMethodCall(s_service, m_transaction, s_txIface, QStringLiteral("GetUpdates"));
        get << QVariant::fromValue<quint64>(PK_FILTER_NONE);
        bus.asyncCall(get);
    });
}

void UpdatesChecker::onPackage(uint info, const QString &, const QString &)
{
    if (info == PK_INFO_ENUM_BLOCKED) {
        return;
    }
    ++m_pending;
    if (info == PK_INFO_ENUM_SECURITY) {
        ++m_pendingSecurity;
    }
}

void UpdatesChecker::onFinished(uint, uint)
{
    auto bus = QDBusConnection::systemBus();
    bus.disconnect(s_service, m_transaction, s_txIface, QStringLiteral("Package"), this, SLOT(onPackage(uint, QString, QString)));
    bus.disconnect(s_service, m_transaction, s_txIface, QStringLiteral("Finished"), this, SLOT(onFinished(uint, uint)));
    m_running = false;
    if (m_pending != m_count || m_pendingSecurity != m_security) {
        m_count = m_pending;
        m_security = m_pendingSecurity;
        Q_EMIT countChanged();
    }
}
