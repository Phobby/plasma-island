/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The AI tab and the island itself (the real Island with the real page and
    backend; a stand-in answers): the island grows taller for a conversation
    and gives the room back, and it stays open while an answer is written
    even when the pointer leaves. On the small island: three dots while an
    answer is on its way and nobody looks, below every other activity; then
    "Answer ready", which opens the tab; or nothing, when that is switched off.
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"
import "../org.phobby.dynamicisland/contents/ui/ai"
import "../org.phobby.dynamicisland/contents/ui/backend"
import "../org.phobby.dynamicisland/contents/ui/providers"

Item {
    id: root
    width: 760
    height: 470

    Theme { id: islandTheme; follow: false }
    ActivityManager { id: activities }
    PlasmaBackend { id: plasma }

    property var live: null
    property int cancelled: 0
    Component {
        id: fake
        AiProvider {
            function verify(done) { done({ ok: true, models: [], problem: null }); }
            function send(messages, model, options) { root.live = this; }
            function cancel() { ++root.cancelled; }
        }
    }
    AiBackend { id: backend; enabled: true }
    AiActivityProvider {
        id: onTheIsland
        manager: activities
        theme: islandTheme
        ai: backend
        onOpened: island.openPage("ai")
    }
    // (something else that is going on, to rank against)
    Activity {
        id: stopwatch
        activityId: "stopwatch"
        category: "timer"
        icon: "chronometer"
        title: "Stopwatch"
        Component.onCompleted: activities.register(this)
    }
    Component { id: aiPage; AiPage { theme: islandTheme; ai: backend } }
    Component { id: otherPage; Item {} }
    // (a page that keeps the wheel for a list of its own while it is shown)

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
        collapseDelay: 200
        pageOrder: "ai,other"
        extraPages: [
            { key: "ai", icon: "dialog-messages", title: "AI", component: aiPage, visible: true },
            { key: "other", icon: "chronometer", title: "Other", component: otherPage, visible: true }
        ]
    }

    TestCase {
        name: "AiIsland"
        when: windowShown

        function find(test) {
            let found = null;
            const walk = item => { if (found === null && test(item)) found = item; for (const c of item.children) walk(c); };
            walk(island);
            return found;
        }
        function page() { return find(item => typeof item.submit === "function" && typeof item.showModels === "function"); }
        function content() { return find(item => item.objectName === "expandedContent"); }
        // the pointer on the island, and away from it
        function pointerOn() { mouseMove(root, root.width / 2, islandTheme.windowTopPad + 14); }
        function pointerAway() { mouseMove(root, 8, root.height - 8); }

        function initTestCase() {
            Lang.setting = "en";
            activities.warm = true;
            backend.catalog.kinds = { tool: { name: "Tool", driver: fake, where: "cli", modelOptional: true } };
            backend.catalog.order = ["tool"];
            let made = null;
            backend.connect("tool", {}, r => made = r);
            tryVerify(() => made !== null);
            backend.acknowledge(made.id);
        }
        function init() { root.live = null; root.cancelled = 0; backend.newChat(); backend.draft = ""; onTheIsland.notify = true; stopwatch.active = false; }
        function cleanup() {
            pointerAway();
            island.expanded = false;
            backend.stop();
            activities.queue = [];
            if (activities.currentEvent) activities.dismissEvent();
            tryCompare(island, "needsLargeWindow", false, 3000);
        }
        // A question asked on the page, then the island let go and left: the answer is on its way, nobody looks.
        function askAndLeave(text) {
            pointerOn();
            island.openPage("ai");
            tryVerify(() => page() !== null);
            tryCompare(page(), "visible", true);
            compare(backend.send(text), "");
            page().release();
            pointerAway();
            tryCompare(island, "expanded", false, 3000);
            tryCompare(backend, "viewing", false);
        }

        // The wheel in a conversation: it scrolls it and stays with it, at its end too, however
        // often one scrolls on from there (tests/tst_scroll.qml has the rules). Beside the
        // conversation it turns the page.
        function notch(item, direction) {
            const at = item.mapToItem(root, item.width / 2, item.height / 2);
            mouseWheel(root, at.x, at.y, 0, 120 * direction);
        }
        function test_0_the_wheel_stays_with_a_conversation() {
            const rest = ScrollGesture.gestureGap + 150;
            pointerOn();
            island.openPage("ai");
            tryVerify(() => page() !== null);
            const p = page(), c = content();
            tryCompare(p, "visible", true);
            let lines = "";
            for (let i = 1; i <= 60; ++i) lines += "Line " + i + " of a long answer.\n\n";
            backend.messages = [{ role: "user", text: "Tell me a lot.", source: backend.sources[0].id }, { role: "assistant", text: lines, source: backend.sources[0].id }];
            const scroll = find(item => item.objectName === "conversation");
            tryVerify(() => scroll.contentHeight > scroll.height * 2, 3000);
            tryCompare(island, "tall", true);
            wait(600);
            scroll.contentY = 0;
            wait(rest);
            compare(scroll.atYBeginning, true);

            // one scroll, all the way down and on: the end holds it
            let steps = 0;
            while (!scroll.atYEnd && steps++ < 200) { notch(scroll, -1); wait(40); }
            verify(scroll.atYEnd, "scrolled to the end");
            for (let i = 0; i < 6; ++i) { notch(scroll, -1); wait(40); }
            compare([c.currentKey, scroll.atYEnd], ["ai", true], "the scroll that reached the end does not turn the page");
            // let go, then scrolled on from the end: still the conversation's
            wait(rest);
            for (let i = 0; i < 3; ++i) { notch(scroll, -1); wait(40); }
            wait(rest);
            compare([c.currentKey, scroll.atYEnd], ["ai", true], "nor does a scroll that starts at the end");

            // up from the end: that scrolls the conversation
            notch(scroll, 1);
            wait(300);
            compare([c.currentKey, scroll.atYEnd], ["ai", false]);

            // beside the conversation (the row of the source above it) the wheel turns the page as on any page
            wait(rest);
            const at = scroll.mapToItem(root, scroll.width / 2, -14);
            mouseWheel(root, at.x, at.y, 0, -120);
            tryCompare(c, "currentKey", "other", 2000);
            wait(500);
        }

        function test_1_taller_for_a_conversation() {
            pointerOn();
            island.openPage("ai");
            tryVerify(() => page() !== null);
            const p = page();
            tryCompare(p, "visible", true);              // (the island's content fades in)
            compare([island.mode, island.tall, island.targetHeight, island.needsTallWindow], ["expanded", false, islandTheme.expandedHeight, false], "an empty chat has the usual size");
            compare(backend.send("What is 2+2?"), "");
            compare([p.tall, island.tall, island.targetHeight, island.needsTallWindow], [true, true, islandTheme.tallHeight, true]);
            tryVerify(() => Math.abs(island.surfaceRect.height - islandTheme.tallHeight) < 1, 3000, "the island has grown");
            verify(islandTheme.tallHeight + islandTheme.windowTopPad <= root.height);
            root.live.delta("4.");
            root.live.finished({ ok: true, cut: false, problem: null });

            // another page: the usual height again; the window keeps its size until the island is small
            content().showPage("other");
            tryCompare(island, "tall", false);
            compare([island.targetHeight, island.needsTallWindow], [islandTheme.expandedHeight, true]);
            tryVerify(() => Math.abs(island.surfaceRect.height - islandTheme.expandedHeight) < 1, 3000);
            pointerAway();
            tryCompare(island, "expanded", false, 3000);
            tryCompare(island, "needsTallWindow", false, 3000);
            compare(island.needsLargeWindow, false);

            // opened again on the conversation: tall at once
            pointerOn();
            island.openPage("ai");
            tryCompare(island, "tall", true);
            compare(island.targetHeight, islandTheme.tallHeight);
        }

        function test_2_open_while_an_answer_is_written() {
            pointerOn();
            island.openPage("ai");
            tryVerify(() => page() !== null);
            tryCompare(page(), "visible", true);
            compare(backend.send("Tell me something"), "");
            compare([page().holdOpen, content().holding], [true, true]);
            // the pointer leaves: the island stays, the answer is written
            pointerAway();
            wait(900);
            compare([island.expanded, island.hovered, backend.busy], [true, false, true]);
            root.live.delta("Here.");
            wait(300);
            compare(island.expanded, true);
            // the answer is complete: the island closes as it does after the pointer left
            root.live.finished({ ok: true, cut: false, problem: null });
            tryCompare(island, "expanded", false, 3000);
            compare([backend.messages.length, backend.unseen], [2, false], "it was read while it was written");

            // let go with Escape: the island may close, the answer goes on
            pointerOn();
            island.openPage("ai");
            tryVerify(() => page() !== null);
            tryCompare(page(), "visible", true);
            compare(backend.send("Another one"), "");
            page().release();
            compare([page().holdOpen, content().holding], [false, false]);
            pointerAway();
            tryCompare(island, "expanded", false, 3000);
            compare([backend.busy, root.cancelled], [true, 0]);
            root.live.delta("Done.");
            root.live.finished({ ok: true, cut: false, problem: null });
            compare([backend.busy, backend.unseen, backend.messages[3].text], [false, true, "Done."]);
        }

        function test_3_three_dots_then_answer_ready() {
            compare(activities.liveCount, 0);
            pointerOn();
            island.openPage("ai");
            tryVerify(() => page() !== null);
            tryCompare(page(), "visible", true);
            compare(backend.send("What is the capital of France?"), "");
            wait(50);
            compare([backend.viewing, onTheIsland.waiting, activities.liveCount], [true, false, 0], "while its page is on screen nothing else says so");
            page().release();
            pointerAway();
            tryCompare(island, "expanded", false, 3000);
            // the small island: three dots
            tryCompare(activities, "liveCount", 1);
            compare([activities.primary.activityId, activities.primary.title, activities.primary.subtitle, island.mode], ["ai-thinking", "Thinking…", "Tool", "live"]);
            tryVerify(() => find(item => item.objectName === "pillDots" && item.visible) !== null, 3000, "the dots are on the pill");
            compare(find(item => item.objectName === "pillDots").running, true);

            root.live.delta("## Paris\n\nThe capital of France is **Paris**.");
            root.live.finished({ ok: true, cut: false, problem: null });
            tryCompare(activities, "liveCount", 0);
            tryVerify(() => activities.currentEvent !== null, 3000);
            compare([activities.currentEvent.title, activities.currentEvent.subtitle, activities.currentEvent.trailing.text, island.mode, backend.unseen],
                    ["Answer ready", "Paris", "Open", "event", true]);
            tryVerify(() => find(item => item.objectName === "pillDots" && item.visible && item.running) === null, 3000, "the dots have stopped");
            // a click on it opens the island on the tab
            activities.activateEvent();
            compare(island.expanded, true);
            tryCompare(content(), "currentKey", "ai");
            tryVerify(() => page() !== null && page().visible);
            compare([backend.unseen, backend.viewing, activities.currentEvent], [false, true, null]);
        }

        function test_4_below_every_other_activity_and_stopped_from_its_card() {
            stopwatch.active = true;
            askAndLeave("A long one");
            tryCompare(activities, "liveCount", 2);
            compare([activities.primary.activityId, activities.secondary.activityId], ["stopwatch", "ai-thinking"], "whatever else is going on comes first");
            const thinking = activities.byId("ai-thinking");
            compare(thinking.actions.map(a => a.text), ["Stop"]);
            thinking.actions[0].trigger();
            compare([backend.busy, root.cancelled, activities.byId("ai-thinking").active], [false, 1, false]);
            wait(300);
            compare(activities.currentEvent, null, "stopped by the user: nothing to announce");
            // a click on the card of the waiting answer opens the tab
            stopwatch.active = false;
            askAndLeave("Another one");
            tryCompare(activities, "liveCount", 1);
            activities.primary.clicked();
            compare(island.expanded, true);
            tryCompare(content(), "currentKey", "ai");
        }

        function test_5_switched_off_or_no_answer() {
            // "Answer ready" switched off: the answer is there, the tab has its dot, the island says nothing
            onTheIsland.notify = false;
            askAndLeave("Quietly");
            tryCompare(activities, "liveCount", 1);
            root.live.delta("Here.");
            root.live.finished({ ok: true, cut: false, problem: null });
            tryCompare(activities, "liveCount", 0);
            wait(500);
            compare([activities.currentEvent, activities.queue.length, backend.unseen], [null, 0, true]);

            // what went wrong is said the same way
            onTheIsland.notify = true;
            askAndLeave("Will this work?");
            root.live.finished({ ok: false, cut: false, problem: { kind: "limit", detail: "" } });
            tryVerify(() => activities.currentEvent !== null, 3000);
            compare([activities.currentEvent.title, activities.currentEvent.subtitle], ["No answer", "A usage limit of Tool was reached. Try again later."]);
            activities.dismissEvent();

            // the tab is switched off: nothing of it on the island
            onTheIsland.enabled = false;
            compare(onTheIsland.waiting, false);
            onTheIsland.enabled = true;
        }
    }
}
