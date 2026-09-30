/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Do Not Disturb, shared with Plasma's notification settings.
*/
import QtQuick
import org.kde.notificationmanager as NotificationManager

Item {
    id: dnd

    property date now: new Date()
    readonly property bool active: settings.notificationsInhibitedByApplication
                                   || (settings.notificationsInhibitedUntil !== undefined
                                       && !isNaN(settings.notificationsInhibitedUntil)
                                       && settings.notificationsInhibitedUntil > now)

    function setActive(on: bool): void {
        if (on) {
            // Same "until manually disabled" convention as the Notifications applet.
            const d = new Date();
            d.setFullYear(d.getFullYear() + 1);
            settings.notificationsInhibitedUntil = d;
        } else {
            settings.notificationsInhibitedUntil = undefined;
            settings.revokeApplicationInhibitions();
        }
        settings.save();
        now = new Date();
    }

    NotificationManager.Settings {
        id: settings
        live: true
        onSettingsChanged: dnd.now = new Date()
    }
    // Re-evaluate once a minute only while a timed DND is running.
    Timer {
        interval: 60000
        repeat: true
        running: dnd.active
        onTriggered: dnd.now = new Date()
    }
}
