/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The pages of the expanded island, in their default order: what the
    Layout settings list and ExpandedContent sort by. `config` is the
    configuration key that shows/hides a page ("" = always there when it has
    something to show: Activities appears while something is going on).
    The user's order is the `pageOrder` setting (comma-separated keys).
*/
import QtQuick

QtObject {
    readonly property var pages: [
        { key: "activities", icon: "view-list-details", title: Lang.i18n("Activities"), config: "",
          hint: Lang.i18n("Appears while something is going on (timer, transfer…)") },
        { key: "media", icon: "view-media-track", title: Lang.i18n("Media"), config: "showMediaModule",
          hint: Lang.i18n("Also turns the media live activity on or off") },
        { key: "control", icon: "speedometer", title: Lang.i18n("System"), config: "showSystemModule",
          hint: Lang.i18n("CPU, RAM, battery, network") },
        { key: "weather", icon: "weather-clear", title: Lang.i18n("Weather"), config: "showWeather",
          hint: Lang.i18n("Now and the next days; also the rain and storm alert") },
        { key: "notifications", icon: "notifications", title: Lang.i18n("Notifications"), config: "showNotificationModule", hint: "" },
        { key: "quicksettings", icon: "configure", title: Lang.i18n("Controls"), config: "showQuickSettings",
          hint: Lang.i18n("Control Center: Do Not Disturb, Wi-Fi, Bluetooth, sliders") },
        { key: "apps", icon: "view-app-grid-symbolic", title: Lang.i18n("Apps"), config: "showApps",
          hint: Lang.i18n("Shortcuts to the applications you choose") },
        { key: "tools", icon: "chronometer", title: Lang.i18n("Tools"), config: "showTools",
          hint: Lang.i18n("Timer, stopwatch, Pomodoro, alarm") },
        { key: "habits", icon: "view-calendar-tasks", title: Lang.i18n("Habits"), config: "showHabits",
          hint: Lang.i18n("Daily checklist, the evening review and its calendar") },
        { key: "calendar", icon: "view-calendar", title: Lang.i18n("Calendar"), config: "showCalendar",
          hint: Lang.i18n("Also the upcoming-event activity") },
        { key: "notes", icon: "view-pim-notes", title: Lang.i18n("Notes"), config: "showNotes", hint: "" },
        { key: "ai", icon: "lucide:sparkles", title: Lang.i18n("AI"), config: "showAi",
          hint: Lang.i18n("Quick questions to Claude Code, a local model or a service with a key") },
        { key: "cloud", icon: "folder-cloud", title: Lang.i18n("Cloud"), config: "showCloud",
          hint: Lang.i18n("Your clouds through rclone: folders by name, drag out, drop in, sync state") },
        { key: "clipboard", icon: "edit-paste", title: Lang.i18n("Clipboard"), config: "showClipboard",
          hint: Lang.i18n("History of what was copied") },
        { key: "devices", icon: "network-bluetooth", title: Lang.i18n("Devices"), config: "showDevicesModule",
          hint: Lang.i18n("Bluetooth devices and phones") }
    ]
    readonly property var defaultOrder: pages.map(p => p.key)

    // The saved order made whole: unknown keys dropped, missing ones (e.g. a page
    // added by an update) inserted after the page that precedes them by default.
    function normalize(saved: string): var {
        const known = defaultOrder;
        const order = String(saved || "").split(",").map(s => s.trim()).filter((k, i, all) => known.indexOf(k) >= 0 && all.indexOf(k) === i);
        for (let i = 0; i < known.length; ++i) {
            if (order.indexOf(known[i]) >= 0) continue;
            const before = i > 0 ? order.indexOf(known[i - 1]) : -1;
            order.splice(before + 1, 0, known[i]);
        }
        return order;
    }
}
