/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Calendar events as a Live Activity. One timed event is pinned at a time:

      upcoming  from `leadMinutes` before the start: "Title · 12 min", priority
                rising as the start approaches
      ongoing   from start to end: time left + progress; a short "… started"
                event is flashed at the start
      ended     for `lingerMinutes` after the end, at a low priority, then gone

    The soonest upcoming event wins, then the running one, then the one that
    just ended. All-day events and reminders without a future time are never
    pinned; they only appear in `today` (the Calendar page).
*/
import QtQuick
import ".."

Item {
    id: provider

    required property ActivityManager manager
    required property var calendar          // IcsCalendarBackend
    required property Theme theme
    property real leadMinutes: 15
    property real lingerMinutes: 10
    property bool showAllDay: true
    property bool enabled: true

    readonly property bool usable: enabled && calendar.available
    readonly property var events: usable ? calendar.events : []

    // `now` ticks every second only while something is pinned; `coarseNow`
    // (20 s) drives the lists so they are not rebuilt every second.
    property real now: Date.now()
    property real coarseNow: Date.now()

    function phaseOf(e: var, t: real): string {
        if (e.allDay) return "";
        if (t < e.start) return e.start - t <= leadMinutes * 60000 ? "upcoming" : "";
        if (t < e.end) return "ongoing";
        return t - e.end < lingerMinutes * 60000 ? "ended" : "";
    }

    readonly property var pinned: {
        const t = coarseNow;
        let best = null, bestRank = 99;
        for (const e of events) {
            const phase = phaseOf(e, t);
            if (phase === "") continue;
            const rank = phase === "upcoming" ? 0 : phase === "ongoing" ? 1 : 2;
            // upcoming: soonest start; ongoing: most recently started; ended: most recently ended
            const better = rank < bestRank
                || (rank === bestRank && (rank === 0 ? e.start < best.start : rank === 1 ? e.start > best.start : e.end > best.end));
            if (better) { best = e; bestRank = rank; }
        }
        return best;
    }
    readonly property string phase: pinned ? phaseOf(pinned, now) : ""

    // Rest of today for the Calendar page (the running and just-ended ones included).
    readonly property var today: {
        const t = coarseNow, d = new Date(t);
        const dayStart = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
        const dayEnd = dayStart + 86400000;
        return events.filter(e => {
            if (e.start >= dayEnd) return false;
            if (e.allDay) return showAllDay && e.end > dayStart;
            if (e.todo) return e.start >= dayStart;                     // reminders stay listed all day
            return e.end > t - lingerMinutes * 60000;
        });
    }
    readonly property var errorNames: {
        const names = [];
        for (const s of calendar.sources) if (calendar.errors[s.url] !== undefined) names.push(s.name || i18n("Calendar"));
        return names;
    }

    function span(msLeft: real): string {
        const s = Math.max(0, Math.ceil(msLeft / 1000));
        if (s < 60) return i18nc("@info seconds, short", "%1 s", s);
        const m = Math.ceil(s / 60);
        if (m < 60) return i18nc("@info minutes, short", "%1 min", m);
        return i18nc("@info hours and minutes, short", "%1 h %2 min", Math.floor(m / 60), m % 60);
    }
    function clock(t: real): string {
        return Qt.formatTime(new Date(t), Qt.locale().timeFormat(Locale.ShortFormat));
    }
    function timeRange(e: var): string {
        if (e.allDay) return i18n("All day");
        return e.end > e.start ? clock(e.start) + " – " + clock(e.end) : clock(e.start);
    }
    function open(e: var): void {
        if (e && e.link) Qt.openUrlExternally(e.link);
    }

    Timer {
        interval: provider.pinned ? 1000 : 20000
        repeat: true
        running: provider.usable && provider.events.length > 0
        triggeredOnStart: true
        onTriggered: {
            const t = Date.now();
            provider.now = t;
            if (!provider.pinned || t - provider.coarseNow >= 20000 || provider.phaseOf(provider.pinned, t) !== provider.phaseOf(provider.pinned, provider.coarseNow)) {
                provider.coarseNow = t;
            }
        }
    }
    onEventsChanged: { now = Date.now(); coarseNow = now; }

    // "… started": once per occurrence, only when we actually saw it start.
    property string announced: ""
    onPhaseChanged: {
        const e = pinned;
        if (phase !== "ongoing" || !e || announced === e.key || now - e.start > 60000) return;
        announced = e.key;
        manager.flash({
            key: "calendar-start",
            icon: e.todo ? "view-task" : "view-calendar",
            color: e.color,
            title: i18nc("@info calendar event has begun", "%1 started", e.title || i18n("Event")),
            subtitle: e.location && e.location !== e.link ? e.location : timeRange(e),
            trailing: e.link ? { type: "button", text: i18nc("@action:button join a video meeting", "Join") } : { type: "text", text: clock(e.start), color: e.color },
            activate: e.link ? (() => provider.open(e)) : undefined,
            duration: 3000
        });
    }

    Activity {
        id: activity
        readonly property var e: provider.pinned
        activityId: "calendar"
        category: "timer"
        // Rises from 2 to 5 as the start approaches; a finished event sinks
        // below every other activity of its category.
        priority: !e ? 0
                : provider.phase === "upcoming" ? 2 + Math.round(3 * (1 - Math.min(1, (e.start - provider.coarseNow) / (provider.leadMinutes * 60000))))
                : provider.phase === "ongoing" ? 2 : -5
        active: provider.usable && e !== null && provider.phase !== ""
        icon: e && e.todo ? "view-task" : "view-calendar"
        color: !e ? provider.theme.red : provider.phase === "ended" ? provider.theme.subText : e.color
        title: e ? (e.title || i18n("Event")) : ""
        subtitle: {
            if (!e) return "";
            const where = e.location && e.location !== e.link ? " · " + e.location : "";
            return provider.timeRange(e) + where + (e.calendar ? " · " + e.calendar : "");
        }
        trailingText: !e ? ""
                    : provider.phase === "upcoming" ? provider.span(e.start - provider.now)
                    : provider.phase === "ongoing" ? i18nc("@info time left in a running event", "%1 left", provider.span(e.end - provider.now))
                    : i18nc("@info calendar event is over", "Ended")
        progress: e && provider.phase === "ongoing" && e.end > e.start ? (provider.now - e.start) / (e.end - e.start) : -1
        actions: e && e.link ? [{ icon: "camera-video-symbolic", text: i18nc("@action:button join a video meeting", "Join"), trigger: () => provider.open(activity.e) }] : []
        onClicked: provider.open(e)
        Component.onCompleted: provider.manager.register(this)
    }
}
