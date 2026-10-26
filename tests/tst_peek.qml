/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The full-screen mode (FullscreenPeek.qml, Island.resting): a window that
    fills the screen comes and goes (as the task manager would tell it), and
    the island is hidden, stays, is drawn up to the edge or shrunk; the pointer
    at the edge opens it only after the delay, leaving it closes it and it
    goes back up, not while it is typed in; a pointer kept at the edge does
    not open it over and over; a call ringing opens it, nothing else does.
    Drawn up, the island rests: what moves in it stops, it takes no pointer,
    and what comes waits (a call too, until it comes down).
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
            island.resting = false; island.expanded = false;
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

        function test_island_resting() {
            const layer = (function find(item) {
                if (item.layerMode === "idle") return item;
                for (const c of item.children) { const f = find(c); if (f) return f; }
                return null;
            })(island);
            verify(layer !== null);
            verify(layer.visible);
            island.resting = true;
            verify(!layer.visible, "what it shows rests");
            verify(activities.quiet && !activities.quietCritical, "what comes waits, a critical event too");
            // nothing takes the pointer
            mouseMove(island, island.width / 2, 10);
            wait(150);
            verify(!island.hovered && !island.expanded, "the pointer on it does nothing");
            island.resting = false;
            verify(layer.visible && !activities.quiet);
            mouseMove(island, island.width / 2 + 2, 12);
            tryVerify(() => island.expanded, 600, "down again: as always");
            mouseMove(root, 5, root.height - 5);
            tryVerify(() => !island.expanded, 1500);
        }

        function test_where_the_small_island_ends() {
            compare(island.restBottom, islandTheme.pillHeight, "the notch: its height");
            islandTheme.notch = false;
            compare(island.restBottom, islandTheme.windowTopPad + islandTheme.pillHeight, "the oval one: below its top room");
            islandTheme.notch = true;
        }
    }
}
