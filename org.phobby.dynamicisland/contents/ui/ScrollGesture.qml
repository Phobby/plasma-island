/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Who a scroll belongs to. One movement of the wheel or of two fingers on a
    touchpad (a "gesture": steps with no more than `gestureGap` between them)
    has one owner, from its first step to its last: the list it began over,
    a slider, or the island's pages. What scrolls asks with take(); the first
    that wants a fresh gesture owns it, everybody else is refused until it is
    over. So a list at its end keeps its scroll (the pages are not turned by
    what is left of it), and a scroll that turned the page does not go on
    into the list of the page arrived at.

    A Flickable lets the wheel through at its end and does not take the first
    steps of a touchpad scroll nor its last. A wheel says nothing of where a
    scroll begins or ends, and a WheelHandler at rest is not shown the step
    with which a touchpad does (ScrollBegin): hence the clock. Where that
    step is seen it is believed first.

    A WheelHandler hears one direction: whoever asks needs a second one
    (orientation: Qt.Horizontal) for the steps that go sideways only.

    Every list of the island has an IslandScroll in it (IslandFlickable,
    IslandListView), which asks for it; the pages ask in ExpandedContent.

    To watch it:  QT_LOGGING_RULES="island.wheel.debug=true"
*/
pragma Singleton
import QtQuick

QtObject {
    id: gesture

    // ---- the numbers, all of them here -------------------------------------------------
    // Steps further apart than this (ms) are two gestures. A wheel turned by
    // hand leaves 30–150 ms between its notches; a touchpad 10–30 ms.
    readonly property int gestureGap: 350
    // After the pages were turned, not again before this (ms): a touchpad that
    // says where a scroll begins could otherwise turn them twice in one swipe.
    readonly property int tabCooldown: 350
    // What turns the page: one notch of a wheel (in eighths of a degree) …
    readonly property int tabAngle: 120
    // … or this much of a touchpad (px); less is the fingers resting.
    readonly property int tabPixels: 40
    // One notch over a row that scrolls sideways moves it by this (px).
    readonly property int notchPixels: 48
    // A slider goes from one end to the other over this much of a touchpad (px).
    readonly property int sliderPixels: 400

    // ---- the gesture that is running ---------------------------------------------------
    property QtObject owner: null
    readonly property bool running: owner !== null
    // Counts the gestures: an owner can tell a new one from the one it knows.
    property int serial: 0
    property real started: 0
    property real last: 0
    // (tests hand in their own clock)
    property var clock: () => Date.now()

    readonly property Timer rest: Timer {
        interval: gesture.gestureGap
        onTriggered: gesture.end()
    }
    function end(): void {
        if (owner === null) return;
        say(owner, null, "over");
        owner = null;
        rest.stop();
    }

    // A step: x and y in pixels (a touchpad) or in eighths of a degree (a
    // wheel); horizontal: it goes sideways more than up or down; flat: it goes
    // sideways only; none: it does not move at all (the end of a scroll).
    function step(event): var {
        const pixels = event.pixelDelta.x !== 0 || event.pixelDelta.y !== 0;
        const dx = pixels ? event.pixelDelta.x : event.angleDelta.x;
        const dy = pixels ? event.pixelDelta.y : event.angleDelta.y;
        return { x: dx, y: dy, pixels: pixels, horizontal: Math.abs(dx) > Math.abs(dy), flat: dy === 0 && dx !== 0, none: dx === 0 && dy === 0 };
    }

    // `who` got a step. wants: it would take a gesture that begins with it.
    // True: the step is its own. False: it is somebody else's, leave it alone.
    function take(who: QtObject, wants: bool, event): bool {
        const now = clock();
        // (a ScrollBegin reaches everybody under the pointer: only the first one ends the old gesture)
        if (owner !== null && (now - last > gestureGap || (event.phase === Qt.ScrollBegin && now - started > 5))) end();
        if (owner === null) {
            // What is left of a scroll that is over begins nothing.
            if (!wants || event.phase === Qt.ScrollMomentum || event.phase === Qt.ScrollEnd) { say(who, event, "passes"); return false; }
            owner = who;
            started = now;
            serial += 1;
        }
        if (owner !== who) { say(who, event, "refused"); return false; }
        last = now;
        rest.restart();
        say(who, event, "takes");
        return true;
    }

    readonly property LoggingCategory log: LoggingCategory { name: "island.wheel"; defaultLogLevel: LoggingCategory.Warning }
    function name(who: QtObject): string { return who === null ? "nobody" : who.objectName.length > 0 ? who.objectName : String(who).replace(/\(0x[0-9a-f]+\)/, ""); }
    function say(who: QtObject, event, what: string): void {
        console.debug(log, clock() % 100000, name(who), what,
                      event === null ? "" : "angle=" + event.angleDelta.x + "," + event.angleDelta.y + " pixel=" + event.pixelDelta.x + "," + event.pixelDelta.y + " phase=" + event.phase,
                      "| gesture", serial, "of", name(owner));
    }
}
