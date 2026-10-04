/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The AI tab's backend with a stand-in for a source of answers (the tests
    of the real ones are tst_ai_*.qml): what is refused before anything is
    sent, connecting and the key's way into the wallet and out of it, an
    answer arriving in pieces, Stop, what went wrong, no answer in time, and
    the chat kept in a file only when that is asked for (that part needs the
    native module and writes under tests/.run/).
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"
import "../org.phobby.dynamicisland/contents/ui/ai"
import "../org.phobby.dynamicisland/contents/ui/backend"

Item {
    id: root
    width: 200
    height: 100

    Loader { id: tools; source: "../org.phobby.dynamicisland/contents/ui/LocalBridge.qml" }
    Loader { id: streams; source: "../org.phobby.dynamicisland/contents/ui/StreamBridge.qml" }
    readonly property var stream: streams.status === Loader.Ready ? streams.item : null
    property var lines: []
    property var ended: null
    Connections {
        target: root.stream
        function onLines(lines) { root.lines = root.lines.concat(lines); }
        function onFinished(exitCode, errorOutput) { root.ended = { code: exitCode, errors: errorOutput }; }
    }
    readonly property var local: tools.status === Loader.Ready ? tools.item : null
    readonly property string here: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, ""))
    readonly property string run: here + "/.run/ai-" + Math.floor(Math.random() * 1e9).toString(36)

    // What the stand-in provider was asked, and how it is to answer when connecting.
    property var asked: []
    property var live: null
    property int cancelled: 0
    property var verdict: ({ ok: true, models: [{ id: "m1", name: "M1" }, { id: "best", name: "Best" }], problem: null })
    property int listed: 0
    Component {
        id: fake
        AiProvider {
            function verify(done) { done(root.verdict); }
            function listModels(done) { ++root.listed; done({ ok: true, models: root.verdict.models, problem: null }); }
            function send(messages, model, options) {
                root.asked.push({ messages: messages, model: model, options: options, secret: secret, server: server });
                root.live = this;
            }
            function cancel() { ++root.cancelled; }
        }
    }

    // The wallet: what was read, written and removed.
    QtObject {
        id: wallet
        property bool secretsAvailable: true
        property var local: null
        property var stream: null
        property var entries: ({})
        property var reads: []
        property var removed: []
        property bool refuses: false
        function readSecret(key, callback) { reads.push(key); callback(entries[key] !== undefined, entries[key] || ""); }
        function writeSecret(key, value, callback) { if (!refuses) entries[key] = value; callback(!refuses, ""); }
        function removeSecret(key) { removed.push(key); delete entries[key]; }
    }

    Component {
        id: backendComponent
        AiBackend {
            core: wallet
            enabled: true
            timeoutSeconds: 30
        }
    }
    SignalSpy { id: answered; signalName: "answered" }
    SignalSpy { id: failed; signalName: "failed" }

    TestCase {
        name: "Ai"
        when: windowShown

        property var ai: null
        function fresh(settings) {
            if (ai !== null) ai.destroy();
            root.asked = []; root.live = null; root.cancelled = 0; root.listed = 0;
            root.verdict = { ok: true, models: [{ id: "m1", name: "M1" }, { id: "best", name: "Best" }], problem: null };
            wallet.entries = ({}); wallet.reads = []; wallet.removed = []; wallet.refuses = false;
            ai = backendComponent.createObject(root, settings || {});
            ai.catalog.kinds = {
                keyed: { name: "Keyed", driver: fake, where: "remote", key: true, server: "https://api.example.org/v1", prefer: "best", paid: true },
                own: { name: "Own server", driver: fake, where: "device", needsServer: true },
                tool: { name: "Tool", driver: fake, where: "cli", modelOptional: true }
            };
            ai.catalog.order = ["tool", "own", "keyed"];
            answered.target = ai; answered.clear();
            failed.target = ai; failed.clear();
            return ai;
        }
        function connect(kind, fields) {
            let result = null;
            ai.connect(kind, fields || {}, r => result = r);
            tryVerify(() => result !== null);
            return result;
        }
        // A connected, accepted source and one question on its way.
        function asking(text) {
            const r = connect("keyed", { key: "sk-test-1" });
            ai.acknowledge(r.id);
            compare(ai.send(text || "What is 2+2?"), "");
            tryVerify(() => root.live !== null);
            return r.id;
        }
        function initTestCase() { Lang.setting = "en"; }
        function cleanupTestCase() { if (ai !== null) ai.destroy(); }

        function test_01_nothing_is_sent_unasked() {
            fresh({ enabled: false });
            compare(ai.send("hello"), "off");
            ai.enabled = true;
            compare(ai.send("hello"), "none", "no source is connected");
            const r = connect("keyed", { key: "sk-test-1" });
            compare(ai.send("hello"), "consent", "the notice of this source was not accepted yet");
            ai.acknowledge(r.id);
            compare(ai.send("   \n "), "empty");
            ai.maxChars = 20;
            compare(ai.send("x".repeat(21)), "long");
            compare([root.asked.length, ai.messages.length, ai.busy], [0, 0, false], "none of it reached the provider or the chat");
            compare(ai.send("x".repeat(20)), "");
            compare(ai.send("another"), "busy");
            compare(ai.messages.length, 1);
        }

        function test_02_connecting_and_the_key() {
            fresh();
            compare(connect("keyed", {}), { ok: false, id: "", error: "Paste the key first.", kept: false });
            root.verdict = { ok: false, models: [], problem: { kind: "auth", detail: "Incorrect API key provided." } };
            let r = connect("keyed", { key: "sk-wrong" });
            compare([r.ok, r.error], [false, "Keyed did not accept the key. (Incorrect API key provided.)"]);
            compare([ai.sourcesJson, Object.keys(wallet.entries).length], ["[]", 0], "nothing is stored before the source has answered");

            root.verdict = { ok: true, models: [{ id: "m1", name: "M1" }, { id: "best", name: "Best" }], problem: null };
            r = connect("keyed", { key: "  sk-test-1 \n" });
            compare([r.ok, r.kept, r.error], [true, true, ""]);
            compare(wallet.entries["ai:" + r.id], "sk-test-1", "the key is in the wallet, under the source's name");
            compare(JSON.parse(ai.sourcesJson), [{ id: r.id, kind: "keyed", server: "", model: "best" }], "the settings hold the source and the model the kind prefers");
            verify(ai.sourcesJson.indexOf("sk-test") < 0 && ai.acknowledgedJson.indexOf("sk-test") < 0, "never the key");
            compare(ai.whereOf(ai.current), "remote");

            // the wallet cannot be written: the key stays for this session, and that is said
            wallet.refuses = true;
            ai.disconnect(r.id);
            r = connect("keyed", { key: "sk-test-2" });
            compare([r.ok, r.kept, wallet.entries["ai:" + r.id]], [true, false, undefined]);

            // a server of one's own: its address is checked, and whether it is this device
            compare(connect("own", { server: "localhost:1234" }).error, "Enter the server's address, starting with http:// or https://.");
            const own = connect("own", { server: "http://localhost:1234/v1/" });
            compare([own.ok, ai.source(own.id).server, ai.whereOf(ai.source(own.id)), ai.label(ai.source(own.id))], [true, "http://localhost:1234/v1", "device", "Own server · localhost"]);
            const far = connect("own", { server: "http://192.168.1.20:8080/v1" });
            compare(ai.whereOf(ai.source(far.id)), "remote", "an address that is not this computer is not called local");
            verify(ai.noticeText(ai.source(far.id)).indexOf("192.168.1.20") > 0);
            verify(ai.noticeText(ai.source(own.id)).indexOf("stays on this device") > 0);
        }

        function test_03_an_answer_in_pieces() {
            fresh({ maxTokens: 777 });
            const id = asking("What is 2+2?");
            compare([ai.busy, ai.busySource, ai.streaming], [true, id, ""]);
            const sent = root.asked[0];
            compare(sent.messages, [{ role: "user", text: "What is 2+2?" }]);
            compare([sent.model, sent.secret, sent.server, sent.options.maxTokens], ["best", "sk-test-1", "https://api.example.org/v1", 777]);
            verify(sent.options.system.indexOf("text only") > 0 && sent.options.system.indexOf("no tools") > 0);

            root.live.delta("2+2 ");
            root.live.delta("is ");
            tryCompare(ai, "streaming", "2+2 is ");
            root.live.delta("4.");
            root.live.finished({ ok: true, cut: false, problem: null });
            compare([ai.busy, ai.streaming, answered.count, failed.count], [false, "", 1, 0]);
            compare(ai.messages, [{ role: "user", text: "What is 2+2?", source: id }, { role: "assistant", text: "2+2 is 4.", source: id, cut: false }]);
            compare(answered.signalArguments[0][0], "2+2 is 4.");

            // a follow-up carries the conversation with it
            compare(ai.send("And plus one?"), "");
            compare(root.asked[1].messages, [{ role: "user", text: "What is 2+2?" }, { role: "assistant", text: "2+2 is 4." }, { role: "user", text: "And plus one?" }]);
            root.live.delta("5.");
            root.live.finished({ ok: true, cut: true, problem: null });
            compare(ai.messages[3].cut, true, "stopped at the length limit: said on the answer");
        }

        function test_04_the_key_is_read_only_when_asked() {
            fresh();
            const r = connect("keyed", { key: "sk-test-1" });
            const settings = { sourcesJson: ai.sourcesJson, acknowledgedJson: JSON.stringify([r.id]) }, kept = wallet.entries;
            // the shell starts again: the settings are there, the key is in the wallet
            ai.destroy();
            ai = backendComponent.createObject(root, settings);
            ai.catalog.kinds = { keyed: { name: "Keyed", driver: fake, where: "remote", key: true, server: "https://api.example.org/v1" } };
            wallet.entries = kept; wallet.reads = [];
            wait(50);
            compare([wallet.reads.length, root.listed], [0, 0], "nothing is read or asked while the tab is not used");
            compare(ai.send("hello"), "");
            tryVerify(() => root.live !== null);
            compare([wallet.reads, root.asked[root.asked.length - 1].secret], [["ai:" + r.id], "sk-test-1"]);
            ai.stop();
            // the key is gone from the wallet: said, and nothing is sent without it
            delete ai.secrets[r.id];
            wallet.entries = ({});
            const before = root.asked.length;
            failed.target = ai; failed.clear();
            compare(ai.send("hello again"), "");
            tryCompare(failed, "count", 1);
            compare([root.asked.length, ai.messages[ai.messages.length - 1].problem.kind], [before, "nokey"]);
            compare(ai.problemOf(ai.messages[ai.messages.length - 1]), "The key of Keyed is not in KDE Wallet any more. Disconnect it and connect it again.");
        }

        function test_05_stop() {
            fresh();
            const id = asking("Tell me a story");
            root.live.delta("Once upon ");
            ai.stop();
            compare([root.cancelled, ai.busy, answered.count, failed.count], [1, false, 0, 0]);
            compare(ai.messages[1], { role: "assistant", text: "Once upon ", source: id, stopped: true });
            // what the provider still says afterwards changes nothing
            root.live.delta("a time");
            root.live.finished({ ok: true, cut: false, problem: null });
            wait(80);
            compare([ai.messages.length, ai.streaming, ai.busy], [2, "", false]);
            // stopped before a word: the question got no answer and is not told again
            compare(ai.send("Second"), "");
            ai.stop();
            compare(ai.messages[2], { role: "user", text: "Second", source: id, stopped: true });
            compare(ai.send("Third"), "");
            compare(root.asked[root.asked.length - 1].messages, [{ role: "user", text: "Tell me a story" }, { role: "assistant", text: "Once upon " }, { role: "user", text: "Third" }]);
        }

        function test_06_what_went_wrong() {
            fresh();
            const id = asking("hello");
            root.live.finished({ ok: false, cut: false, problem: { kind: "limit", detail: "Rate limit reached" } });
            compare([ai.busy, failed.count, answered.count], [false, 1, 0]);
            compare(ai.messages, [{ role: "user", text: "hello", source: id, problem: { kind: "limit", detail: "Rate limit reached" } }]);
            compare(ai.problemOf(ai.messages[0]), "A usage limit of Keyed was reached. Try again later. (Rate limit reached)");
            // "Try again": the same question, once
            compare(ai.retry(), "");
            compare([ai.messages.length, root.asked[1].messages], [1, [{ role: "user", text: "hello" }]]);
            // the answer broke off in the middle: what came stays, with what happened
            root.live.delta("Hel");
            root.live.finished({ ok: false, cut: false, problem: { kind: "network", detail: "" } });
            compare(ai.messages[1], { role: "assistant", text: "Hel", source: id, problem: { kind: "network", detail: "" } });
            compare(ai.problemOf(ai.messages[1]), "No connection to Keyed, or it was cut.");
            compare(ai.retry(), "");
            compare([ai.messages.length, root.asked[2].messages.length], [1, 1]);
            // an answer of nothing is no answer
            root.live.finished({ ok: true, cut: false, problem: null });
            compare([ai.messages[0].problem.kind, ai.problemOf(ai.messages[0])], ["empty", "The model gave no answer."]);
            compare(ai.retry(), "");
            root.live.finished({ ok: true, cut: true, problem: null });
            compare(ai.messages[0].problem.kind, "cut");

            const said = (kind, where) => ai.problemText({ kind: kind, detail: "" }, where, "X");
            compare(said("auth", "cli"), "Claude Code is not signed in. Run “claude” in a terminal, sign in, then ask again.");
            compare(said("auth", "remote"), "X did not accept the key.");
            compare(said("network", "device"), "The model server on this computer did not answer. Is it running?");
            compare(said("timeout", "remote"), "X did not answer in time.");
            compare(said("model", "remote"), "X does not have this model.");
            compare(said("server", "remote"), "X has a problem of its own right now. Try again later.");
            compare(said("refused", "remote"), "The model declined to answer this.");
            compare(said("tools", "cli"), "Claude Code reached for a tool. It was stopped at once; this box only takes text answers.");
            compare(said("missing", "cli"), "Claude Code could not be started.");
            compare(ai.problemText({ kind: "unknown", detail: "odd thing" }, "remote", "X"), "odd thing");
            compare(said("unknown", "remote"), "Something went wrong.");
        }

        function test_07_no_answer_in_time() {
            fresh({ timeoutSeconds: 1 });
            asking("hello");
            root.live.delta("One word");
            wait(700);
            root.live.alive();                       // something still arrives: the clock starts over
            wait(700);
            compare(ai.busy, true);
            tryCompare(ai, "busy", false, 3000);
            compare([root.cancelled, failed.count, ai.messages[1].problem.kind, ai.messages[1].text], [1, 1, "timeout", "One word"]);
        }

        function test_08_disconnecting_takes_the_key_out_of_the_wallet() {
            fresh();
            const id = asking("hello");
            verify(wallet.entries["ai:" + id] !== undefined && ai.acknowledged(id));
            ai.disconnect(id);
            compare([wallet.removed, wallet.entries["ai:" + id], ai.busy, root.cancelled], [["ai:" + id], undefined, false, 1]);
            compare([ai.sources.length, ai.acknowledgedJson, ai.secrets[id], ai.current], [0, "[]", undefined, null]);
            // from the settings window: the source leaves the settings, the island follows
            const again = connect("keyed", { key: "sk-test-3" });
            wallet.removed = [];
            ai.sourcesJson = "[]";
            compare([wallet.removed, wallet.entries["ai:" + again.id]], [["ai:" + again.id], undefined]);
            // a source without a key leaves the wallet alone
            const tool = connect("tool");
            wallet.removed = [];
            ai.disconnect(tool.id);
            compare(wallet.removed, []);
        }

        function test_09_the_model() {
            fresh();
            const tool = connect("tool");
            compare(ai.source(tool.id).model, "", "a command has a choice of its own");
            ai.acknowledge(tool.id);
            compare(ai.send("hi"), "");
            compare([root.asked[0].model, root.asked[0].secret, wallet.reads.length], ["", "", 0]);
            ai.stop();
            // a source whose model was never chosen: its list is asked, the first is taken and remembered
            ai.sourcesJson = JSON.stringify([{ id: "own-1", kind: "own", server: "http://localhost:1/v1", model: "" }]);
            ai.acknowledge("own-1");
            root.listed = 0;
            compare(ai.send("hi"), "");
            tryVerify(() => root.asked.length === 2);
            compare([root.asked[1].model, ai.source("own-1").model, root.listed], ["m1", "m1", 1]);
            ai.stop();
            ai.setModel("own-1", "other");
            compare(ai.send("hi"), "");
            compare([root.asked[2].model, root.listed], ["other", 1]);
            ai.stop();
            // the page's choice of source, for now
            const keyed = connect("keyed", { key: "k" });
            compare(ai.current.id, "own-1");
            ai.chosenId = keyed.id;
            compare(ai.current.id, keyed.id);
            ai.defaultId = "nope"; ai.chosenId = "";
            compare(ai.current.id, "own-1", "an id that is gone falls back to the first source");
        }

        function test_10_a_long_chat_and_a_new_one() {
            fresh({ longChat: 60 });
            asking("A question of some length");
            root.live.delta("An answer of some length as well.");
            compare(ai.lengthy, false);
            root.live.finished({ ok: true, cut: false, problem: null });
            compare(ai.lengthy, false);
            compare(ai.send("One more question to make it long"), "");
            compare(ai.lengthy, true);
            ai.newChat();
            compare([ai.messages.length, ai.busy, ai.lengthy, root.cancelled], [0, false, false, 1]);
        }

        function test_11_kept_in_a_file_only_when_asked() {
            if (root.local === null) skip("the native module is not built: ./install.sh");
            wallet.local = Qt.binding(() => root.local);
            fresh();
            const path = ai.historyPath;
            verify(path.length > 0);
            // (not the user's own file: the stand-in's data folder is the real one, so the name is changed)
            wallet.local = null;
            const store = { dataHome: () => root.run, readTextFile: (p, n) => root.local.readTextFile(p, n), removeFile: p => root.local.removeFile(p),
                            writePrivateFile: (p, t) => root.local.writePrivateFile(p, t), writeTextFile: (p, t) => root.local.writeTextFile(p, t) };
            wallet.local = store;
            const file = root.run + "/dynamicisland/ai-chat.json";
            compare(ai.historyPath, file);
            ai.restore();
            const id = asking("Remember this");
            root.live.delta("I will.");
            root.live.finished({ ok: true, cut: false, problem: null });
            compare(root.local.fileSize(file), -1, "kept in memory only: nothing is written");

            ai.keepHistory = true;
            verify(root.local.fileSize(file) > 0, "switched on: the chat is written");
            compare(JSON.parse(root.local.readTextFile(file)).messages.map(m => m.text), ["Remember this", "I will."]);
            verify(root.local.readTextFile(file).indexOf("sk-test") < 0);
            let mode = null;
            root.local.run("stat", ["-c", "%a", file], (code, out) => mode = out.trim());
            tryVerify(() => mode !== null);
            compare(mode, "600", "for the owner only");

            // the shell starts again: the page opens, the chat is back
            const settings = { sourcesJson: ai.sourcesJson, acknowledgedJson: ai.acknowledgedJson, keepHistory: true };
            ai.destroy();
            ai = backendComponent.createObject(root, settings);
            compare(ai.messages.length, 0, "not read before the page opens");
            ai.restore();
            compare(ai.messages.map(m => [m.role, m.text]), [["user", "Remember this"], ["assistant", "I will."]]);
            // a new chat empties the file; switching it off deletes it
            ai.newChat();
            compare(root.local.fileSize(file), -1);
            ai.messages = [{ role: "user", text: "x", source: id, stopped: true }];
            ai.save();
            verify(root.local.fileSize(file) > 0);
            ai.keepHistory = false;
            compare(root.local.fileSize(file), -1, "switched off: the file is gone");
            wallet.local = null;
        }

        // The native helper that runs a command and hands over its lines while it runs.
        function test_12_a_command_read_while_it_runs() {
            if (root.stream === null) skip("the native module is not built: ./install.sh");
            const dir = root.run + "/stream box";
            root.lines = []; root.ended = null;
            // (the test's command is a shell script; the helper itself uses no shell)
            verify(root.stream.start("sh", ["-c", "echo first; pwd; cat; sleep 0.4; printf 'çğş last'; echo oops >&2; exit 3"], "from stdin\n", dir));
            compare(root.stream.running, true);
            verify(!root.stream.start("sh", ["-c", "echo second"], "", dir), "one at a time");
            tryVerify(() => root.lines.length >= 3, 3000);
            compare([root.lines, root.ended], [["first", dir, "from stdin"], null], "the first lines are here while it still runs, in the folder it was given");
            tryVerify(() => root.ended !== null, 3000);
            compare([root.lines[3], root.ended.code, root.ended.errors.trim(), root.stream.running, root.stream.processId], ["çğş last", 3, "oops", false, 0]);
            let mode = null;
            root.local.run("stat", ["-c", "%a", dir], (code, out) => mode = out.trim());
            tryVerify(() => mode !== null);
            compare(mode, "700", "the folder it made is the owner's only");

            // Stop
            root.lines = []; root.ended = null;
            verify(root.stream.start("sh", ["-c", "echo started; sleep 30; echo never"], "", dir));
            tryVerify(() => root.lines.length === 1, 3000);
            const pid = root.stream.processId;
            verify(pid > 0);
            root.stream.stop();
            tryVerify(() => root.ended !== null, 4000);
            compare([root.ended.code, root.lines, root.stream.running], [-1, ["started"], false]);

            // a command that is not there; no folder, no command
            root.ended = null;
            verify(root.stream.start(root.run + "/no-such-command", [], "", dir));
            tryVerify(() => root.ended !== null, 3000);
            compare(root.ended.code, -1);
            verify(!root.stream.start("sh", [], "", ""), "never without a folder of its own");
            verify(!root.stream.start("", [], "", dir));
        }
    }
}
