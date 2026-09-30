/*
    SPDX-License-Identifier: GPL-2.0-or-later

    ActivityManager: single source of truth for what the island shows.

      * Live Activities are registered once by providers and toggled through
        `active`. The active ones are sorted by `order` (category rank), then
        by `priority`, then by start time → `primary`, `secondary`, `live`.
      * Transient events are queued with flash({...}). An event covers the live
        activity only if the "event" category ranks above the primary activity;
        otherwise it waits (events older than `maxEventAge` are dropped).

    Event object:
      { kind: "notification" | "event",
        icon, color, title, subtitle,
        trailing: { type: "ring" | "battery" | "slider" | "text" | "dot", value, color, text, charging },
        duration (ms), notification (for kind "notification"), activate: function,
        key (coalesce repeats), live (feedback like volume: dropped instead of
        queued when it cannot be shown right away), force (shown even above a
        higher-priority live activity, e.g. an incoming call) }
*/
import QtQuick

Item {
    id: manager

    // ---- configuration ------------------------------------------------------
    property var order: ["privacy", "call", "recording", "event", "timer", "transfer", "media"]
    property bool splitEnabled: true
    // Playing media never drops out of sight: if it is not among the two
    // shown activities it takes the split bubble (others wait in the list).
    property bool keepMediaVisible: true
    property int eventDuration: 3000
    property int notificationDuration: 4000
    property int maxEventAge: 30000

    // ---- inputs from the island ----------------------------------------------
    // While expanded events are held back; while hovered the banner stays.
    property bool holdEvents: false
    property bool hovered: false

    // ---- live activities ------------------------------------------------------
    property var registered: []
    property var live: []                 // pill-worthy, sorted
    property var indicators: []           // indicatorOnly activities, active
    readonly property var primary: live.length > 0 ? live[0] : null
    readonly property var secondary: splitEnabled && live.length > 1 ? live[1] : null
    readonly property int liveCount: live.length

    function rank(category: string): int {
        const i = order.indexOf(category);
        return i < 0 ? order.length : i;
    }

    function register(a: Activity): void {
        if (registered.indexOf(a) >= 0) return;
        registered.push(a);
        a.activeChanged.connect(scheduleUpdate);
        a.priorityChanged.connect(scheduleUpdate);
        a.categoryChanged.connect(scheduleUpdate);
        scheduleUpdate();
    }
    function unregister(a: Activity): void {
        const i = registered.indexOf(a);
        if (i < 0) return;
        registered.splice(i, 1);
        scheduleUpdate();
    }

    property bool updatePending: false
    function scheduleUpdate(): void {
        if (updatePending) return;
        updatePending = true;
        Qt.callLater(update);
    }
    function update(): void {
        updatePending = false;
        const act = registered.filter(a => a && a.active);
        const sorted = act.filter(a => !a.indicatorOnly).sort((a, b) =>
            (rank(a.category) - rank(b.category)) || (b.priority - a.priority) || (a.startedAt - b.startedAt));
        if (keepMediaVisible && splitEnabled) {
            const m = sorted.findIndex(a => a.category === "media");
            if (m > 1) sorted.splice(1, 0, sorted.splice(m, 1)[0]);
        }
        live = sorted;
        indicators = act.filter(a => a.indicatorOnly);
        if (!currentEvent) Qt.callLater(showNext);
    }
    onOrderChanged: scheduleUpdate()

    function byId(id: string): var {
        return registered.find(a => a.activityId === id) ?? null;
    }

    // ---- transient events -------------------------------------------------------
    property var currentEvent: null
    property var queue: []
    readonly property bool eventsAllowed: !holdEvents && (!primary || rank("event") <= rank(primary.category))

    // System events fired while providers read their initial state are noise.
    property bool warm: false
    Timer {
        interval: 4000
        running: true
        onTriggered: manager.warm = true
    }

    function flash(ev: var): void {
        ev.kind = ev.kind || "event";
        if (!warm && ev.kind === "event") return;
        if (ev.live && !eventsAllowed && !ev.force) return;
        ev.queuedAt = Date.now();
        // Coalesce repeated events of the same key (e.g. volume ticks).
        if (ev.key) {
            if (currentEvent && currentEvent.key === ev.key) {
                currentEvent = ev;
                eventTimer.interval = durationOf(ev);
                eventTimer.restart();
                return;
            }
            queue = queue.filter(q => q.key !== ev.key);
        }
        queue.push(ev);
        // Deferred: a live activity toggled in the same tick must rank first.
        if (!currentEvent) Qt.callLater(showNext);
    }

    function durationOf(ev: var): int {
        return ev.duration || (ev.kind === "notification" ? notificationDuration : eventDuration);
    }

    function showNext(): void {
        if (currentEvent || holdEvents) return;
        const now = Date.now();
        queue = queue.filter(q => now - q.queuedAt < maxEventAge);
        const i = eventsAllowed ? 0 : queue.findIndex(q => q.force);
        if (i < 0 || queue.length === 0) return;
        currentEvent = queue.splice(i, 1)[0];
        eventTimer.interval = durationOf(currentEvent);
        eventTimer.restart();
    }

    function dismissEvent(): void {
        eventTimer.stop();
        currentEvent = null;
        if (queue.length > 0) gapTimer.restart();
    }

    function activateEvent(): void {
        const ev = currentEvent;
        if (ev && typeof ev.activate === "function") ev.activate();
        dismissEvent();
    }

    onEventsAllowedChanged: if (eventsAllowed && !currentEvent) gapTimer.restart()

    Timer {
        id: eventTimer
        onTriggered: manager.hovered ? restart() : manager.dismissEvent()
    }
    // Small gap so consecutive events visibly "pulse" back and forth.
    Timer {
        id: gapTimer
        interval: 220
        onTriggered: manager.showNext()
    }
}
