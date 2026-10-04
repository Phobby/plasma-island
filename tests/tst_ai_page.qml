/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The AI page inside the real expanded island, with the real backend and a
    stand-in for the sources (it answers when the test says so): connecting,
    the notice before the first question, Enter and Shift+Enter, an answer
    arriving in pieces, Stop, the length limit, links that are only opened
    after asking, the island staying open and taller, and the page coming
    back to the conversation after the island closed.

    One part asks tests/ai-server.py through the real provider (an answer
    with a picture in it: the picture must not be fetched); it needs the
    native module and is skipped without it.
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"
import "../org.phobby.dynamicisland/contents/ui/ai"
import "../org.phobby.dynamicisland/contents/ui/backend"

Item {
    id: root
    width: 470
    height: 400

    Loader { id: tools; source: "../org.phobby.dynamicisland/contents/ui/LocalBridge.qml" }
    readonly property var local: tools.status === Loader.Ready ? tools.item : null
    readonly property string here: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, ""))
    readonly property string run: here + "/.run/page-" + Math.floor(Math.random() * 1e9).toString(36)

    Theme { id: islandTheme; follow: false }
    ActivityManager { id: activities }
    PlasmaBackend { id: plasma }

    // The stand-in source: what it was asked, and what it says it found on this computer.
    property var asked: []
    property var live: null
    property int cancelled: 0
    property var here_: ({ found: true, helper: true, version: "9.9.9", running: true, installed: true, models: [] })
    readonly property var modelNames: [{ id: "tiny", name: "Tiny" }, { id: "big", name: "Big" }]
    Component {
        id: fake
        AiProvider {
            function detect(done) { done(root.here_); }
            function verify(done) { done({ ok: true, models: root.modelNames, problem: null }); }
            function listModels(done) { done({ ok: true, models: root.modelNames, problem: null }); }
            function send(messages, model, options) { root.asked.push({ messages: messages, model: model }); root.live = this; }
            function cancel() { ++root.cancelled; }
        }
    }
    QtObject {
        id: nativeCore
        readonly property var local: root.local
        readonly property var stream: null
        property bool secretsAvailable: true
        property var entries: ({})
        function readSecret(key, callback) { callback(entries[key] !== undefined, entries[key] || ""); }
        function writeSecret(key, value, callback) { entries[key] = value; callback(true, ""); }
        function removeSecret(key) { delete entries[key]; }
    }
    AiBackend { id: backend; core: nativeCore; enabled: true }
    property string defaultPicked: ""
    Component { id: aiPage; AiPage { theme: islandTheme; ai: backend; onDefaultPicked: id => root.defaultPicked = id } }
    Component { id: otherPage; Item {} }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 8
        width: islandTheme.expandedWidth
        height: expanded.tall ? islandTheme.tallHeight : islandTheme.expandedHeight
        radius: 28
        color: islandTheme.surface
        ExpandedContent {
            id: expanded
            anchors.fill: parent
            anchors.margins: islandTheme.padding
            anchors.topMargin: islandTheme.padding * 0.7
            theme: islandTheme
            backend: plasma
            manager: activities
            showMediaModule: false
            showSystemModule: false
            showNotificationModule: false
            pageOrder: "ai,other"
            extraPages: [
                { key: "ai", icon: "dialog-messages", title: "AI", component: aiPage, visible: true },
                { key: "other", icon: "chronometer", title: "Other", component: otherPage, visible: true }
            ]
        }
    }

    TestCase {
        name: "AiPage"
        when: windowShown

        function find(test) {
            let found = null;
            const walk = item => { if (found === null && test(item)) found = item; for (const c of item.children) walk(c); };
            walk(expanded);
            return found;
        }
        function named(name) { return find(item => item.objectName === name); }
        function page() { return find(item => typeof item.submit === "function" && typeof item.showModels === "function"); }
        function showsNow(text) { return find(item => item.visible === true && typeof item.text === "string" && item.text.indexOf(text) >= 0 && item.width > 0) !== null; }
        // (what is shown may need a layout pass first)
        function shown(...texts) {
            for (const text of texts) tryVerify(() => showsNow(text), 2000, "shown: " + text);
            return true;
        }
        function click(item) { mouseClick(item, item.width / 2, item.height / 2); }
        // The island opens (a new page) and closes (the page goes away).
        function open() {
            expanded.active = true;
            expanded.jumpTo("ai");
            tryVerify(() => page() !== null);
            wait(50);
            return page();
        }
        function close() {
            expanded.active = false;
            tryVerify(() => page() === null);
        }
        function type(p, text) {
            const input = named("question");
            click(input.parent.parent);                 // the first click asks for the keyboard
            tryCompare(p, "typing", true);
            input.forceActiveFocus();
            input.text = text;
            input.cursorPosition = input.length;
            return input;
        }
        function standIns() {
            const kinds = Object.assign({}, backend.catalog.kinds);
            for (const k in kinds) kinds[k] = Object.assign({}, kinds[k], { driver: fake });
            backend.catalog.kinds = kinds;
        }

        function initTestCase() {
            Lang.setting = "en";
            activities.warm = true;
            standIns();
        }
        function init() { root.asked = []; root.live = null; root.cancelled = 0; }
        function cleanup() { if (expanded.active) close(); }

        function test_01_nothing_connected_what_is_here_and_add_another() {
            root.here_ = { found: false, helper: true, version: "", running: false, installed: true, models: [] };
            const p = open();
            compare([p.view, p.tall, expanded.tall, p.keepsWheel], ["cards", false, false, false]);
            tryCompare(p, "detected", true);
            shown("Not found · Install", "Not running · Start it", "Add another");

            // not installed: the command is shown to be copied, nothing is run
            click(named("card-claude-cli"));
            compare(p.view, "install");
            shown("Claude Code was not found", "curl -fsSL https://claude.ai/install.sh | bash");
            p.view = "cards";
            click(named("card-ollama"));
            shown("Ollama is not running", "ollama serve");
            compare([backend.sources.length, root.asked.length], [0, 0]);

            // the kinds that take a key or an address
            p.view = "cards";
            click(named("card-+"));
            compare([p.view, named("kindList").count, expanded.tall], ["kinds", 7, true]);
            p.showForm("anthropic");
            compare([named("keyField").visible, named("serverField").visible], [true, false]);
            shown("https://platform.claude.com/settings/keys", "may cost money", "KDE Wallet");
            compare(p.interacting, true, "typing a key keeps the island open");
            click(named("formConnect"));
            tryVerify(() => p.formError.length > 0);
            compare([p.formError, backend.sources.length], ["Paste the key first.", 0]);

            // a "local" server at an address that is not this computer: said first, connected on the second press
            p.showForm("local");
            compare([named("keyField").visible, named("serverField").visible], [false, true]);
            named("serverField").text = "http://192.168.1.20:8080/v1";
            compare([p.far, named("farNote").visible], [true, true]);
            shown("What you write will be sent to 192.168.1.20. The connection is not encrypted.");
            click(named("formConnect"));
            compare([backend.sources.length, p.farAccepted, named("formConnect").text], [0, true, "Connect anyway"]);
            click(named("formConnect"));
            tryCompare(backend, "available", true);
            compare([backend.sources[0].server, backend.whereOf(backend.sources[0]), p.view], ["http://192.168.1.20:8080/v1", "remote", "models"], "several models, none preferred: the user chooses");
            click(named("modelList").itemAtIndex(1));
            compare([backend.sources[0].model, p.view], ["big", "chat"]);
            backend.disconnect(backend.sources[0].id);
            compare(p.view, "cards", "the last source is gone: back to connecting");
            close();
        }

        function test_02_the_notice_then_enter_sends() {
            root.here_ = { found: true, helper: true, version: "9.9.9", running: true, installed: true, models: [] };
            const p = open();
            tryCompare(p, "detected", true);
            shown("Found · no key needed");
            click(named("card-claude-cli"));
            tryCompare(p, "view", "chat");
            const id = backend.sources[0].id;
            compare([backend.sources[0].kind, backend.sources[0].model, p.tall, named("emptyHint").visible], ["claude-cli", "", false, true]);
            shown("For quick questions.");

            const input = type(p, "What is 2+2?");
            compare([p.interacting, p.tall, expanded.tall, expanded.interacting], [true, true, true, true], "typing: the island keeps the keyboard and grows");
            // Shift+Enter is a new line, Enter sends
            keyClick(Qt.Key_Return, Qt.ShiftModifier);
            compare([input.text, root.asked.length], ["What is 2+2?\n", 0]);
            input.text = "What is 2+2?";
            keyClick(Qt.Key_Return);
            compare([p.view, root.asked.length, backend.messages.length, backend.busy], ["notice", 0, 0, false], "before the first question the source's notice; nothing is sent");
            shown("is sent to Claude, through the Claude Code on this computer", "uses up some of that account's usage");
            click(named("noticeContinue"));
            compare([p.view, backend.acknowledged(id), root.asked.length, input.text], ["chat", true, 1, ""]);
            compare(root.asked[0].messages, [{ role: "user", text: "What is 2+2?" }]);

            // the answer arrives in pieces; the island stays open even without the pointer
            compare([p.holdOpen, expanded.holding, named("thinking") !== null], [true, true, true]);
            root.live.delta("2+2 is ");
            shown("2+2 is");
            root.live.delta("**4**.");
            root.live.finished({ ok: true, cut: false, problem: null });
            compare([backend.busy, p.holdOpen, expanded.holding, backend.messages.length], [false, false, false, 2]);
            tryVerify(() => named("thinking") === null);
            shown("2+2 is");

            // the next question goes without a notice
            input.text = "And 3+3?";
            keyClick(Qt.Key_Enter);
            compare([p.view, root.asked.length, root.asked[1].messages.length], ["chat", 2, 3]);
            // Enter while an answer is written sends nothing more
            input.text = "too early";
            keyClick(Qt.Key_Return);
            compare([root.asked.length, input.text], [2, "too early"]);
            // Stop
            root.live.delta("3+3 ");
            tryCompare(backend, "streaming", "3+3 ");
            click(named("sendOrStop"));
            compare([backend.busy, root.cancelled, backend.messages[3].stopped, backend.messages[3].text], [false, 1, true, "3+3 "]);
            shown("Stopped.");
            close();
        }

        function test_03_too_long_is_not_sent() {
            backend.maxChars = 30;
            const p = open(), input = type(p, "x".repeat(31));
            compare([p.over, named("sendOrStop").enabled, named("limitNote").visible], [1, false, true]);
            shown("Too long for this box (31 of 30 characters). Use the Claude app or a terminal for this.");
            const before = backend.messages.length;
            keyClick(Qt.Key_Return);
            click(named("sendOrStop"));
            compare([root.asked.length, backend.messages.length, input.text.length], [0, before, 31], "neither Enter nor the button sends it");
            input.text = "x".repeat(30);
            compare([p.over, named("sendOrStop").enabled], [0, true]);
            input.text = "";
            backend.maxChars = 4000;
            close();
        }

        function test_04_links_are_asked_about_and_pictures_become_links() {
            backend.newChat();
            const p = open(), input = type(p, "links please");
            keyClick(Qt.Key_Return);
            root.live.delta("See [the docs](https://example.org/docs) and ![a cat](https://example.org/cat.png) <img src=\"https://example.org/x.png\">\n\n```sh\necho hi\n```");
            root.live.finished({ ok: true, cut: false, problem: null });
            const text = find(item => item.textFormat === Text.MarkdownText && item.visible && String(item.text).indexOf("the docs") >= 0);
            verify(text !== null);
            verify(text.text.indexOf("![") < 0 && text.text.indexOf("<img") < 0, "no picture and no HTML reaches the text item: " + text.text);
            shown("echo hi", "sh");
            // a link is not opened: it is asked about
            text.linkActivated("https://example.org/docs");
            compare([p.view, named("linkAddress").text, named("linkOpen").visible], ["link", "https://example.org/docs", true]);
            p.view = "chat";
            text.linkActivated("file:///etc/passwd");
            compare([p.view, named("linkOpen").visible], ["link", false], "not a web address: there is no Open");
            shown("This is not a web address");
            p.view = "chat";
            close();
        }

        function test_05_the_island_closes_and_the_answer_goes_on() {
            backend.newChat();
            let p = open(), input = type(p, "A long question");
            keyClick(Qt.Key_Return);
            compare([backend.busy, backend.viewing, p.holdOpen], [true, true, true]);
            // Escape lets the island go; the answer goes on
            keyClick(Qt.Key_Escape);
            compare([p.typing, p.letGo, p.holdOpen, expanded.holding, backend.busy], [false, true, false, false, true]);
            input.text = "half a thought";
            close();
            compare([backend.busy, backend.viewing, backend.unseen, root.cancelled], [true, false, false, 0]);
            root.live.delta("Here it is.");
            root.live.finished({ ok: true, cut: false, problem: null });
            compare([backend.busy, backend.unseen, backend.messages[1].text], [false, true, "Here it is."], "answered while nobody looked: a dot for the tab");

            // the island opens again: the conversation is there, and what was typed
            p = open();
            compare([p.view, backend.unseen, backend.viewing, named("question").text, p.tall], ["chat", false, true, "half a thought", true]);
            shown("Here it is.", "A long question");
            // another tab: nobody is looking
            expanded.showPage("other");
            tryCompare(backend, "viewing", false);
            wait(450);                                  // (the pages slide)
            expanded.showPage("ai");
            tryCompare(backend, "viewing", true);
            wait(450);
            // New chat
            click(named("newChat"));
            compare([backend.messages.length, named("emptyHint").visible], [0, true]);
            named("question").text = "";
            close();
        }

        function test_06_models_and_sources() {
            const p = open();
            click(named("modelChip"));
            compare(p.view, "models");
            tryCompare(named("modelList"), "count", 2);
            // a name the list does not have can be typed
            named("modelField").text = "my-own-model";
            p.modelFilter = "my-own-model";
            compare([named("modelList").count, named("modelList").itemAtIndex(0).modelData.name], [1, "Use “my-own-model”"]);
            click(named("modelList").itemAtIndex(0));
            compare([backend.current.model, p.view, named("modelChip").label], ["my-own-model", "chat", "my-own-model"]);

            // a second source: used for now, made the default, disconnected
            let made = null;
            backend.connect("ollama", {}, r => made = r);
            tryVerify(() => made !== null);
            click(named("sourceChip"));
            compare(p.view, "sources");
            shown("Ollama", "Make default", "In use");
            backend.chosenId = made.id;
            compare(backend.current.id, made.id);
            p.defaultPicked(made.id);
            compare(root.defaultPicked, made.id);
            backend.disconnect(made.id);
            compare([backend.sources.length, backend.current.kind, p.view], [1, "claude-cli", "sources"]);
            backend.disconnect(backend.sources[0].id);
            compare(p.view, "cards");
            close();
        }

        // The real provider and a server's answer with a picture in it: shown as text, never fetched.
        function test_07_a_picture_in_an_answer_is_not_fetched() {
            if (root.local === null) skip("the native module is not built: ./install.sh");
            let answer = null;
            const log = root.run + "/page.log";
            root.local.writeTextFile(log, "");
            root.local.run("python3", [root.here + "/ai-server.py", "--log", log, "--lifetime", "40"], (code, out, err) => answer = { code: code, out: out });
            tryVerify(() => answer !== null, 10000);
            const port = Number(answer.out.trim());
            verify(port > 0);
            backend.catalog.kinds = Object.assign({}, backend.catalog.kinds, { local: Object.assign({}, backend.catalog.kinds.local, { driver: "OpenAiProvider.qml" }) });
            let made = null;
            backend.connect("local", { server: "http://127.0.0.1:" + port + "/v1" }, r => made = r);
            tryVerify(() => made !== null, 5000);
            compare(made.ok, true);
            backend.setModel(made.id, "markdown");
            backend.acknowledge(made.id);
            backend.chosenId = made.id;
            backend.newChat();
            const p = open(), input = type(p, "show me");
            keyClick(Qt.Key_Return);
            tryCompare(backend, "busy", false, 8000);
            shown("print(\"hi <there>\")", "Answer");
            wait(1200);
            const paths = root.local.readTextFile(log, 400000).split("\n").filter(l => l.length > 0).map(l => JSON.parse(l).path);
            compare(paths.filter(path => path.indexOf("pixel") >= 0), [], "nothing was fetched because an answer said so");
            verify(paths.indexOf("/v1/chat/completions") >= 0);
            const x = new XMLHttpRequest();
            x.open("GET", "http://127.0.0.1:" + port + "/__quit");
            x.send();
            wait(200);
            backend.disconnect(made.id);
            standIns();
            close();
            compare(backend.sources.length, 0);
        }
    }
}
