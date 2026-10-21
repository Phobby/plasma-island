/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Notch mode (Theme.notch, Island.qml, IslandShape/NotchOutline): the island
    hangs from the top edge, only its lower corners rounded; where it takes the
    pointer is that shape, the topmost row of pixels included; the pointer that
    leaves the open notch for the panel beside it does not open it again; the
    dot is a half circle at the edge; the width limit; its colours; and, off,
    the island as it always was.
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"

Item {
    id: root
    width: 900
    height: 420

    Theme { id: islandTheme; follow: false; notch: true }
    ActivityManager { id: activities; maxEventAge: 400 }
    PlasmaBackend { id: plasma }
    Activity { id: stopwatch; activityId: "stopwatch"; category: "timer"; icon: "chronometer"; title: "Stopwatch"; Component.onCompleted: activities.register(this) }
    Activity { id: timer; activityId: "timer"; category: "timer"; icon: "player-time"; title: "Timer"; Component.onCompleted: activities.register(this) }
    Component { id: otherPage; Item {} }
    Island {
        id: island
        anchors.fill: parent
        theme: islandTheme
        backend: plasma
        manager: activities
        showMediaModule: false
        showSystemModule: false
        showNotificationModule: false
        hoverDelay: 60
        collapseDelay: 120
        dotMode: true
        pageOrder: "other"
        extraPages: [{ key: "other", icon: "chronometer", title: "Other", component: otherPage, visible: true }]
    }

    TestCase {
        name: "Notch"
        when: windowShown

        function settled() { tryVerify(() => Math.abs(island.surfaceRect.width - island.targetWidth) < 0.001 && Math.abs(island.surfaceRect.height - island.targetHeight) < 0.001 && Math.abs(island.surfaceRadius - island.targetRadius) < 0.001, 2000); }
        function away() { mouseMove(root, 40, 400); wait(30); }
        function initTestCase() { Lang.setting = "en"; activities.warm = true; }
        function cleanup() {
            away(); island.hoverSpent = false;
            stopwatch.active = false; timer.active = false;
            island.expanded = false; island.dot = false; island.maxWidth = 0;
            islandTheme.notch = true; islandTheme.notchBlack = true; islandTheme.notchPixels = 0;
            wait(60); settled();
        }

        function test_1_it_hangs_from_the_edge() {
            compare(island.mode, "idle");
            compare(island.surfaceRect.y, 0, "no room above it");
            compare(island.surfaceRadius, islandTheme.notchRadius);
            // the mask's rounded rectangle reaches above the window by its radius: inside, the top is straight
            const m = island.maskRect, s = island.surfaceRect;
            compare(m.y, -island.hitRadius);
            compare(m.y + m.height, s.y + s.height, "down to its lower edge");
            compare([m.x, m.width], [s.x, s.width]);
            // open, the same: from the edge downwards
            island.expanded = true;
            settled();
            compare(island.surfaceRect.y, 0);
            compare(island.maskRect.y + island.maskRect.height, island.surfaceRect.height);
        }

        function test_2_the_topmost_row_opens_it() {
            const s = island.surfaceRect;
            // the pointer pushed against the edge of the screen: y 0
            mouseMove(root, s.x + s.width / 2, 0);
            tryVerify(() => island.expanded, 1000, "opened from the topmost row of pixels");
            // and its corners there are straight: the outermost column takes it too
            away();
            tryVerify(() => !island.expanded, 1000);
            settled();
            island.hoverSpent = false;
            mouseMove(root, island.surfaceRect.x + 1, 0);
            tryVerify(() => island.hovered, 500, "the upper corner is not rounded off");
        }

        function test_3_leaving_for_the_panel_does_not_open_it_again() {
            const s = island.surfaceRect;
            mouseMove(root, s.x + s.width / 2, 2);
            tryVerify(() => island.expanded, 1000);
            settled();
            // along the panel to its widgets beside the small notch, at the panel's height
            let opened = 0;
            const count = () => { if (island.expanded) ++opened; };
            island.expandedChanged.connect(count);
            const beside = s.x - 30;
            for (let x = island.surfaceRect.x + 10; x > beside; x -= 12) { mouseMove(root, x, 8); wait(16); }
            mouseMove(root, beside, 8);
            tryVerify(() => !island.expanded, 1000, "closed once the pointer left it");
            wait(600);
            island.expandedChanged.disconnect(count);
            compare([island.expanded, opened], [false, 0], "and not opened again");
        }

        function test_4_the_dot_is_a_half_circle_at_the_edge() {
            island.dot = true;
            settled();
            compare(island.mode, "dot");
            compare([island.surfaceRect.y, island.surfaceRect.width, island.surfaceRect.height, island.surfaceRadius],
                    [0, 2 * island.dotSize, island.dotSize, island.dotSize]);
            // its target starts at the edge too
            compare(island.hitRect.y, 0);
            verify(island.hitRect.height >= island.dotTarget);
            mouseMove(root, island.surfaceRect.x + island.surfaceRect.width / 2, 0);
            tryVerify(() => island.hovered, 500);
        }

        function test_5_the_width_limit() {
            stopwatch.active = true;
            tryCompare(island, "mode", "live");
            settled();
            const free = island.surfaceRect.width;
            island.maxWidth = 150;
            settled();
            compare(island.surfaceRect.width, 150);
            verify(free > 150);
            // the split island: pill, gap and bubble together within the limit
            timer.active = true;
            tryCompare(island, "mode", "split");
            settled();
            fuzzyCompare(island.surfaceRect.width + islandTheme.splitGap + islandTheme.bubbleSize, 150, 0.01);
            // never narrower than two heights of it
            island.maxWidth = 20;
            settled();
            fuzzyCompare(island.surfaceRect.width + islandTheme.splitGap + islandTheme.bubbleSize, 2 * islandTheme.pillHeight, 0.01);
            // the limit is the notch's: the island without it is as wide as ever
            island.maxWidth = 150;
            timer.active = false;
            settled();
            islandTheme.notch = false;
            settled();
            compare(island.surfaceRect.width, free);
        }

        function test_6_its_height_and_colours() {
            islandTheme.notchPixels = 44;
            compare(islandTheme.pillHeight, 44);
            settled();
            compare(island.surfaceRect.height, 44);
            // black, opaque, nothing of glass on it, light text
            compare(String(islandTheme.base), "#000000");
            compare([islandTheme.alpha, islandTheme.blurWanted, islandTheme.borderWidth, islandTheme.shadowLevel, islandTheme.material],
                    [1, false, 0, 0, "flat"]);
            verify(islandTheme.contrast(islandTheme.text, islandTheme.surface) >= 4.5);
            // the island's own colours: opaque too, the text still readable on them
            islandTheme.notchBlack = false;
            islandTheme.style = Styles.parse(JSON.stringify({ preset: "oxygen", fill: "gradient", gradientType: "linear", gradientAngle: 90,
                                                               gradientStops: ["#1a1b1d", "#134a83"], opacity: 60, blur: true, border: true, shadow: 2 }), null);
            compare([islandTheme.alpha, islandTheme.blurWanted, islandTheme.borderWidth, islandTheme.shadowLevel], [1, false, 0, 0]);
            verify(islandTheme.gradientFill, "the gradient stays");
            verify(islandTheme.contrast(islandTheme.text, islandTheme.surface) >= 4.5);
            islandTheme.style = Styles.defaults("oxygen");
        }

        function test_7_off_it_is_the_island_as_ever() {
            islandTheme.notch = false;
            settled();
            compare(island.surfaceRect.y, islandTheme.windowTopPad);
            compare(islandTheme.windowTopPad, 6);
            compare(island.surfaceRadius, islandTheme.rounded(islandTheme.pillHeight / 2));
            compare(island.maskRect, island.hitRect);
            compare(island.maskBubbleRect, island.bubbleRect);
            island.dot = true;
            settled();
            compare([island.surfaceRect.width, island.surfaceRect.height, island.surfaceRadius], [island.dotSize, island.dotSize, island.dotSize / 2]);
        }
    }
}
