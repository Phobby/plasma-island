// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QObject>
#include <QRect>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

/*
 * Whether the pointer is inside a rectangle of the screen (global, logical
 * pixels), without taking it: a window that took the pointer there would
 * also take the clicks of the window under it. Used while the island is
 * drawn up over a full-screen window, for the light at the edge (main.qml):
 * the pointer coming near the island's place lights it.
 *
 * While `active`, a small KWin script is loaded (org.kde.KWin /Scripting)
 * that looks at KWin's own pointer position and, only when it goes in or out
 * of `zone`, calls Near(b) on this object over the session bus (at this
 * process's unique name, path /org/phobby/DynamicIsland/Pointer). Nothing is
 * sent while the pointer moves inside or outside. Inactive, or `zone`
 * changed, the script is unloaded (and made anew). Without KWin (another
 * compositor, X11 without its scripting) `available` stays false and `near`
 * false.
 */
class PointerWatch : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_CLASSINFO("D-Bus Interface", "org.phobby.DynamicIsland.Pointer")
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(QRect zone READ zone WRITE setZone NOTIFY zoneChanged)
    Q_PROPERTY(bool near READ isNear NOTIFY nearChanged)
    Q_PROPERTY(bool available READ isAvailable NOTIFY availableChanged)

public:
    explicit PointerWatch(QObject *parent = nullptr);
    ~PointerWatch() override;

    bool active() const { return m_active; }
    void setActive(bool active);
    QRect zone() const { return m_zone; }
    void setZone(const QRect &zone);
    bool isNear() const { return m_near; }
    bool isAvailable() const { return m_available; }

public Q_SLOTS:
    // Called by the KWin script.
    Q_SCRIPTABLE void Near(bool near);

Q_SIGNALS:
    void activeChanged();
    void zoneChanged();
    void nearChanged();
    void availableChanged();

private:
    void restart();
    void load();
    void unload();
    void setNear(bool near);

    QTimer m_later;
    bool m_active = false;
    bool m_registered = false;
    bool m_loaded = false;
    bool m_near = false;
    bool m_available = false;
    QRect m_zone;
    QString m_name;
    QString m_file;
};
