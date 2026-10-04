/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The AI tab and the island itself (the real Island with the real page and
    backend; a stand-in answers): the island grows taller for a conversation
    and gives the room back, and it stays open while an answer is written
    even when the pointer leaves.
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"
import "../org.phobby.dynamicisland/contents/ui/ai"
import "../org.phobby.dynamicisland/contents/ui/backend"

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
    Component { id: aiPage; AiPage { theme: islandTheme; ai: backend } }
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
        function init() { root.live = null; root.cancelled = 0; backend.newChat(); backend.draft = ""; }
        function cleanup() {
            pointerAway();
            island.expanded = false;
            tryCompare(island, "needsLargeWindow", false, 3000);
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
    }
}
