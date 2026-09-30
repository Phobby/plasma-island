/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Desktop notifications → transient "notification" events.
    While Do Not Disturb is on nothing is shown but the arrivals are counted.
*/
import QtQuick
import ".."

Item {
    id: provider

    required property ActivityManager manager
    required property PlasmaBackend backend
    property bool enabled: true
    property bool doNotDisturb: false
    property int missedWhileDnd: 0

    onDoNotDisturbChanged: if (doNotDisturb) missedWhileDnd = 0

    Connections {
        target: provider.backend
        function onNotificationArrived(n) {
            if (!provider.enabled) return;
            if (provider.doNotDisturb) {
                provider.missedWhileDnd++;
                return;
            }
            provider.manager.flash({
                kind: "notification",
                notification: n,
                activate: () => provider.backend.activateNotification(n.id)
            });
        }
    }
}
