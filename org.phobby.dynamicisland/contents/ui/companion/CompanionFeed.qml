/*
    SPDX-License-Identifier: GPL-2.0-or-later

    What the companion is told of the island. It reads the ActivityManager
    (what is live, the event that is shown), the island (whether it shows
    anything, whether its open page asks something) and the AI tab's backend
    (whether an answer is on its way), and hands that to the controller as
    plain facts and moments. It writes nothing back: the island, its events
    and its activities go on as if nobody watched.

    Nothing is polled: every fact is a binding, every moment a signal.

      playing    a media activity is live
      thinking   the AI is writing an answer (whether or not its page is shown)
      asking     a question waits for the user: an event with buttons or one
                 that feels like a question (the habits' evening one), an
                 activity that asks (its waiting form), or the open page (a
                 confirmation, the evening review)
      idle       the island shows nothing but the clock (or is a dot)

      perk       an event came up, or another activity took the pill
      cheer      an event that feels "done": a timer ran out, a download is there
      tired      one that feels "low": the battery
      answer     the AI's answer is ready, or could not be given
*/
import QtQuick

Item {
    id: feed

    required property CompanionController mind
    property var manager: null              // ActivityManager
    property var island: null               // Island
    property var ai: null                   // AiBackend, or null

    readonly property var event: manager !== null ? manager.currentEvent : null
    readonly property bool playing: manager !== null && manager.live.some(a => a.category === "media")
    readonly property bool thinking: ai !== null && ai.busy === true
    readonly property bool questionShown: event !== null && (Array.isArray(event.buttons) || event.feel === "ask")
    readonly property bool activityAsks: manager !== null && ((manager.primary !== null && manager.primary.asks === true)
                                                              || (manager.secondary !== null && manager.secondary.asks === true))
    readonly property bool asking: questionShown || activityAsks || (island !== null && island.asking === true)
    readonly property bool idle: island === null || island.mode === "idle" || island.mode === "dot"

    Binding { target: feed.mind; property: "playing"; value: feed.playing }
    Binding { target: feed.mind; property: "thinking"; value: feed.thinking }
    Binding { target: feed.mind; property: "asking"; value: feed.asking }
    Binding { target: feed.mind; property: "idle"; value: feed.idle }

    // An event that is shown again and again under one key (the volume) is one event.
    property string lastKey: ""
    onEventChanged: {
        if (event === null) { lastKey = ""; return; }
        const key = String(event.key || event.title || "event");
        if (key === lastKey) return;
        lastKey = key;
        mind.notice(event.feel === "done" ? "cheer" : event.feel === "low" ? "tired" : "perk");
    }
    // Another activity took the pill (music has its own way of showing).
    property var lastPrimary: null
    readonly property var primary: manager !== null ? manager.primary : null
    onPrimaryChanged: {
        if (primary !== null && primary !== lastPrimary && primary.category !== "media") mind.notice("perk");
        lastPrimary = primary;
    }
    Connections {
        target: feed.ai
        ignoreUnknownSignals: true
        function onAnswered() { feed.mind.notice("answer"); }
        function onFailed() { feed.mind.notice("answer"); }
    }
}
