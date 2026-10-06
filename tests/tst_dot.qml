/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Dot mode (Island.qml, ActivityManager.qml): a click on the small island
    shrinks it to a dot in the pill's place, a click on the dot brings back the
    closed pill; off, a click opens the island as it always did. What the dot
    does with events (shows them as a colour and keeps them, opens for them,
    nothing; critical ones always), hovering, the button of the open island
    (a click on its empty room does not shrink it),
    and where the island takes the pointer in each form.
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"

Item {
    id: root
    width: 760
    height: 300

    Theme { id: islandTheme; follow: false }
    ActivityManager { id: activities; maxEventAge: 400 }
    PlasmaBackend { id: plasma }
    Activity { id: stopwatch; activityId: "stopwatch"; category: "timer"; icon: "chronometer"; title: "Stopwatch"; Component.onCompleted: activities.register(this) }
    Activity { id: mic; activityId: "mic"; category: "privacy"; indicatorOnly: true; color: "#ff9f0a"; Component.onCompleted: activities.register(this) }
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
        collapseDelay: 80
        dotMode: true
        pageOrder: "other"
        extraPages: [{ key: "other", icon: "chronometer", title: "Other", component: otherPage, visible: true }]
    }

    TestCase {
        name: "Dot"
        when: windowShown

        function find(test) { let found = null; const walk = item => { if (found === null && test(item)) found = item; for (const c of item.children) walk(c); }; walk(island); return found; }
        function settled() { tryVerify(() => Math.abs(island.surfaceRect.width - island.targetWidth) < 0.001 && Math.abs(island.surfaceRect.height - island.targetHeight) < 0.001 && Math.abs(island.surfaceRadius - island.targetRadius) < 0.001, 2000); }
        function away() { mouseMove(root, 40, 280); wait(30); }
        function onIsland() { return [island.surfaceRect.x + island.surfaceRect.width / 2, island.surfaceRect.y + island.surfaceRect.height / 2]; }
        function initTestCase() { Lang.setting = "en"; activities.warm = true; }
        function cleanup() {
            away(); island.hoverSpent = false;
            stopwatch.active = false; mic.active = false;
            activities.queue = []; activities.countWaiting();
            if (activities.currentEvent) activities.dismissEvent();
            island.dotMode = true; island.dotEvents = 0; island.dotCriticalExpand = true; island.dotHoverExpand = false; island.dotSize = 15;
            island.expanded = false; island.dot = false;
            wait(60); settled();
        }

        function test_1_a_click_makes_a_dot_and_a_click_the_pill() {
            compare(island.mode, "idle");
            const [x, y] = onIsland();
            mouseClick(root, x, y);
            compare([island.mode, island.dot, island.expanded], ["dot", true, false]);
            settled();
            compare([island.surfaceRect.width, island.surfaceRect.height, island.surfaceRadius], [15, 15, 7.5]);
            // in the pill's place: the same centre
            fuzzyCompare(island.surfaceRect.x + 7.5, x, 0.6);
            fuzzyCompare(island.surfaceRect.y + 7.5, y, 0.6);
            // the pointer is still on it: nothing opens
            wait(200);
            compare(island.mode, "dot");
            // the dot's click: the closed pill, although the pointer is on it
            mouseClick(root, x, y);
            compare([island.mode, island.dot], ["idle", false]);
            settled();
            wait(200);
            compare(island.expanded, false, "back to the closed pill");
            compare(island.surfaceRect.width, islandTheme.pillWidth);
            // once the pointer has left, hovering opens it as always
            away(); wait(350);
            compare(island.hoverSpent, false);
            mouseMove(root, x, y - 2); mouseMove(root, x, y);
            tryCompare(island, "expanded", true);
        }

        function test_2_off_a_click_opens_the_island() {
            island.dotMode = false;
            const [x, y] = onIsland();
            mouseClick(root, x, y);
            compare([island.expanded, island.dot, island.mode], [true, false, "expanded"]);
            compare(find(i => i.objectName === "shrinkButton").visible, false);
            // switched off while it is a dot: the pill comes back
            island.expanded = false; island.dotMode = true; island.dot = true;
            compare(island.mode, "dot");
            island.dotMode = false;
            compare([island.dot, island.mode], [false, "idle"]);
        }

        function test_3_the_dot_takes_the_pointer_a_little_around_it() {
            island.dot = true; settled();
            compare([island.hitRect.width, island.hitRect.height, island.hitRadius], [24, 24, 12]);
            fuzzyCompare(island.hitRect.x + 12, island.surfaceRect.x + 7.5, 0.01);
            // a click beside the dot, inside the target
            mouseClick(root, island.surfaceRect.x - 3, island.surfaceRect.y + 7);
            compare(island.dot, false);
            settled();
            // the other forms: the shape itself
            compare(island.hitRect, island.surfaceRect);
            island.dotSize = 28; island.dot = true; settled();
            compare([island.surfaceRect.width, island.hitRect.width], [28, 28]);
        }

        function test_4_hovering_the_dot() {
            island.dot = true; settled();
            const [x, y] = onIsland();
            mouseMove(root, x, y);
            tryCompare(island, "dotGlow", 1);
            wait(200);
            compare([island.expanded, island.mode], [false, "dot"], "it glows, it does not open");
            away();
            tryCompare(island, "dotGlow", 0);
            // the setting: hovering opens it, and it returns to the dot
            island.dotHoverExpand = true;
            mouseMove(root, x, y);
            tryCompare(island, "expanded", true);
            compare(island.dot, true);
            away();
            tryCompare(island, "mode", "dot");
        }

        function test_5_the_button_of_the_open_island() {
            const [x, y] = onIsland();
            mouseMove(root, x, y);
            tryCompare(island, "expanded", true);
            settled(); wait(250);
            const button = find(i => i.objectName === "shrinkButton");
            verify(button.visible);
            mouseClick(button);
            compare([island.mode, island.dot, island.expanded], ["dot", true, false]);
            settled();
            compare(island.surfaceRect.width, 15);
        }

        function test_5b_the_open_island_a_click_right_after_it_opened_but_not_on_its_empty_surface() {
            const [x, y] = onIsland();
            mouseMove(root, x, y);
            tryCompare(island, "expanded", true);
            compare(island.grace, true);
            // the pointer rests: the click still means the pill, not the tab that came under it
            const tab = expandedPage();
            mouseClick(root, x, y);
            compare([island.mode, island.dot, expandedPage()], ["dot", true, tab]);
            island.dot = false; away(); wait(350); settled();
            // the pointer moved on: clicks are the open island's again
            mouseMove(root, x, y);
            tryCompare(island, "expanded", true);
            settled(); wait(250);
            mouseMove(root, x + 20, y + 40);
            compare(island.grace, false);
            const settings = find(i => i.objectName === "shrinkButton").parent.children;
            let asked = 0;
            const count = () => asked++;
            island.settingsRequested.connect(count);
            mouseClick(settings[settings.length - 1]);
            island.settingsRequested.disconnect(count);
            compare([asked, island.mode], [1, "expanded"], "a button's click is the button's");
            // the empty surface of the open island: nothing (a page being filled in is not lost to a click beside a field)
            mouseClick(root, island.surfaceRect.x + island.surfaceRect.width / 2, island.surfaceRect.y + island.surfaceRect.height - 30);
            wait(150);
            compare([island.mode, island.dot, island.expanded], ["expanded", false, true]);
            // and after the moment has passed, without moving
            away(); wait(350); settled();
            mouseMove(root, x, y);
            tryCompare(island, "expanded", true);
            tryCompare(island, "grace", false, 2000);
        }
        function expandedPage() { return find(i => i.objectName === "expandedContent").currentIndex; }

        function test_6_events_only_as_the_dots_colour_and_not_lost() {
            island.dot = true; settled();
            verify(island.dotColor.a === 0, "nothing to say: the island's own body");
            activities.flash({ key: "volume", title: "Volume" });
            activities.flash({ kind: "notification", key: "n1", notification: { summary: "Hello", body: "there", applicationName: "Test" } });
            wait(300);
            compare([island.mode, activities.currentEvent, activities.waiting], ["dot", null, 1]);
            verify(Qt.colorEqual(island.dotColor, islandTheme.accent));
            // older than an event may get: the passing one is gone, the notification waits
            wait(500);
            compare(island.mode, "dot");
            // a live activity pulses, a privacy indicator gives its colour
            stopwatch.active = true;
            tryCompare(island, "dotPulse", true);
            mic.active = true;
            tryVerify(() => Qt.colorEqual(island.dotColor, "#ff9f0a"));
            compare(island.mode, "dot");
            stopwatch.active = false; mic.active = false;
            // back to the pill: what waited is shown
            const [x, y] = onIsland();
            mouseClick(root, x, y);
            tryCompare(island, "mode", "notification");
            compare([activities.currentEvent.key, activities.waiting, activities.queue.length], ["n1", 0, 0]);
        }

        function test_7_critical_events_open_it_and_it_returns() {
            island.dot = true; settled();
            activities.flash({ key: "call", title: "Incoming call", force: true, duration: 300 });
            tryCompare(island, "mode", "event");
            compare(island.dot, true);
            tryCompare(island, "mode", "dot", 2000);
            // not wanted: it waits like the others, in its own colour
            island.dotCriticalExpand = false;
            activities.flash({ key: "power", title: "Low battery", critical: true });
            wait(250);
            compare([island.mode, activities.waitingCritical], ["dot", true]);
            verify(Qt.colorEqual(island.dotColor, "#ffd60a"));
        }

        function test_8_events_open_it_briefly_or_show_nothing() {
            island.dotEvents = 1; island.dot = true; settled();
            activities.flash({ key: "volume", title: "Volume", duration: 250 });
            tryCompare(island, "mode", "event");
            tryCompare(island, "mode", "dot", 2000);
            compare(island.dot, true);
            // nothing: no colour, no pulse; a notification still waits for the pill
            island.dotEvents = 2;
            stopwatch.active = true;
            activities.flash({ kind: "notification", key: "n2", notification: { summary: "Hello", body: "there", applicationName: "Test" } });
            wait(250);
            compare([island.mode, island.dotPulse, island.dotColor.a, activities.waiting], ["dot", false, 0, 1]);
            stopwatch.active = false;
        }

        function test_9_a_picture_of_it() {
            island.dot = true; settled();
            grabImage(root).save("/tmp/claude-1000/dot-idle.png");
            mic.active = true; wait(100);
            grabImage(root).save("/tmp/claude-1000/dot-mic.png");
        }
    }
}
