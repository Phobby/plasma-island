/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Notch mode (Theme.notch, Island.qml, IslandShape/NotchOutline): the island
    hangs from the top edge, only its lower corners rounded; where it takes the
    pointer is that shape, the topmost row of pixels included; the pointer that
    leaves the open notch for the panel beside it does not open it again; the
    dot is a half circle at the edge; the width limit; its colours; one shape
    and nothing else drawn (looked at in pixels); the cat beside it, clear of
    its curves; and, off, the island as it always was.
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"
import "../org.phobby.dynamicisland/contents/ui/companion"

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
        // (only where it is looked at: elsewhere the pointer moves over where it would stand)
        Companion { id: cat; island: island; theme: islandTheme; enabled: false; reduceMotion: true; sleepSeconds: 3600 }
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
            island.expanded = false; island.dot = false; island.maxWidth = 0; cat.enabled = false;
            islandTheme.notch = true; islandTheme.notchBlack = true; islandTheme.notchLook = false; islandTheme.notchPixels = 0;
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

        function test_7_one_shape_and_nothing_else() {
            // nothing of the glass is drawn over or around it
            compare([islandTheme.shadowSize, String(islandTheme.frost), String(islandTheme.innerShadow), String(islandTheme.highlight)],
                    [0, String(Qt.rgba(0, 0, 0, 0)), String(Qt.rgba(0, 0, 0, 0)), String(Qt.rgba(0, 0, 0, 0))]);
            for (const open of [false, true]) {
                island.expanded = open;
                settled();
                wait(400);   // (the content's fade)
                const img = grabImage(island);
                const s = island.surfaceRect, e = islandTheme.notchEar;
                const black = (x, y) => { const c = img.pixel(x, y); return c.a > 0.99 && c.r < 0.01 && c.g < 0.01 && c.b < 0.01; };
                // (what the test's window shows where nothing is drawn)
                const ground = img.pixel(2, island.height - 2);
                const empty = (x, y) => Qt.colorEqual(img.pixel(x, y), ground);
                // the top row: black from one curve to the other, no gap at the edge
                for (let x = Math.ceil(s.x - e / 2); x < s.x + s.width + e / 2; ++x) verify(black(x, 0), "top row at " + x);
                // its sides straight below the curves, its lower corners rounded and alike
                for (let y = e + 1; y < s.height - s.height / 2; y += 3) {
                    verify(black(s.x + 1, y) && black(s.x + s.width - 2, y), "sides at " + y);
                    verify(empty(s.x - 2, y) && empty(s.x + s.width + 1, y), "nothing beside it at " + y);
                }
                verify(empty(s.x + 1, s.height - 2) && empty(s.x + s.width - 2, s.height - 2), "the lower corners are rounded");
                verify(black(s.x + s.width / 2, s.height - 2), "the lower edge");
                // inside it, along its edges, no second outline or pill: black right up to the content
                const r = island.surfaceRadius;
                for (let y = 1; y < s.height - r; y += 2)
                    for (let d = 1; d < 7; ++d) verify(black(s.x + d, y) && black(s.x + s.width - 1 - d, y), "inside its sides at " + d + ", " + y);
                for (let x = s.x + r; x < s.x + s.width - r; x += 3)
                    for (const y of [1, 2, 3, s.height - 4, s.height - 3, s.height - 2]) verify(black(x, y), "inside its top and bottom at " + x + ", " + y);
                // no shadow, glow or ring under or around it
                for (let x = s.x - 20; x < s.x + s.width + 20; x += 5) verify(empty(x, s.height + 3), "nothing under it at " + x);
                // the two halves alike, at the edge and at the lower corners
                for (let y = 0; y < s.height; y += 2)
                    for (const d of [-e, -e / 2, 0, 2, 5])
                        compare(black(Math.floor(s.x + d), y), black(Math.ceil(s.x + s.width - 1 - d), y), "symmetric at " + d + ", " + y);
            }
        }

        function test_8_the_cat_beside_it() {
            cat.enabled = true;
            settled();
            tryVerify(() => cat.maskShapes.length > 0, 2000);
            const s = island.surfaceRect, e = islandTheme.notchEar;
            const spot = cat.character.parent;
            // against the notch, beyond its curves at the edge, on whichever side it stands
            if (cat.side === "left") {
                verify(spot.x + spot.width <= s.x - e + 1, "left: clear of the curve");
                verify(spot.x + spot.width >= s.x - e - 2, "left: against it");
            } else {
                verify(spot.x >= s.x + s.width + e - 1, "right: clear of the curve");
                verify(spot.x <= s.x + s.width + e + 2, "right: against it");
            }
            // on the panel: no taller than the notch, standing on its lower edge
            compare(spot.height, island.surfaceRect.height);
            compare(spot.y + spot.height, island.surfaceRect.height);
            // where it takes the pointer is not the notch's
            for (const r of cat.maskShapes)
                verify(r.x + r.width <= s.x - e + 1 || r.x >= s.x + s.width + e - 1, "its body is not over the notch");
            // with the notch open it moves aside with it
            island.expanded = true;
            settled();
            tryVerify(() => cat.side === "left" ? spot.x + spot.width <= island.surfaceRect.x - e + 1
                                                : spot.x >= island.surfaceRect.x + island.surfaceRect.width + e - 1, 2000);
        }

        function test_9_the_islands_own_look() {
            // straight where it meets the edge unless asked otherwise
            compare(islandTheme.notchEar, 0);
            islandTheme.notchBlack = false;
            islandTheme.notchLook = true;
            islandTheme.style = Styles.parse(JSON.stringify({ preset: "oxygen", material: "metal", opacity: 82, blur: true, border: true, shadow: 2,
                                                               background: "#1a1b1d" }), null);
            // its material, see-through and blur; never a border or shadow, matte at the edge
            compare([islandTheme.material, islandTheme.alpha, islandTheme.blurWanted, islandTheme.borderWidth, islandTheme.shadowLevel],
                    ["metal", 0.82, true, 0, 0]);
            compare([String(islandTheme.highlight), String(islandTheme.innerShadow)], [String(Qt.rgba(0, 0, 0, 0)), String(Qt.rgba(0, 0, 0, 0))]);
            // metal from top to bottom, in the notch's one outline
            compare(islandTheme.notchBody.length, 3);
            compare(islandTheme.notchBodyAngle, 180);
            verify(islandTheme.notchBody[0].hslLightness > islandTheme.notchBody[2].hslLightness);
            settled();
            wait(100);
            const img = grabImage(island), s = island.surfaceRect;
            const ground = img.pixel(2, island.height - 2);
            // see-through: the top row shows the ground through it, but is drawn edge to edge
            for (let x = Math.ceil(s.x) + 1; x < s.x + s.width - 1; x += 4) {
                const c = img.pixel(x, 0);
                verify(!Qt.colorEqual(c, ground), "drawn at " + x);
            }
            verify(Qt.colorEqual(img.pixel(s.x - 2, 1), ground), "nothing beside it at the edge");
            verify(islandTheme.contrast(islandTheme.text, islandTheme.surface) >= 4.5);
            islandTheme.notchLook = false;
            islandTheme.style = Styles.defaults("oxygen");
        }

        function test_10_off_it_is_the_island_as_ever() {
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
