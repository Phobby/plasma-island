// SPDX-License-Identifier: GPL-2.0-or-later
#include "packagekitwatcher.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>

static const QString s_service = QStringLiteral("org.freedesktop.PackageKit");
static const QString s_transaction = QStringLiteral("org.freedesktop.PackageKit.Transaction");

PackageKitWatcher::PackageKitWatcher(QObject *parent)
    : QObject(parent)
{
    m_timer.setInterval(1000);
    connect(&m_timer, &QTimer::timeout, this, &PackageKitWatcher::poll);
}

void PackageKitWatcher::setEnabled(bool enabled)
{
    if (m_enabled == enabled) {
        return;
    }
    m_enabled = enabled;
    Q_EMIT enabledChanged();
    QDBusConnection bus = QDBusConnection::systemBus();
    if (!enabled) {
        bus.disconnect(s_service, QStringLiteral("/org/freedesktop/PackageKit"), s_service, QStringLiteral("TransactionListChanged"), this,
                       SLOT(listChanged(QStringList)));
        m_timer.stop();
        m_paths.clear();
        const bool had = !m_shown.isEmpty();
        m_shown.clear();
        if (had) {
            Q_EMIT countChanged();
        }
        return;
    }
    // A signal the daemon sends by itself; listening does not start it.
    bus.connect(s_service, QStringLiteral("/org/freedesktop/PackageKit"), s_service, QStringLiteral("TransactionListChanged"), this,
                SLOT(listChanged(QStringList)));
    // Already running with something going on? (Asked only of a daemon that is there.)
    if (bus.interface() && bus.interface()->isServiceRegistered(s_service)) {
        auto *watcher = new QDBusPendingCallWatcher(
            bus.asyncCall(QDBusMessage::createMethodCall(s_service, QStringLiteral("/org/freedesktop/PackageKit"), s_service,
                                                         QStringLiteral("GetTransactionList"))),
            this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
            const QDBusPendingReply<QList<QDBusObjectPath>> reply = *w;
            w->deleteLater();
            if (reply.isError()) {
                return;
            }
            QStringList paths;
            for (const QDBusObjectPath &p : reply.value()) {
                paths << p.path();
            }
            listChanged(paths);
        });
    }
}

void PackageKitWatcher::listChanged(const QStringList &paths)
{
    if (!m_enabled) {
        return;
    }
    // A transaction that left the list without saying how it ended.
    const QStringList shown = m_shown.keys();
    for (const QString &path : shown) {
        if (!paths.contains(path)) {
            QDBusConnection::systemBus().disconnect(s_service, path, s_transaction, QStringLiteral("Finished"), this, SLOT(transactionFinished(uint, uint)));
            Q_EMIT finished(m_shown.take(path), QStringLiteral("unknown"));
            Q_EMIT countChanged();
        }
    }
    m_paths = paths;
    if (m_paths.isEmpty()) {
        m_timer.stop();
    } else {
        if (!m_timer.isActive()) {
            m_timer.start();
        }
        poll();
    }
}

void PackageKitWatcher::poll()
{
    for (const QString &path : std::as_const(m_paths)) {
        look(path);
    }
}

void PackageKitWatcher::look(const QString &path)
{
    QDBusMessage call = QDBusMessage::createMethodCall(s_service, path, QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("GetAll"));
    call << s_transaction;
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(call), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, path](QDBusPendingCallWatcher *w) {
        const QDBusPendingReply<QVariantMap> reply = *w;
        w->deleteLater();
        if (reply.isError() || !m_enabled || !m_paths.contains(path)) {
            return;
        }
        const QVariantMap p = reply.value();
        // PkRoleEnum: 10 install-files, 11 install-packages, 13 refresh-cache, 22 update-packages,
        // 25 download-packages, 33 upgrade-system. PkTransactionFlagEnum: 2 simulate, 4 only-download.
        const uint role = p.value(QStringLiteral("Role")).toUInt();
        const qulonglong flags = p.value(QStringLiteral("TransactionFlags")).toULongLong();
        QString action;
        switch (role) {
        case 10:
        case 11: action = QStringLiteral("install"); break;
        case 13: action = QStringLiteral("refresh"); break;
        case 22: action = QStringLiteral("update"); break;
        case 25: action = QStringLiteral("download"); break;
        case 33: action = QStringLiteral("upgrade"); break;
        default: return;
        }
        if (flags & 2) {
            return;
        }
        const bool background = role == 13 || (flags & 4);
        if (background && !m_showBackground) {
            return;
        }
        QString id = m_shown.value(path);
        if (id.isEmpty()) {
            id = QStringLiteral("pk") + QString::number(m_next++);
            m_shown.insert(path, id);
            QDBusConnection::systemBus().connect(s_service, path, s_transaction, QStringLiteral("Finished"), this, SLOT(transactionFinished(uint, uint)));
            QVariantMap info;
            info.insert(QStringLiteral("action"), action);
            info.insert(QStringLiteral("background"), background);
            Q_EMIT started(id, info);
            Q_EMIT countChanged();
        }
        // PkStatusEnum: 8 download, 20.. download-repository/-packagelist/…; 9 install, 10 update, 16 commit
        const uint status = p.value(QStringLiteral("Status")).toUInt();
        const QString stage = status == 8 || (status >= 20 && status <= 26) ? QStringLiteral("download")
                            : status == 9 || status == 10 || status == 16 ? QStringLiteral("install") : QString();
        const uint percent = p.value(QStringLiteral("Percentage")).toUInt();
        Q_EMIT progress(id, percent <= 100 ? int(percent) : -1, p.value(QStringLiteral("Speed")).toLongLong() / 8,
                        p.value(QStringLiteral("RemainingTime")).toInt(), stage);
    });
}

void PackageKitWatcher::transactionFinished(uint exit, uint)
{
    const QString path = message().path();
    QDBusConnection::systemBus().disconnect(s_service, path, s_transaction, QStringLiteral("Finished"), this, SLOT(transactionFinished(uint, uint)));
    if (!m_shown.contains(path)) {
        return;
    }
    // PkExitEnum: 1 success, 2 failed, 3 cancelled, 9 cancelled-priority; the others ask for another
    // round (a key, an EULA, untrusted packages): how that ends is not known here.
    const QString outcome = exit == 1 ? QStringLiteral("done") : exit == 2 || exit == 6 ? QStringLiteral("failed")
                          : exit == 3 || exit == 9 ? QStringLiteral("cancelled") : QStringLiteral("unknown");
    Q_EMIT finished(m_shown.take(path), outcome);
    Q_EMIT countChanged();
}
