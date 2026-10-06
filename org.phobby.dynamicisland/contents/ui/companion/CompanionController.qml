/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The companion's mind, running: Companion.js has the rules, this hands them
    what goes on (the properties below, bound by whoever uses it; see
    CompanionFeed.qml for the island's side) and what is done to the cat
    (clicked(), pointerAt(), hovered()), and says what to draw: `body`,
    `accessory`, `bubble`, `tilt`, and gesture() for what happens once.

    It draws nothing and knows no cat: any character can be put on it.

    One timer, armed for the next moment at which something is due and not at
    all when nothing is (a sleeping cat). `active` false: nothing runs, and
    what it felt is forgotten. Nothing is ever stored or sent anywhere.

    For tests: `clock` and `random` can be handed in, and `timed: false`
    leaves the stepping to tick().
*/
import QtQuick
import "Companion.js" as Mind
import "CompanionTuning.js" as Tuning

QtObject {
    id: controller

    // Shown at all (not hidden, not switched off).
    property bool active: true

    // ---- what goes on ----------------------------------------------------------------
    property bool idle: true            // the island shows nothing but the clock
    property bool playing: false
    property bool thinking: false
    property bool asking: false
    // Beside the dot: it sleeps, whatever goes on.
    property bool asleepOnly: false

    // ---- settings --------------------------------------------------------------------
    property bool music: true
    property bool thoughts: true
    property bool events: true
    property bool petting: true
    property bool clicks: true
    property bool noAnger: false
    property bool still: false
    property int sleepAfter: tuning.sleepAfter
    property int sulkFor: tuning.sulkFor

    property var tuning: Tuning.TUNING
    property var clock: () => Date.now()
    property var random: () => Math.random()
    property bool timed: true

    // ---- what to draw ----------------------------------------------------------------
    property string body: "sit"
    property string accessory: ""
    property string bubble: ""
    property bool tilt: false
    // blink · tail · ear · lick · yawn · stretch · hop · perk · flinch · turn · shoo
    signal gesture(string name)

    // ---- what happens ----------------------------------------------------------------
    // perk · cheer · tired · answer · note (Companion.js: notice())
    function notice(kind: string): void {
        if (!active || state === null) return;
        Mind.notice(state, context(), clock(), tuning, kind);
        tick();
    }
    function clicked(): void {
        if (!active || state === null) return;
        tell(Mind.click(state, context(), clock(), tuning));
        tick();
    }
    function hovered(inside: bool): void {
        if (!active || state === null) return;
        if (!inside) strokes = Mind.strokeStart();
        tell(Mind.hover(state, context(), clock(), inside));
        tick();
    }
    // The pointer moved over the cat: its x, and the cat's width.
    function pointerAt(x: real, width: real): void {
        if (!active || !petting || state === null) return;
        const now = clock();
        if (!Mind.strokeFeed(strokes, x, now, width, tuning, state.petting)) return;
        Mind.stroke(state, context(), now, tuning);
        tick();
    }

    // ---- the running of it -----------------------------------------------------------
    // (made by reset(), not by a binding: one would make it anew whenever the clock moved)
    property var state: null
    property var strokes: null
    function reset(): void {
        state = Mind.start(clock(), random, tuning);
        strokes = Mind.strokeStart();
    }
    function context(): var {
        return { idle: idle, playing: playing, thinking: thinking, asking: asking, asleepOnly: asleepOnly,
                 music: music, thoughts: thoughts, events: events, petting: petting, clicks: clicks, noAnger: noAnger,
                 still: still, sleepAfter: asleepOnly ? 0 : sleepAfter, sulkFor: sulkFor };
    }
    function tell(gestures: var): void { for (const g of gestures) gesture(g); }
    function tick(): void {
        timer.stop();
        if (!active || state === null) return;
        const c = context();
        let now = clock(), next = now;
        // (what is due right away is done right away; never more than a few rounds)
        for (let round = 0; round < 6 && next >= 0 && next <= now; ++round) {
            tell(Mind.step(state, c, now, random, tuning));
            next = Mind.due(state, c, now, tuning);
            now = clock();
        }
        const v = Mind.view(state, c, now);
        if (body !== v.body) body = v.body;
        if (accessory !== v.accessory) accessory = v.accessory;
        if (bubble !== v.bubble) bubble = v.bubble;
        if (tilt !== v.tilt) tilt = v.tilt;
        nextDue = next;
        if (timed && next >= 0) {
            timer.interval = Math.max(1, Math.ceil(next - now));
            timer.start();
        }
    }
    // When tick() is next due by itself (-1: never, until something happens).
    property real nextDue: -1
    readonly property Timer timer: Timer { onTriggered: controller.tick() }

    onActiveChanged: {
        // hidden: what it felt is forgotten
        reset();
        tick();
    }
    onPlayingChanged: {
        if (playing && active && state !== null) Mind.notice(state, context(), clock(), tuning, "note");
        tick();
    }
    onIdleChanged: tick()
    onThinkingChanged: tick()
    onAskingChanged: tick()
    onAsleepOnlyChanged: tick()
    onMusicChanged: tick()
    onThoughtsChanged: tick()
    onEventsChanged: tick()
    onPettingChanged: tick()
    onClicksChanged: tick()
    onNoAngerChanged: tick()
    onStillChanged: tick()
    onSleepAfterChanged: tick()
    onSulkForChanged: tick()
    Component.onCompleted: { reset(); tick(); }
}
