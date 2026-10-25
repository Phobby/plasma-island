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
        Companion { id: cat; island: island; theme: islandTheme; enabled: false; reduceMotion: true; sleepSeconds: 3600; sizePercent: 120 }
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
            island.expanded = false; island.dot = false; island.maxWidth = 0; cat.enabled = false; cat.sizePercent = 120;
            islandTheme.notchBorderEnabled = false; islandTheme.notchEars = false;
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
            // set wider than what it shows, it is that wide: over the whole range it never gets narrower,
            // and its window keeps room for it (nothing of it is cut)
            timer.active = false;
            tryCompare(island, "mode", "live");
            let last = 0;
            for (let w = 80; w <= 1200; w += 40) {
                island.maxWidth = w;
                settled();
                const shown = island.surfaceRect.width;
                verify(shown >= last, "wider or as wide at " + w + ": " + shown + " < " + last);
                compare(shown, Math.max(2 * islandTheme.pillHeight, w), "as wide as set at " + w);
                verify(island.smallHalfWidth * 2 >= shown + 2 * islandTheme.privacyAreaWidth - 0.5, "its window has room at " + w);
                last = shown;
            }
            verify(last > free, "wider than what it shows");
            // never wider than its screen
            islandTheme.screenWidth = 1000; islandTheme.screenHeight = 800;
            settled();
            verify(island.surfaceRect.width <= 1000 - 2 * islandTheme.screenMargin - 2 * islandTheme.windowSidePad, "kept on the screen");
            islandTheme.screenWidth = 0; islandTheme.screenHeight = 0;
            // the width is the notch's: the island without it is as wide as ever
            timer.active = true;
            tryCompare(island, "mode", "split");
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
            const s = island.surfaceRect, e = islandTheme.notchEar + cat.notchGap;
            const spot = cat.character.parent;
            // a little away from the notch (and its curves at the edge), on whichever side it stands
            if (cat.side === "left") {
                verify(spot.x + spot.width <= s.x - e + 1, "left: clear of it");
                verify(spot.x + spot.width >= s.x - e - 2, "left: near it");
            } else {
                verify(spot.x >= s.x + s.width + e - 1, "right: clear of it");
                verify(spot.x <= s.x + s.width + e + 2, "right: near it");
            }
            // its size as set; as high as the panel or less it stands on the panel's lower edge, larger from the screen's edge
            compare(spot.height, Math.round(islandTheme.pillHeight * cat.sizePercent / 100));
            compare(spot.y, Math.max(0, island.surfaceRect.height - spot.height));
            cat.sizePercent = 160;
            tryCompare(spot, "height", Math.round(islandTheme.pillHeight * 1.6));
            compare(spot.y, 0);
            cat.sizePercent = 100;
            tryCompare(spot, "height", islandTheme.pillHeight);
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
            // its material, see-through and blur, its gloss; never a border, shadow or inner shadow
            compare([islandTheme.material, islandTheme.alpha, islandTheme.blurWanted, islandTheme.borderWidth, islandTheme.shadowLevel],
                    ["metal", 0.82, true, 0, 0]);
            verify(islandTheme.highlight.a > 0);
            compare(String(islandTheme.innerShadow), String(Qt.rgba(0, 0, 0, 0)));
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

        // The curves where it meets the edge reach further down than out: the join starts lower,
        // filled from the edge to there beside the sides, and nothing beside them below it.
        function test_ears_start_lower_than_they_reach_out() {
            islandTheme.notchEars = true;
            settled(); wait(100);
            const e = islandTheme.notchEar, ed = islandTheme.notchEarDepth;
            verify(e > 0 && ed > e, "deeper (" + ed + ") than wide (" + e + ")");
            compare(ed, Math.round(islandTheme.pillHeight * islandTheme.notchEarDrop));
            const img = grabImage(island), s = island.surfaceRect;
            const black = (x, y) => { const c = img.pixel(x, y); return c.a > 0.99 && c.r < 0.01 && c.g < 0.01 && c.b < 0.01; };
            const ground = img.pixel(2, island.height - 2);
            for (const x of [Math.floor(s.x) - 1, Math.ceil(s.x + s.width)]) {
                verify(black(x, 0), "joined to the edge at " + x);
                // (just beside the side the curve is still there a little above its depth)
                verify(black(x, Math.floor(ed * 0.5)), "the curve reaches down beside " + x);
                compare(img.pixel(x, Math.ceil(ed + 3)), ground, "below it, nothing beside " + x);
            }
            islandTheme.notchEars = false;
        }

        // The size setting: the whole island is scaled by it (main.qml). Step by step over its range
        // the notch as it is shown never gets smaller, in either direction, with a top panel under it
        // or without (beyond half a pixel of rounding); it is as large as asked (within a pixel); and it
        // always covers the panel.
        function test_size_grows_the_notch_over_the_whole_range() {
            for (const panel of [0, 32]) {
                islandTheme.notchPixels = panel;
                let last = null;
                for (let size = Styles.scaleMin; size <= Styles.scaleMax; size += 5) {
                    islandTheme.style = Styles.normalize(Object.assign(Styles.defaults("symbiot"), { scale: size }));
                    compare(islandTheme.scale, size / 100, "the setting is not cut at " + size);
                    settled();
                    const k = islandTheme.scale;
                    const shown = { width: island.surfaceRect.width * k, height: island.surfaceRect.height * k };
                    if (panel > 0) verify(shown.height >= panel - 0.5, "covers the panel at " + size + ": " + shown.height);
                    if (last !== null) {
                        verify(shown.width >= last.width - 0.5, "wider or as wide at " + size + ": " + shown.width + " < " + last.width);
                        verify(shown.height >= last.height - 0.5, "higher or as high at " + size + ": " + shown.height + " < " + last.height);
                    }
                    if (size > 100 || panel === 0) {
                        // (the island's own designed size, times the setting)
                        const designed = panel > 0 ? panel : Math.round(islandTheme.gu * 2);
                        verify(Math.abs(shown.height - designed * k) <= 1, "as high as asked at " + size + ": " + shown.height + " vs " + designed * k);
                    }
                    verify(Math.abs(shown.width - Math.round(islandTheme.gu * 10) * k) <= 1, "as wide as asked at " + size);
                    last = shown;
                }
                // and past 100 % it grows in height too, not only in width
                verify(last.height > (panel > 0 ? panel : Math.round(islandTheme.gu * 2)), "taller at the top of the range");
            }
            islandTheme.notchPixels = 0;
            islandTheme.style = Styles.defaults("oxygen");
        }

        // On a screen it is kept within the screen: the size grows up to what the open island at its
        // widest and tallest has room for, then stays; the settings are told (scaleLimited).
        function test_size_is_kept_within_the_screen() {
            const screens = [[1920, 1080], [1366, 768], [1280, 800], [3840, 2160], [2560, 1440], [683, 384]];
            for (const [w, h] of screens) {
                islandTheme.screenWidth = w; islandTheme.screenHeight = h;
                let last = 0;
                for (let size = Styles.scaleMin; size <= Styles.scaleMax; size += 5) {
                    islandTheme.style = Styles.normalize(Object.assign(Styles.defaults("symbiot"), { scale: size }));
                    const k = islandTheme.scale;
                    verify(k >= last, "never smaller on " + w + "x" + h + " at " + size);
                    verify(k <= size / 100 + 1e-9, "never larger than asked");
                    // the widest and the tallest the window gets, at that size, on the screen (from 100 % up:
                    // up to 100 % it is never cut, as before there was a limit)
                    if (size <= 100) compare(k, size / 100, "not cut up to 100 % on " + w + "x" + h);
                    else if (k > 1) {
                        verify((islandTheme.wideWidth + 2 * islandTheme.windowSidePad) * k <= w, "fits across " + w + " at " + size);
                        verify((islandTheme.tallHeight + islandTheme.windowTopPad + islandTheme.windowBottomPad) * k <= h, "fits down " + h + " at " + size);
                    }
                    compare(islandTheme.scaleLimited, k < size / 100 - 0.001, "said when cut at " + size);
                    last = k;
                }
            }
            // a large screen has room for all of it
            islandTheme.screenWidth = 3840; islandTheme.screenHeight = 2160;
            islandTheme.style = Styles.normalize(Object.assign(Styles.defaults("symbiot"), { scale: Styles.scaleMax }));
            compare([islandTheme.scale, islandTheme.scaleLimited], [Styles.scaleMax / 100, false]);
            islandTheme.screenWidth = 0; islandTheme.screenHeight = 0;
            islandTheme.style = Styles.defaults("oxygen");
        }

        function test_border_is_inset_in_every_colour_mode() {
            islandTheme.notchBorderEnabled = true;
            islandTheme.notchBorderWidth = 6;
            islandTheme.notchBorderColor = "#ff0000";
            islandTheme.notchBorderOpacity = 100;
            for (const ears of [false, true]) {
                islandTheme.notchEars = ears;
                for (const mode of [0, 1, 2]) {
                    islandTheme.notchBlack = mode === 0;
                    islandTheme.notchLook = mode === 2;
                    for (const state of ["idle", "dot", "expanded", "split"]) {
                        island.dot = state === "dot";
                        island.expanded = state === "expanded";
                        stopwatch.active = state === "split";
                        timer.active = state === "split";
                        settled(); wait(100);
                        const img = grabImage(island), s = island.surfaceRect;
                        const edge = img.pixel(Math.round(s.x + s.width / 2), Math.round(s.height - 2));
                        verify(edge.r > 0.9 && edge.g < 0.1 && edge.b < 0.1, "lower border: " + mode + "/" + state + "/" + ears);
                        if (state === "expanded" || state === "idle") {
                            const y = Math.round(islandTheme.notchEarDepth + 8);
                            const side = img.pixel(Math.round(s.x + 2), y);
                            verify(side.r > 0.9 && side.g < 0.1, "side border follows the outline");
                            compare(img.pixel(Math.round(s.x - 2), y), img.pixel(2, island.height - 2), "side border stays inside the mask");
                        }
                        const top = img.pixel(Math.round(s.x + s.width / 2), 0);
                        verify(top.g > 0.1 || top.r < 0.9, "no border across the screen edge");
                        compare(img.pixel(Math.round(s.x + s.width / 2), Math.ceil(s.height + 2)), img.pixel(2, island.height - 2), "nothing outside the mask");
                    }
                }
            }
            islandTheme.notchBorderOpacity = 25;
            fuzzyCompare(islandTheme.notchEdgeColor.a, 0.25, 0.01);
            islandTheme.notch = false;
            compare(islandTheme.notchEdgeWidth, 0);
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
