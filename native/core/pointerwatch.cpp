// SPDX-License-Identifier: GPL-2.0-or-later
#include "pointerwatch.h"

#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QFile>
#include <QStandardPaths>

namespace {
const QString kPath = QStringLiteral("/org/phobby/DynamicIsland/Pointer");
const QString kKWin = QStringLiteral("org.kde.KWin");
const QString kScripting = QStringLiteral("org.kde.kwin.Scripting");
int s_files = 0;

// What KWin runs: the pointer's position from KWin itself, and a call only when it goes in or out.
QString script(const QRect &zone, const QString &service)
{
    return QStringLiteral(
               "// Dynamic Island: the pointer near the island's place (native/core/pointerwatch.cpp).\n"
               "const zone = { x: %1, y: %2, w: %3, h: %4 };\n"
               "let inside = null;\n"
               "function look() {\n"
               "    const p = workspace.cursorPos;\n"
               "    const now = p.x >= zone.x && p.x < zone.x + zone.w && p.y >= zone.y && p.y < zone.y + zone.h;\n"
               "    if (now === inside) return;\n"
               "    inside = now;\n"
               "    callDBus(\"%5\", \"%6\", \"org.phobby.DynamicIsland.Pointer\", \"Near\", now);\n"
               "}\n"
               "workspace.cursorPosChanged.connect(look);\n"
               "look();\n")
        .arg(zone.x())
        .arg(zone.y())
        .arg(zone.width())
        .arg(zone.height())
        .arg(service, kPath);
}
}

PointerWatch::PointerWatch(QObject *parent)
    : QObject(parent)
    , m_name(QStringLiteral("dynamicisland-pointer-%1").arg(QCoreApplication::applicationPid()))
{
    // (a zone that changes a few times in a row, as the island is laid out: loaded once, after them)
    m_later.setSingleShot(true);
    m_later.setInterval(200);
    connect(&m_later, &QTimer::timeout, this, &PointerWatch::restart);
}

PointerWatch::~PointerWatch()
{
    unload();
    if (m_registered) QDBusConnection::sessionBus().unregisterObject(kPath);
}

void PointerWatch::setActive(bool active)
{
    if (m_active == active) return;
    m_active = active;
    Q_EMIT activeChanged();
    m_later.start();
}

void PointerWatch::setZone(const QRect &zone)
{
    if (m_zone == zone) return;
    m_zone = zone;
    Q_EMIT zoneChanged();
    if (m_active) m_later.start();
}

void PointerWatch::Near(bool near)
{
    // (a call from a script loaded before this one, or after it was switched off: not believed)
    if (m_active && m_loaded) setNear(near);
}

void PointerWatch::setNear(bool near)
{
    if (m_near == near) return;
    m_near = near;
    Q_EMIT nearChanged();
}

void PointerWatch::restart()
{
    unload();
    setNear(false);
    if (m_active && m_zone.width() > 0 && m_zone.height() > 0) load();
}

void PointerWatch::load()
{
    auto bus = QDBusConnection::sessionBus();
    if (!m_registered) {
        m_registered = bus.registerObject(kPath, this, QDBusConnection::ExportScriptableSlots);
        // (another island of this shell has it: only one at a time)
        if (!m_registered) return;
    }
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
    m_file = dir + QStringLiteral("/%1-%2.js").arg(m_name).arg(++s_files);
    QFile file(m_file);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) return;
    file.write(script(m_zone, bus.baseService()).toUtf8());
    file.close();

    // (one left by a shell that ended without unloading it goes first)
    bus.asyncCall(QDBusMessage::createMethodCall(kKWin, QStringLiteral("/Scripting"), kScripting, QStringLiteral("unloadScript")) << m_name);
    QDBusMessage load = QDBusMessage::createMethodCall(kKWin, QStringLiteral("/Scripting"), kScripting, QStringLiteral("loadScript"));
    load << m_file << m_name;
    auto *watcher = new QDBusPendingCallWatcher(bus.asyncCall(load), this);
    const QString file_ = m_file;
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, file_](QDBusPendingCallWatcher *w) {
        w->deleteLater();
        QDBusPendingReply<int> reply = *w;
        const bool ok = !reply.isError() && reply.value() >= 0;
        // (switched off or loaded anew meanwhile)
        if (file_ != m_file || !m_active) return;
        if (ok) {
            auto bus = QDBusConnection::sessionBus();
            bus.asyncCall(QDBusMessage::createMethodCall(kKWin, QStringLiteral("/Scripting/Script%1").arg(reply.value()),
                                                         QStringLiteral("org.kde.kwin.Script"), QStringLiteral("run")));
            m_loaded = true;
        }
        if (m_available != ok) {
            m_available = ok;
            Q_EMIT availableChanged();
        }
    });
}

void PointerWatch::unload()
{
    if (!m_file.isEmpty()) {
        QDBusConnection::sessionBus().asyncCall(
            QDBusMessage::createMethodCall(kKWin, QStringLiteral("/Scripting"), kScripting, QStringLiteral("unloadScript")) << m_name);
        QFile::remove(m_file);
        m_file.clear();
    }
    m_loaded = false;
}
