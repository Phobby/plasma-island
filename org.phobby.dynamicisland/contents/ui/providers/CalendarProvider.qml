/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Next calendar event as a Live Activity during the last N minutes before
    it starts. Hidden when the PIM calendar plugin is unavailable.
*/
import QtQuick
import ".."
import "../backend"

Item {
    id: provider

    required property ActivityManager manager
    required property CalendarBackend calendar
    required property Theme theme
    property int leadMinutes: 15
    property bool enabled: true

    property real now: Date.now()
    readonly property var next: calendar.upcoming.length > 0 ? calendar.upcoming[0] : null
    readonly property real minutesLeft: next ? (next.start.getTime() - now) / 60000 : -1

    Timer {
        interval: 30000
        repeat: true
        running: provider.enabled && provider.calendar.available && provider.next !== null
        triggeredOnStart: true
        onTriggered: {
            provider.now = Date.now();
            if (provider.minutesLeft <= 0) provider.calendar.refresh();
        }
    }

    Activity {
        activityId: "calendar"
        category: "timer"
        priority: 2
        active: provider.enabled && provider.calendar.available && provider.next !== null
                && provider.minutesLeft > 0 && provider.minutesLeft <= provider.leadMinutes
        icon: "view-calendar"
        color: provider.theme.red
        title: provider.next ? provider.next.title : ""
        subtitle: provider.next ? Qt.formatTime(provider.next.start, Qt.locale().timeFormat(Locale.ShortFormat)) : ""
        trailingText: i18nc("@info minutes until event", "%1 min", Math.max(1, Math.ceil(provider.minutesLeft)))
        Component.onCompleted: provider.manager.register(this)
    }
}
