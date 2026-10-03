/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Upcoming events from the Plasma calendar's PIM plugin (Akonadi: KOrganizer,
    Google/Nextcloud calendars…). `available` is false when that plugin is not
    installed — the calendar module then hides itself.
*/
import QtQuick
import org.kde.plasma.workspace.calendar as PlasmaCalendar
import ".."

Item {
    id: calendar

    property bool enabled: true
    property bool pimAvailable: false
    readonly property bool available: enabled && pimAvailable
    // [{ title, start: Date, end: Date }] upcoming, timed events (today + tomorrow)
    property var upcoming: []

    PlasmaCalendar.EventPluginsManager {
        id: plugins
        enabledPlugins: calendar.available ? ["pimevents"] : []
    }

    Instantiator {
        model: plugins.model
        delegate: QtObject {
            required property var model
            Component.onCompleted: if (model.pluginId === "pimevents") calendar.pimAvailable = true
        }
    }

    PlasmaCalendar.Calendar {
        id: monthCalendar
        days: 7
        weeks: 6
        firstDayOfWeek: Lang.locale.firstDayOfWeek
        today: new Date()
    }

    onAvailableChanged: if (available) {
        monthCalendar.daysModel.setPluginsManager(plugins);
        Qt.callLater(refresh);
    }

    Connections {
        target: monthCalendar.daysModel
        function onAgendaUpdated() { Qt.callLater(calendar.refresh); }
    }

    function refresh(): void {
        if (!available) { upcoming = []; return; }
        const now = new Date();
        const tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
        let list = [];
        for (const day of [now, tomorrow]) {
            const events = monthCalendar.daysModel.eventsForDate(day) || [];
            for (const e of events) {
                if (e.isAllDay || !e.startDateTime) continue;
                if (e.startDateTime > now) list.push({ title: e.title, start: e.startDateTime, end: e.endDateTime });
            }
        }
        list.sort((a, b) => a.start - b.start);
        upcoming = list;
    }

    Timer {
        interval: 5 * 60 * 1000
        repeat: true
        running: calendar.available
        onTriggered: calendar.refresh()
    }
}
