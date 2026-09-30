// SPDX-License-Identifier: GPL-2.0-or-later
#include "islandservice.h"

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusVariant>

static const QString s_service = QStringLiteral("org.phobby.DynamicIsland");
static const QString s_path = QStringLiteral("/org/phobby/DynamicIsland");

// D-Bus nests variants (e.g. from gdbus "<'text'>"); unwrap them for QML.
static QVariantMap plain(const QVariantMap &in)
{
    QVariantMap out;
    for (auto it = in.cbegin(); it != in.cend(); ++it) {
        QVariant v = it.value();
        while (v.canConvert<QDBusVariant>() && v.userType() == qMetaTypeId<QDBusVariant>()) {
            v = v.value<QDBusVariant>().variant();
        }
        out.insert(it.key(), v);
    }
    return out;
}

IslandService::IslandService(QObject *parent)
    : QObject(parent)
{
    auto bus = QDBusConnection::sessionBus();
    if (bus.registerObject(s_path, this, QDBusConnection::ExportScriptableContents) && bus.registerService(s_service)) {
        m_registered = true;
    } else {
        bus.unregisterObject(s_path);
        qWarning("IslandService: %s is already taken (another Dynamic Island instance?)", qPrintable(s_service));
    }
}

IslandService::~IslandService()
{
    if (m_registered) {
        auto bus = QDBusConnection::sessionBus();
        bus.unregisterService(s_service);
        bus.unregisterObject(s_path);
    }
}

void IslandService::emitClicked(const QString &id)
{
    Q_EMIT ActivityClicked(id);
}

void IslandService::Push(const QString &id, const QVariantMap &properties)
{
    if (id.isEmpty()) {
        return;
    }
    if (!m_ids.contains(id)) {
        m_ids.append(id);
        Q_EMIT idsChanged();
    }
    Q_EMIT pushed(id, plain(properties));
}

void IslandService::Update(const QString &id, const QVariantMap &properties)
{
    Push(id, properties);
}

void IslandService::Finish(const QString &id, const QString &status)
{
    if (m_ids.removeAll(id) > 0) {
        Q_EMIT idsChanged();
    }
    Q_EMIT finished(id, status);
}

void IslandService::Flash(const QVariantMap &properties)
{
    Q_EMIT flashed(plain(properties));
}

QStringList IslandService::List()
{
    return m_ids;
}
