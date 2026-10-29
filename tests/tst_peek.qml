/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The full-screen mode (FullscreenPeek.qml, Island.resting): a window that
    fills the screen comes and goes (as the task manager would tell it), and
    the island is hidden, stays, is drawn up to the edge or shrunk; the pointer
    at the edge opens it only after the delay, leaving it closes it and it
    goes back up, not while it is typed in; a pointer kept at the edge does
    not open it over and over; a call ringing opens it, nothing else does.
    On the desktop too, where wanted: nothing going on in it for a while, it
    is drawn up or shrunk the same way, and anything that comes brings it back.
    Drawn up, the island rests: what moves in it stops, it takes no pointer,
    and what comes waits (a call too, until it comes down). The light at the
    edge holds still, unless an event waits: then it pulses.
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"

Item {
    id: root
    width: 900
    height: 420

    FullscreenPeek {
        id: peek
        delay: 150
        settle: 120
        property int opened: 0
        onOpenRequested: ++opened
    }
    Theme { id: islandTheme; follow: false; notch: true }
    ActivityManager { id: activities; maxEventAge: 2000 }
    PlasmaBackend { id: plasma }
    // (something live, for the size of the island with it)
    Activity { id: build; activityId: "peek-test"; category: "transfer"; icon: "run-build"; title: "Tëstwick"; progress: 40; active: false
               Component.onCompleted: activities.register(this) }
    PeekGlow { id: glow; width: 200; height: 18 }
    Island {
        id: island
        width: 900
        height: 300
        theme: islandTheme
        backend: plasma
        manager: activities
        showMediaModule: false
        showSystemModule: false
        showNotificationModule: false
        hoverDelay: 60
        collapseDelay: 120
    }

    TestCase {
        name: "FullscreenPeek"
        when: windowShown

        function init() {
            peek.mode = 0; peek.over = false; peek.edgeHovered = false; peek.hovered = false;
            peek.open = false; peek.busy = false; peek.ringing = false; peek.callOpens = true; peek.opened = 0;
            peek.idle = false; peek.idleDelay = 0;
            island.resting = false; island.restingHolds = true; island.expanded = false;
            // (the states as they follow at once; the dwell and the breaker have tests of their own)
            peek.dwell = 0; peek.most = 1000; peek.changes = [];
        }
        // (the state while a window comes, is there and goes)
        function states() { return [peek.hidden, peek.away, peek.shrunk, peek.active]; }

        function test_modes_over_a_full_screen_window() {
            const seen = [];
            for (const mode of [0, 1, 2, 3]) {
                peek.mode = mode;
                peek.over = false;
                const before = states();
                peek.over = true;
                const during = states();
                peek.over = false;
                compare(states(), before, "back as it was once the window is gone: " + mode);
                seen.push(during);
            }
            compare(seen[0], [true, false, false, false], "hide");
            compare(seen[1], [false, false, false, false], "normal: nothing changes");
            compare(seen[2], [false, true, false, true], "peek: drawn up");
            compare(seen[3], [false, false, true, true], "shrink: the nub");
            compare(peek.opened, 0, "nothing opened it");
        }

        function test_the_edge_opens_it_after_the_delay() {
            peek.mode = 2; peek.over = true;
            peek.edgeHovered = true;
            wait(80);
            verify(peek.away, "not before the delay");
            tryVerify(() => !peek.away && peek.shown, 400);
            compare(peek.opened, 1, "opened as a hover would");
            // passing over it: no
            init();
            peek.mode = 2; peek.over = true;
            peek.edgeHovered = true; wait(60); peek.edgeHovered = false;
            wait(250);
            verify(peek.away && peek.opened === 0, "the pointer passing over it does not open it");
            // no delay set: at once
            peek.delay = 0;
            peek.edgeHovered = true;
            tryVerify(() => peek.shown, 100);
            peek.delay = 150;
        }

        function test_left_and_closed_it_goes_back_up() {
            peek.mode = 2; peek.over = true;
            peek.show();
            peek.open = true; peek.hovered = true;
            wait(250);
            verify(peek.shown, "open and under the pointer: down");
            peek.hovered = false;
            wait(250);
            verify(peek.shown, "left but still open (the island closes after its own delay)");
            peek.busy = true; peek.open = false;
            wait(250);
            verify(peek.shown, "being typed in: stays");
            peek.busy = false;
            tryVerify(() => peek.away, 500, "closed and left: back up");
        }

        function test_no_flicker_with_the_pointer_kept_at_the_edge() {
            peek.mode = 2; peek.over = true;
            peek.edgeHovered = true;
            tryVerify(() => peek.shown, 400);
            // (down, the strip is gone: the pointer kept at the very top is above the oval island, on nothing of it)
            peek.edgeHovered = false;
            peek.open = false;
            tryVerify(() => peek.away, 500);
            // (back up: the strip comes back under it)
            peek.edgeHovered = true;
            const opened = peek.opened;
            wait(600);
            verify(peek.away && peek.opened === opened, "drawn up under a pointer that stayed there: it does not open again");
            peek.edgeHovered = false;
            peek.edgeHovered = true;
            tryVerify(() => peek.shown, 400, "away and back: it opens");
        }

        function test_a_strip_that_comes_back_where_the_pointer_is_not() {
            peek.mode = 2; peek.over = true;
            peek.show();
            peek.open = false;
            tryVerify(() => peek.away, 500);
            wait(450);
            verify(peek.armed, "no pointer there: the strip may open it again");
            peek.edgeHovered = true;
            tryVerify(() => peek.shown, 400);
        }

        function test_a_ringing_call_opens_it_and_nothing_else() {
            for (const mode of [2, 3]) {
                init();
                peek.mode = mode; peek.over = true;
                peek.ringing = true;
                verify(peek.shown && peek.opened === 1, "the call opens it: " + mode);
            }
            init();
            peek.mode = 2; peek.over = true; peek.callOpens = false;
            peek.ringing = true;
            verify(peek.away && peek.opened === 0, "not if that is not wanted");
            init();
            peek.mode = 1; peek.over = true;
            peek.ringing = true;
            compare(peek.opened, 0, "normal: nothing to bring down");
        }

        function test_the_window_gone_while_open() {
            peek.mode = 3; peek.over = true;
            peek.show();
            peek.over = false;
            verify(!peek.shown && !peek.shrunk && !peek.active);
            peek.over = true;
            verify(peek.shrunk, "a new window: the nub again");
        }

        function test_no_back_and_forth_a_dwell() {
            peek.dwell = 350; peek.most = 4; peek.changedAt = -1e9;
            peek.mode = 2;
            peek.over = true;
            verify(peek.away, "the first change at once");
            peek.over = false;
            verify(peek.away, "not again within the dwell");
            tryVerify(() => !peek.active, 800, "taken after it");
            peek.over = true; peek.over = false;
            wait(450);
            verify(!peek.active, "a moment's window, there and gone within the dwell: nothing changed");
        }

        function test_no_back_and_forth_the_breaker() {
            peek.dwell = 0; peek.most = 4; peek.changes = [];
            peek.mode = 3;
            let changes = 0;
            const count = () => ++changes;
            peek.steadyChanged.connect(count);
            // a window at the edge of the notch, every frame in and out
            for (let i = 0; i < 30; ++i) { peek.over = !peek.over; wait(16); }
            peek.steadyChanged.disconnect(count);
            verify(changes <= 6, "held after a few: " + changes);
            peek.over = false;
            tryVerify(() => !peek.active, 2500, "and taken again once it holds still");
            // (the hold over before the next test)
            wait(1100);
        }

        function test_open_stays_open_when_a_window_comes() {
            peek.mode = 2;
            peek.open = true; peek.hovered = true;
            peek.over = true;
            verify(peek.shown && !peek.away, "opened by the pointer: it stays down and open");
            compare(peek.opened, 0, "nothing new opened it");
            peek.hovered = false; peek.open = false;
            tryVerify(() => peek.away, 600, "closed: up");
        }

        function test_on_the_desktop_when_nothing_goes_on() {
            const seen = [];
            for (const mode of [0, 1, 2, 3]) {
                init();
                peek.mode = mode;
                peek.idle = true; peek.idleDelay = 150;
                wait(80);
                verify(!peek.active, "not before the delay: " + mode);
                wait(250);
                seen.push(states());
                peek.idle = false;
                compare(states(), [false, false, false, false], "something comes: back at once, " + mode);
            }
            compare(seen[0], [false, false, false, false], "hide: never on the desktop");
            compare(seen[1], [false, false, false, false], "normal: nothing changes");
            compare(seen[2], [false, true, false, true], "peek: drawn up");
            compare(seen[3], [false, false, true, true], "shrink: the nub");
            // off: never
            init();
            peek.mode = 2; peek.idle = true;
            wait(300);
            verify(!peek.active, "not wanted: it stays");
            // the time starts again after each thing that went on
            peek.idleDelay = 200;
            wait(120); peek.idle = false; peek.idle = true; wait(120);
            verify(!peek.away, "interrupted: the delay starts again");
            tryVerify(() => peek.away, 400);
            // the edge opens it as over a full-screen window
            peek.edgeHovered = true;
            tryVerify(() => peek.shown, 400);
            compare(peek.opened, 1);
            // switched off while it is up: it comes down
            init();
            peek.mode = 3; peek.idle = true; peek.idleDelay = 100;
            tryVerify(() => peek.shrunk, 400);
            peek.idleDelay = 0;
            verify(!peek.active, "switched off: down");
        }

        function test_resting_without_holding() {
            island.restingHolds = false;
            island.resting = true;
            verify(!activities.quiet && activities.quietCritical, "drawn up only for being idle: what comes still comes");
            island.resting = false;
            island.restingHolds = true;
        }

        function test_island_resting() {
            const layer = (function find(item) {
                if (item.layerMode === "idle") return item;
                for (const c of item.children) { const f = find(c); if (f) return f; }
                return null;
            })(island);
            const picture = findChild(island, "frozenPicture");
            verify(layer !== null && picture !== null);
            verify(layer.visible && !picture.visible);
            island.resting = true;
            // (what it shows becomes a picture of itself: the same pixels, everything under it stopped)
            tryVerify(() => island.frozen, 1000, "a picture of what it shows");
            verify(!layer.visible && picture.visible && String(picture.source).length > 0, "what it shows rests as a picture");
            verify(activities.quiet && !activities.quietCritical, "what comes waits, a critical event too");
            // nothing takes the pointer
            mouseMove(island, island.width / 2, 10);
            wait(150);
            verify(!island.hovered && !island.expanded, "the pointer on it does nothing");
            island.resting = false;
            verify(layer.visible && !picture.visible && !activities.quiet);
            mouseMove(island, island.width / 2 + 2, 12);
            tryVerify(() => island.expanded, 600, "down again: as always");
            mouseMove(root, 5, root.height - 5);
            tryVerify(() => !island.expanded, 1500);
        }

        // Drawn up, the island is only moved (main.qml): its size and its shape never change, at any size
        // setting, in both layouts, idle or with something live in it.
        function test_size_kept_while_resting() {
            const rect = () => [island.surfaceRect.x, island.surfaceRect.y, island.surfaceRect.width, island.surfaceRect.height, island.surfaceRadius];
            const measured = [];
            for (const notch of [true, false]) {
                islandTheme.notch = notch;
                for (const scale of [0.8, 1, 2.4]) {
                    islandTheme.scaleOverride = scale;
                    for (const live of [false, true]) {
                        build.active = live;
                        tryVerify(() => island.mode === (live ? "live" : "idle"), 1000);
                        wait(islandTheme.morphDuration + 150);
                        const before = rect();
                        island.resting = true;
                        tryVerify(() => island.frozen, 1000);
                        wait(islandTheme.morphDuration + 150);
                        const during = rect();
                        compare(during, before, "resting: " + (notch ? "notch" : "oval") + " at " + scale + (live ? ", live" : ", idle"));
                        island.resting = false;
                        wait(50);
                        compare(rect(), before, "back: the same");
                        measured.push(before[2] + "x" + before[3]);
                        if (live) { build.active = false; tryVerify(() => island.mode === "idle", 4000); }
                    }
                }
            }
            islandTheme.scaleOverride = 0;
            islandTheme.notch = true;
            verify(measured.length === 12);
        }

        function test_where_the_small_island_ends() {
            compare(island.restBottom, islandTheme.pillHeight, "the notch: its height");
            islandTheme.notch = false;
            compare(island.restBottom, islandTheme.windowTopPad + islandTheme.pillHeight, "the oval one: below its top room");
            islandTheme.notch = true;
        }
    
        function test_the_light_pulses_for_an_event() {
            const shape = glow.children[0];
            glow.lit = true;
            tryCompare(glow, "opacity", 1);
            wait(300);
            compare(shape.opacity, 1, "lit by the pointer: it holds still");
            glow.pulse = true;
            tryVerify(() => shape.opacity < 0.5, 1500, "an event waits: it pulses");
            tryCompare(shape, "opacity", 1, 2500, "and comes back up");
            glow.pulse = false;
            compare(shape.opacity, 1, "the event gone: still again");
            glow.lit = false;
        }
}
}
