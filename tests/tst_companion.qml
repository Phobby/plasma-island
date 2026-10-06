/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The companion on the island (contents/ui/companion): the real Island with
    the cat beside it, as main.qml puts it there. Where it sits in each form
    of the island and on each side, where it takes the pointer and that the
    pointer on it is not the pointer on the island, what stroking and clicking
    do with a real pointer, what it is told by the ActivityManager, the dot,
    reduced motion, and that nothing runs while it sleeps or is hidden.

    Its rules by themselves, with the clock handed in: tests/companion.test.js.
    The times are shortened here (the controller's `tuning`), never the clock.
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"
import "../org.phobby.dynamicisland/contents/ui/companion"
import "../org.phobby.dynamicisland/contents/ui/companion/CompanionTuning.js" as Tuning
import "../org.phobby.dynamicisland/contents/ui/companion/CatPoses.js" as Poses

Item {
    id: root
    width: 900
    height: 320

    Theme { id: islandTheme; follow: false }
    ActivityManager { id: activities; maxEventAge: 400 }
    PlasmaBackend { id: plasma }
    Activity { id: stopwatch; activityId: "stopwatch"; category: "timer"; icon: "chronometer"; title: "Stopwatch"; Component.onCompleted: activities.register(this) }
    Activity { id: transfer; activityId: "transfer"; category: "transfer"; icon: "download"; title: "Download"; Component.onCompleted: activities.register(this) }
    Activity { id: media; activityId: "media"; category: "media"; title: "Song"; Component.onCompleted: activities.register(this) }
    Activity { id: habit; activityId: "habits"; category: "habits"; asks: true; title: "How was today?"; Component.onCompleted: activities.register(this) }
    Activity { id: mic; activityId: "mic"; category: "privacy"; indicatorOnly: true; color: "#ff9f0a"; Component.onCompleted: activities.register(this) }
    QtObject { id: fakeAi; property bool busy: false; signal answered(string text); signal failed(string problem) }
    Component { id: otherPage; Item { property bool asking: false; objectName: "otherPage" } }

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
        collapseDelay: 80
        dotMode: true
        pageOrder: "notes"
        extraPages: [{ key: "notes", icon: "chronometer", title: "Other", component: otherPage, visible: true }]
        Companion { id: companion; island: island; theme: islandTheme; ai: fakeAi }
    }

    TestCase {
        id: test
        name: "Companion"
        when: windowShown

        readonly property var mind: companion.mind
        property var gestures: []
        // the times of the test: a tenth of the real ones
        readonly property var quick: Object.assign({}, Tuning.TUNING, {
            petWindow: 1200, petLinger: 300, makeUpAfter: 600, clickWindow: 1500, angryFor: 350, startleFor: 200, annoyedFor: 250,
            dozeFor: 150, wakeFor: 150, perkFor: 200, cheerFor: 200, tiredFor: 200, exclaimFor: 250, noteFor: 200 })

        function find(name) { let found = null; const walk = item => { if (found === null && item.objectName === name) found = item; for (const c of item.children) walk(c); }; walk(island); return found; }
        function settled() { tryVerify(() => Math.abs(island.surfaceRect.width - island.targetWidth) < 0.001 && Math.abs(island.surfaceRect.height - island.targetHeight) < 0.001, 3000); wait(320); }
        function spot() { return find("companionSpot"); }
        function onPill() { return [island.surfaceRect.x + island.surfaceRect.width / 2, island.surfaceRect.y + island.surfaceRect.height / 2]; }
        // the middle of the cat's head, and of its body
        function onCat(part) { const shapes = companion.maskShapes, s = shapes[part === "body" && shapes.length > 1 ? 1 : 0]; return [s.x + s.width / 2, s.y + s.height / 2]; }
        function away() { mouseMove(root, 30, 300); wait(30); }
        // the hand goes back and forth over the cat's head: `turns` strokes of `far` px each way
        function rub(turns, far, gap) {
            const [x, y] = onCat("head");
            for (let i = 0; i < turns; ++i)
                for (let k = 0; k <= 6; ++k) { mouseMove(root, x + (i % 2 ? far - 2 * far * k / 6 : -far + 2 * far * k / 6), y); wait(gap === undefined ? 12 : gap); }
        }
        function all() { return [mind.body, mind.accessory, mind.bubble, mind.tilt]; }
        function asleep() { companion.sleepSeconds = 1; mind.sleepAfter = 250; tryCompare(mind, "body", "sleep", 4000); }

        Connections { target: companion.mind; function onGesture(name) { test.gestures.push(name); } }

        function initTestCase() { Lang.setting = "en"; activities.warm = true; }
        function init() {
            mind.tuning = quick;
            mind.sulkFor = 500;
            mind.sleepAfter = 600000;
            gestures = [];
        }
        function cleanup() {
            away(); island.hoverSpent = false;
            stopwatch.active = false; transfer.active = false; media.active = false; habit.active = false; mic.active = false; fakeAi.busy = false;
            activities.queue = []; activities.countWaiting();
            if (activities.currentEvent) activities.dismissEvent();
            island.expanded = false; island.dot = false;
            companion.enabled = true; companion.sideSetting = 0; companion.sizePercent = 130; companion.dotBehaviour = 0; companion.reduceMotion = false;
            companion.spaceLeft = 100000; companion.spaceRight = 100000;
            companion.music = true; companion.thoughts = true; companion.events = true; companion.petting = true; companion.clicks = true; companion.noAnger = false;
            mind.sleepAfter = 600000;
            // (what it felt is forgotten)
            companion.enabled = false; companion.enabled = true;
            wait(60); settled();
        }

        // ---- where it sits ---------------------------------------------------------------------
        function test_01_beside_the_pill_on_the_left() {
            const s = spot(), pill = island.surfaceRect;
            compare([companion.side, companion.mirrored, s.visible], ["left", false, true]);
            compare([s.height, s.width], [Math.round(islandTheme.pillHeight * 1.3), Math.round(Math.round(islandTheme.pillHeight * 1.3) * Poses.W / Poses.H)]);
            fuzzyCompare(s.x + s.width, pill.x + 1, 0.01);
            // on the pill's level, a little lower, and inside the window
            verify(s.y >= 1 && s.y < pill.y, "its head stands a little above the pill: " + s.y);
            verify(s.y + s.height > pill.y + pill.height && s.y + s.height <= islandTheme.windowTopPad + islandTheme.pillHeight + islandTheme.windowBottomPad);
            // the bubble: on the far side of its head, inside the window too
            fakeAi.busy = true;
            const b = find("companionBubble");
            tryVerify(() => b.visible && b.opacity > 0.99);
            verify(b.x + b.width <= s.x + s.width / 2 && b.x >= pill.x - companion.reserve - islandTheme.windowSidePad, "the bubble is beside its head: " + b.x);
            verify(b.y >= 0);
            // the size setting, within its limits
            companion.sizePercent = 180;
            compare(s.height, Math.round(islandTheme.pillHeight * 1.8));
            verify(s.y >= 1 && s.y + s.height <= islandTheme.windowTopPad + islandTheme.pillHeight + islandTheme.windowBottomPad, "the largest cat fits the small window");
            companion.sizePercent = 500;
            compare(s.height, Math.round(islandTheme.pillHeight * 1.8));
            companion.sizePercent = 20;
            compare(s.height, islandTheme.pillHeight);
        }
        function test_02_it_follows_the_island_and_covers_nothing() {
            const s = spot();
            for (const form of ["live", "split", "event", "notification", "expanded"]) {
                if (form === "live") stopwatch.active = true;
                else if (form === "split") transfer.active = true;
                else if (form === "event") { stopwatch.active = false; transfer.active = false; wait(60); activities.flash({ title: "Charging", icon: "battery", duration: 5000 }); }
                else if (form === "notification") { activities.dismissEvent(); wait(300); activities.flash({ kind: "notification", title: "Hi", notification: { summary: "Hi", body: "there" }, duration: 5000 }); }
                else { activities.dismissEvent(); wait(300); island.expanded = true; }
                tryCompare(island, "mode", form);
                settled();
                const pill = island.surfaceRect;
                fuzzyCompare(s.x + s.width, pill.x + 1, 0.01, "beside the island as " + form);
                verify(s.x >= 0, "inside the window as " + form + ": " + s.x);
                verify(s.y + s.height <= pill.y + pill.height + 12, "at the island's top as " + form);
            }
            // the window keeps the room: the widest island of each window, the cat and its bubble beside it
            verify(companion.reserve >= s.width + find("companionBubble").width * 0.8);
        }
        function test_03_on_the_right_it_keeps_clear_of_the_bubble_and_the_dots() {
            const s = spot();
            companion.sideSetting = 2;
            tryCompare(companion, "cross", 0, 3000);
            compare([companion.side, companion.mirrored], ["right", true]);
            fuzzyCompare(s.x, island.surfaceRect.x + island.surfaceRect.width - 1, 0.01);
            // the split island's bubble comes out: the cat moves over, it does not jump
            stopwatch.active = true; transfer.active = true;
            tryCompare(island, "mode", "split");
            settled();
            verify(island.bubbleRect.width > 0);
            // (the bubble comes out on a spring: once that has come to rest)
            tryVerify(() => s.x >= island.bubbleRect.x + island.bubbleRect.width - 1.01, 2000, "right of the bubble: " + s.x + " / " + (island.bubbleRect.x + island.bubbleRect.width));
            // a privacy dot too
            const before = s.x;
            mic.active = true;
            tryVerify(() => activities.indicators.length === 1);
            wait(30);
            verify(s.x < before + islandTheme.privacyDotSize, "it does not jump aside");
            tryVerify(() => s.x >= before + islandTheme.privacyDotSize + 8, 2000);
            tryVerify(() => Math.abs(s.x - (island.surfaceRect.x + island.surfaceRect.width + island.besideRight - 1)) < 0.6, 2000, "right of the dots");
            verify(island.besideRight > islandTheme.splitGap + islandTheme.bubbleSize + 8 + islandTheme.privacyDotSize);
            // on the left none of that concerns it
            companion.sideSetting = 1;
            tryCompare(companion, "cross", 0, 3000);
            fuzzyCompare(s.x + s.width, island.surfaceRect.x + 1, 0.01);
        }
        function test_04_a_change_of_sides_is_a_walk_across() {
            const s = spot(), from = s.x;
            companion.sideSetting = 2;
            compare(companion.side, "right");
            fuzzyCompare(s.x, from, 0.01, "it starts where it was");
            compare(companion.mirrored, false, "and turns round on the way");
            let steps = 0, last = s.x, back = 0;
            while (companion.cross !== 0 && steps++ < 400) { wait(16); if (s.x < last - 0.01) ++back; last = s.x; }
            compare(back, 0, "never backwards");
            verify(steps > 8, "over several frames: " + steps);
            compare(companion.mirrored, true);
            fuzzyCompare(s.x, island.surfaceRect.x + island.surfaceRect.width - 1, 0.01);
        }
        function test_05_no_room_on_one_side_of_the_screen() {
            const need = spot().width + companion.bubbleRoom + 6, half = islandTheme.expandedWidth / 2;
            compare(companion.wanted, "left");
            // the island near the screen's left edge: by itself it goes right
            companion.spaceLeft = half + need - 1;
            compare(companion.wanted, "right");
            companion.spaceLeft = half + need;
            compare(companion.wanted, "left");
            // set to the right, no room there: left
            companion.sideSetting = 2;
            compare(companion.wanted, "right");
            companion.spaceRight = half + need - 1;
            compare(companion.wanted, "left");
            // room on neither side: where it was told
            companion.spaceLeft = 10;
            compare(companion.wanted, "right");
        }

        // ---- the dot -----------------------------------------------------------------------------
        function test_06_hidden_beside_a_dot_and_back_with_the_pill() {
            const s = spot();
            island.dot = true;
            tryCompare(s, "visible", false);
            compare([companion.shown, mind.active, companion.maskShapes.length], [false, false, 0]);
            compare(mind.nextDue >= 0 && mind.timer.running, false, "nothing runs for a hidden cat");
            compare(find("companionCat").moving && find("companionCat").running, false);
            island.dot = false;
            tryVerify(() => s.visible && companion.presence > 0.99);
            compare([companion.shown, mind.active, companion.maskShapes.length], [true, true, 2]);
        }
        function test_07_or_asleep_beside_the_dot() {
            const s = spot();
            companion.dotBehaviour = 1;
            media.active = true; fakeAi.busy = true;
            tryCompare(mind, "accessory", "headphones");
            island.dot = true;
            tryCompare(mind, "body", "sleep", 3000);
            compare([s.visible, mind.accessory, mind.bubble], [true, "", "zzz"]);
            tryCompare(mind, "nextDue", -1, 2000);
            settled();
            fuzzyCompare(s.x + s.width, island.hitRect.x + 1, 0.01, "beside the dot");
            compare(companion.maskShapes.length, 1);
            island.dot = false;
            tryCompare(mind, "accessory", "headphones", 3000);
        }
        function test_08_switched_off() {
            companion.enabled = false;
            tryCompare(spot(), "visible", false);
            compare([companion.reserve, companion.maskShapes.length, mind.active, mind.timer.running], [0, 0, false, false]);
            companion.enabled = true;
            verify(companion.reserve > 0);
        }

        // ---- where it takes the pointer -------------------------------------------------------------
        function test_09_its_body_takes_the_pointer_the_air_around_it_does_not() {
            const s = spot();
            compare(companion.maskShapes.length, 2);
            for (const shape of companion.maskShapes) {
                verify(shape.x >= s.x && shape.x + shape.width <= s.x + s.width + 0.5 && shape.y >= s.y && shape.y + shape.height <= s.y + s.height + 0.5, "inside the cat");
                verify(shape.x + shape.width <= island.surfaceRect.x + 2, "not over the pill");
            }
            // on the head, on the body
            for (const part of ["head", "body"]) {
                const [x, y] = onCat(part);
                mouseMove(root, x, y); wait(20);
                compare(companion.hovered, true, part);
                away();
                compare(companion.hovered, false);
            }
            // the corner of its box above its tail: air
            mouseMove(root, s.x + 2, s.y + 2); wait(20);
            compare(companion.hovered, false, "the corner of its box is air");
            // its tail is not a handle
            mouseMove(root, s.x + 4 * s.width / Poses.W, s.y + 45 * s.height / Poses.H); wait(20);
            compare(companion.hovered, false, "nor is its tail");
            // its bubble takes nothing
            fakeAi.busy = true;
            const b = find("companionBubble");
            tryVerify(() => b.opacity > 0.99);
            mouseMove(root, b.x + b.width * 0.3, b.y + b.height * 0.4); wait(20);
            compare([companion.hovered, island.hovered], [false, false], "the bubble takes nothing");
            mouseClick(root, b.x + b.width * 0.3, b.y + b.height * 0.4);
            compare([mind.body, island.expanded, island.dot], ["sit", false, false]);
        }
        function test_10_the_region_follows_its_pose_and_not_its_fidgets() {
            const before = JSON.stringify(companion.maskShapes);
            for (const g of ["blink", "tail", "ear", "hop", "lick"]) find("companionCat").gesture(g);
            wait(200);
            compare(JSON.stringify(companion.maskShapes), before, "a hop or a flick of the tail moves no region");
            asleep();
            compare(companion.maskShapes.length, 1, "curled up: one shape");
            const curled = companion.maskShapes[0], s = spot();
            verify(curled.y > s.y + s.height * 0.5 && curled.y + curled.height <= s.y + s.height + 0.5, "low, where it lies");
            // above the sleeping cat, where its head was: air now
            mouseMove(root, s.x + s.width * 0.65, s.y + s.height * 0.2); wait(20);
            compare(companion.hovered, false);
        }
        function test_11_the_pointer_on_the_cat_is_not_the_pointer_on_the_island() {
            const [cx, cy] = onCat("body");
            mouseMove(root, cx, cy); wait(250);
            compare([companion.hovered, island.hovered, island.expanded, activities.hovered], [true, false, false, false]);
            // from the pill to the cat and back, quickly, many times: the island opens once and does not flutter
            const [px, py] = onPill();
            let changes = 0, was = island.expanded;
            for (let i = 0; i < 12; ++i) {
                mouseMove(root, px - island.surfaceRect.width / 2 + 6, py); wait(25);
                if (island.expanded !== was) { ++changes; was = island.expanded; }
                const [x, y] = companion.maskShapes.length > 0 ? onCat("body") : [cx, cy];
                mouseMove(root, x, y); wait(25);
                if (island.expanded !== was) { ++changes; was = island.expanded; }
            }
            verify(changes <= 1, "the island changed " + changes + " times");
            // open, the pointer goes over to the cat: the cat does not hold the island open
            away(); wait(400);
            island.expanded = true; settled();
            mouseMove(root, px, py + 30); wait(40);
            compare(island.hovered, true);
            const [ex, ey] = onCat("body");
            mouseMove(root, ex, ey); wait(30);
            compare([companion.hovered, island.hovered], [true, false]);
            tryCompare(island, "expanded", false, 2000);
        }
        function test_12_a_click_on_the_cat_is_the_cats() {
            const [x, y] = onCat("body");
            mouseClick(root, x, y);
            compare([island.dot, island.expanded, mind.body], [false, false, "curious"]);
            // and one on the pill is the island's
            away(); wait(300);
            const [px, py] = onPill();
            mouseClick(root, px, py);
            compare(island.dot, true);
        }

        // ---- stroking and clicking, with a pointer ---------------------------------------------------
        function test_13_stroking() {
            const [x, y] = onCat("head");
            // resting on it: a look
            mouseMove(root, x - 3, y); mouseMove(root, x, y); wait(700);
            compare(all(), ["curious", "", "", false]);
            // passing over it once: nothing more
            away();
            for (let k = -16; k <= 8; k += 2) { mouseMove(root, x + k, y); wait(8); }
            compare(mind.body, "curious");
            away(); wait(60);
            compare(mind.body, "sit");
            // back and forth: stroked
            rub(5, 9);
            compare(all(), ["pet", "", "heart", false]);
            // the hand rests: a moment later it is over
            tryCompare(mind, "body", "curious", 2000);
            away();
            compare(mind.body, "sit");
            // too small a movement is not one
            rub(12, 2);
            verify(mind.body !== "pet", "trembling on the spot");
            away();
            // switched off
            companion.petting = false;
            rub(6, 9);
            verify(mind.body !== "pet");
        }
        function test_14_stroked_in_its_sleep() {
            asleep();
            rub(6, 8);
            compare([mind.body, mind.bubble], ["purr", "heart"]);
            away();
            tryCompare(mind, "body", "sleep", 2000);
            compare(gestures.indexOf("stretch"), -1, "it never woke");
        }
        function test_15_clicks() {
            const [x, y] = onCat("body");
            mouseClick(root, x, y);
            compare(mind.body, "curious");
            mouseClick(root, x, y);
            compare(mind.body, "annoyed");
            mouseClick(root, x, y);
            compare([mind.body, mind.bubble], ["angry", "hiss"]);
            tryCompare(mind, "body", "sulk", 2000);
            // sulking: no click moves it, the pointer gets a flick of the tail
            away(); gestures = [];
            mouseMove(root, x, y); wait(30);
            verify(gestures.indexOf("shoo") >= 0);
            mouseClick(root, x, y); mouseClick(root, x, y);
            compare(mind.body, "sulk");
            // a short stroke is not taken, a long one makes up
            rub(4, 9);
            compare(mind.body, "sulk");
            mind.sulkFor = 60000;
            mouseClick(root, x, y);
            away(); wait(700);
        }
        function test_16_a_long_stroke_makes_up() {
            const [x, y] = onCat("body");
            mind.sulkFor = 60000;
            mouseClick(root, x, y); mouseClick(root, x, y); mouseClick(root, x, y);
            tryCompare(mind, "body", "sulk", 2000);
            rub(3, 9);
            compare(mind.body, "sulk", "not at once");
            rub(30, 9);
            compare([mind.body, mind.bubble], ["pet", "heart"]);
        }
        function test_17_clicked_awake_from_sleep() {
            asleep();
            mouseClick(root, onCat("body")[0], onCat("body")[1]);
            compare([mind.body, mind.bubble], ["angry", "hiss"]);
            tryCompare(mind, "body", "sulk", 2000);
            away();
            tryCompare(mind, "body", "sleep", 3000);
        }
        function test_18_never_angry_and_clicks_switched_off() {
            companion.noAnger = true;
            const [x, y] = onCat("body");
            for (let i = 0; i < 6; ++i) mouseClick(root, x, y);
            compare(mind.body, "curious");
            asleep();
            mouseClick(root, onCat("body")[0], onCat("body")[1]);
            compare(mind.body, "wake");
            tryCompare(mind, "body", "curious", 2000);
            away();
            companion.noAnger = false; companion.clicks = false;
            asleep();
            for (let i = 0; i < 4; ++i) mouseClick(root, onCat("body")[0], onCat("body")[1]);
            compare(mind.body, "sleep");
        }
        function test_19_the_right_button_is_its_own_menu() {
            // (a menu cannot open off screen: the click is looked at instead)
            let opened = 0, hidden = 0, settings = 0;
            const menu = companion.openMenu, a = () => ++hidden, b = () => ++settings;
            companion.openMenu = () => ++opened;
            companion.hideRequested.connect(a); companion.settingsRequested.connect(b);
            const [x, y] = onCat("body");
            mouseClick(root, x, y, Qt.RightButton);
            compare([opened, island.menuOpen, mind.body], [1, false, "sit"], "its own menu: not the island's, and not a click on the cat");
            // beside the cat, and on its bubble: nobody's
            mouseClick(root, spot().x + 2, spot().y + 2, Qt.RightButton);
            compare(opened, 1);
            companion.hideRequested(); companion.settingsRequested();
            compare([hidden, settings], [1, 1]);
            companion.hideRequested.disconnect(a); companion.settingsRequested.disconnect(b);
            companion.openMenu = menu;
        }

        // ---- what it is told -------------------------------------------------------------------------
        function test_20_music_the_ai_and_questions() {
            media.active = true;
            tryCompare(mind, "accessory", "headphones");
            compare(mind.body, "listen");
            fakeAi.busy = true;
            compare(all(), ["listen", "headphones", "dots", true]);
            fakeAi.busy = false; fakeAi.answered("42");
            compare(mind.bubble, "exclaim");
            tryCompare(mind, "bubble", "", 2000);
            media.active = false;
            tryCompare(mind, "accessory", "");
            // a question with buttons, for as long as it is shown
            wait(300);
            activities.flash({ key: "suggestion", title: "Mute?", buttons: [{ text: "Yes" }, { text: "No" }], duration: 5000 });
            tryCompare(mind, "bubble", "question");
            tryCompare(mind, "tilt", true);          // (once it has looked at what came up)
            activities.chooseEvent(0);
            tryCompare(mind, "bubble", "");
            // the habits' evening question: its event, and its waiting activity
            activities.flash({ key: "habits", feel: "ask", title: "How was today?", duration: 5000 });
            tryCompare(mind, "bubble", "question");
            activities.dismissEvent();
            tryCompare(mind, "bubble", "");
            habit.active = true;
            tryCompare(mind, "bubble", "question");
            habit.active = false;
            tryCompare(mind, "bubble", "");
            // a page that asks
            island.expanded = true; settled();
            find("otherPage").asking = true;
            tryCompare(mind, "bubble", "question");
            find("otherPage").asking = false;
            tryCompare(mind, "bubble", "");
        }
        function test_21_events() {
            activities.flash({ key: "timer-done", feel: "done", title: "Timer done", duration: 400 });
            tryCompare(mind, "body", "cheer");
            tryCompare(mind, "body", "sit", 3000);
            activities.flash({ key: "power", feel: "low", title: "Low battery", duration: 400 });
            tryCompare(mind, "body", "tired");
            tryCompare(mind, "body", "sit", 3000);
            wait(300);
            // asleep: an event wakes it, then it looks
            asleep();
            compare([mind.bubble, mind.nextDue, mind.timer.running], ["zzz", -1, false]);
            gestures = [];
            activities.flash({ kind: "notification", title: "Hi", notification: { summary: "Hi", body: "" }, duration: 500 });
            tryCompare(mind, "body", "wake");
            tryCompare(mind, "body", "perk", 2000);
            compare(gestures.filter(g => g === "stretch").length, 1);
            // the same event again and again (the volume) is one
            tryCompare(activities, "currentEvent", null, 3000);
            gestures = [];
            mind.sleepAfter = 600000;
            wait(300);
            for (let i = 0; i < 5; ++i) { activities.flash({ key: "volume", title: "Volume", duration: 300 }); wait(60); }
            tryCompare(activities, "currentEvent", null, 3000);
            compare(gestures.filter(g => g === "perk").length, 1);
        }

        // ---- motion --------------------------------------------------------------------------------
        function test_22_reduced_motion_still_poses() {
            companion.reduceMotion = true;
            const cat = find("companionCat"), bubble = find("companionBubble");
            compare([companion.calm, cat.still, bubble.still], [true, true, true]);
            media.active = true;
            tryCompare(mind, "accessory", "headphones");
            compare([cat.loop, cat.moving, cat.phones], ["", false, 1], "no nodding, the headphones are simply on");
            fakeAi.busy = true;
            tryCompare(bubble, "kind", "dots");
            wait(700);
            compare([cat.moving, mind.nextDue], [false, -1], "and no fidgets: nothing is due");
            gestures = [];
            cat.gesture("hop"); cat.gesture("blink");
            compare([cat.act, cat.blinkAt], ["", -1]);
            // a pose changes at once
            rub(6, 9);
            compare([mind.body, cat.poseAt], ["pet", 1]);
            // sides change without a walk
            away();
            companion.sideSetting = 2;
            compare([companion.side, companion.cross, companion.mirrored], ["right", 0, true]);
        }
        function test_23_only_what_moves_runs() {
            const cat = find("companionCat");
            wait(700);
            compare([mind.body, cat.moving], ["sit", false], "sitting still: no frames");
            verify(mind.nextDue > 0, "only the next fidget is waited for");
            media.active = true;
            tryCompare(mind, "body", "listen");
            tryCompare(cat, "loop", "bob");
            compare(cat.moving, true);
            // the music's own beat instead of the calm nod
            media.active = false;
            tryCompare(mind, "body", "sit");
            asleep();
            tryCompare(cat, "quick", false, 3000);
            compare([cat.loop, mind.timer.running, mind.nextDue], ["breath", false, -1], "asleep: the slow breath, and no timer of the mind");
        }
    }
}
