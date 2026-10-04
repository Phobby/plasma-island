/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The AI tab's network providers against tests/ai-server.py, a local
    stand-in for the services (nothing on the internet is asked, no usage is
    spent, no real key is needed). The server is started with the native
    module (skipped when it is not built); what it was sent is read from its
    log under tests/.run/.

    AiLocal: a model server on this computer (ai/OpenAiProvider.qml without a
    key, as Ollama, LM Studio and llama.cpp are): found or not, an answer in
    pieces, Stop, a connection that is cut, what went wrong, no answer in time.
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
    readonly property var local: tools.status === Loader.Ready ? tools.item : null
    readonly property string here: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, ""))
    readonly property string run: here + "/.run/http-" + Math.floor(Math.random() * 1e9).toString(36)

    // What the providers and the backend use of the native core; the wallet is a stand-in.
    QtObject {
        id: nativeCore
        readonly property var local: root.local
        readonly property var stream: null
        property bool secretsAvailable: true
        property var entries: ({})
        property var removed: []
        function readSecret(key, callback) { callback(entries[key] !== undefined, entries[key] || ""); }
        function writeSecret(key, value, callback) { entries[key] = value; callback(true, ""); }
        function removeSecret(key) { removed.push(key); delete entries[key]; }
    }

    property string written: ""
    property var pieces: []
    property var result: null
    function reset() { written = ""; pieces = []; result = null; }
    Component {
        id: openAi
        OpenAiProvider {
            core: nativeCore
            onDelta: text => { root.written += text; root.pieces.push(text); }
            onFinished: result => root.result = result
        }
    }
    Component { id: backendComponent; AiBackend { core: nativeCore; enabled: true } }
    SignalSpy { id: answered; signalName: "answered" }
    SignalSpy { id: failed; signalName: "failed" }

    // ---- the stand-in server ------------------------------------------------------------
    // Starts one and gives its port; `key` = the key it asks for ("" = none).
    function serve(test, name, key) {
        let answer = null;
        const args = [root.here + "/ai-server.py", "--log", root.run + "/" + name + ".log", "--lifetime", "90"];
        root.local.writeTextFile(root.run + "/" + name + ".log", "");
        root.local.run("python3", key.length > 0 ? args.concat(["--key", key]) : args, (code, out, err) => answer = { code: code, out: out, err: err });
        test.tryVerify(() => answer !== null, 10000);
        test.compare(answer.code, 0, answer.err);
        return Number(answer.out.trim());
    }
    function quit(test, port) {
        if (port <= 0) return;
        const x = new XMLHttpRequest();
        x.open("GET", "http://127.0.0.1:" + port + "/__quit");
        x.send();
        test.wait(200);
    }
    // What the server was sent: [{ method, path, headers, body }].
    function sent(name) {
        return root.local.readTextFile(root.run + "/" + name + ".log", 4000000).split("\n").filter(l => l.length > 0).map(l => JSON.parse(l));
    }

    TestCase {
        name: "AiLocal"
        when: windowShown

        property int port: 0
        readonly property string base: "http://127.0.0.1:" + port + "/v1"
        property var model: null
        function ask(name, text, messages) {
            root.reset();
            model.send(messages || [{ role: "user", text: text || "hello" }], name, { system: "SYS", maxTokens: 64 });
            tryVerify(() => root.result !== null, 10000);
            return root.result;
        }
        function last() { const all = root.sent("local"); return all[all.length - 1]; }

        function initTestCase() {
            if (root.local === null) skip("the native module is not built: ./install.sh");
            Lang.setting = "en";
            port = root.serve(this, "local", "");
            verify(port > 0);
            model = openAi.createObject(root, { server: base });
        }
        function cleanupTestCase() {
            if (model !== null) model.destroy();
            root.quit(this, port);
        }

        function test_01_found_running_or_not() {
            let found = null;
            model.options = { command: "sh" };
            model.detect(r => found = r);
            tryVerify(() => found !== null, 5000);
            compare([found.found, found.running, found.installed, found.models.length], [true, true, true, 13]);

            // installed, but nothing answers at its address: "not running"
            const idle = openAi.createObject(root, { server: "http://127.0.0.1:9/v1", options: { command: "sh" } });
            found = null;
            idle.detect(r => found = r);
            tryVerify(() => found !== null, 5000);
            compare(found, { found: true, running: false, installed: true, models: [] });
            // neither its program nor an answer: "not found"
            idle.options = { command: "no-such-model-server-xyz" };
            found = null;
            idle.detect(r => found = r);
            tryVerify(() => found !== null, 5000);
            compare(found, { found: false, running: false, installed: false, models: [] });
            let listed = null;
            idle.listModels(r => listed = r);
            tryVerify(() => listed !== null, 5000);
            compare([listed.ok, listed.problem.kind], [false, "network"]);
            idle.destroy();

            listed = null;
            model.listModels(r => listed = r);
            tryVerify(() => listed !== null, 5000);
            compare([listed.ok, listed.models.slice(0, 3)], [true, [{ id: "boom", name: "boom" }, { id: "drop", name: "drop" }, { id: "hang", name: "hang" }]]);
        }

        function test_02_an_answer_in_pieces() {
            const text = "Merhaba dünya, çğş İı 🙂 <b>&amp;";
            const r = ask("tiny-1", text);
            compare([r.ok, r.cut, r.problem, root.written], [true, false, null, "REPLY[1]: " + text]);
            verify(root.pieces.length > 3, "it arrived in pieces: " + root.pieces.length);
            const request = last();
            compare([request.method, request.path, request.headers["content-type"], request.headers["authorization"]],
                    ["POST", "/v1/chat/completions", "application/json;charset=UTF-8", undefined], "no key is sent to a server that has none");
            compare(request.body, { model: "tiny-1", stream: true, messages: [{ role: "system", content: "SYS" }, { role: "user", content: text }], max_tokens: 64 });
            verify(request.body.tools === undefined && request.body.tool_choice === undefined, "no tool is ever offered");

            const follow = ask("tiny-1", "", [{ role: "user", text: "one" }, { role: "assistant", text: "two" }, { role: "user", text: "three" }]);
            compare([follow.ok, root.written], [true, "REPLY[3]: three"]);
            compare(ask("markdown").ok, true);
            verify(root.written.indexOf("```python") > 0);
        }

        function test_03_stop() {
            root.reset();
            model.send([{ role: "user", text: "a long one" }], "slow", { system: "", maxTokens: 64 });
            tryVerify(() => root.pieces.length >= 3, 5000);
            model.cancel();
            const had = root.pieces.length;
            wait(700);
            compare([root.pieces.length, root.result], [had, null], "nothing arrives after Stop, and nothing is reported");
            // and the next question is answered as usual
            compare([ask("tiny-1", "after").ok, root.written], [true, "REPLY[1]: after"]);
        }

        function test_04_the_connection_is_cut() {
            const r = ask("drop", "abcdefghijklmnopqrstuvwxyz");
            compare([r.ok, r.problem.kind, root.written], [false, "network", "REPLY[1]: abcd"], "what came stays; then it is said");
            const dead = openAi.createObject(root, { server: "http://127.0.0.1:9/v1" });
            root.reset();
            dead.send([{ role: "user", text: "anyone?" }], "tiny-1", { system: "", maxTokens: 8 });
            tryVerify(() => root.result !== null, 5000);
            compare([root.result.ok, root.result.problem.kind, root.written], [false, "network", ""]);
            dead.destroy();
        }

        function test_05_what_went_wrong() {
            compare(ask("limit").problem, { kind: "limit", detail: "Rate limit reached for requests." });
            compare(ask("missing").problem, { kind: "model", detail: "The model `missing` does not exist." });
            compare(ask("never-heard-of-it").problem.kind, "model");
            compare(ask("boom").problem, { kind: "server", detail: "The server had an error." });
            const mid = ask("midfail", "abcdefghijklmnop");
            compare([mid.ok, mid.problem, root.written], [false, { kind: "server", detail: "The upstream provider failed." }, "REPLY[1"]);
        }

        function test_06_the_length_limit() {
            const r = ask("long", "something");
            compare([r.ok, r.cut, root.written], [true, true, "REPLY[1]: something"]);
            // a service that only knows the limit's newer name says so: asked again with it, once
            const before = root.sent("local").length;
            const n = ask("newparam", "new name");
            compare([n.ok, root.written], [true, "REPLY[1]: new name"]);
            const two = root.sent("local").slice(before);
            compare(two.map(e => [e.body.max_tokens, e.body.max_completion_tokens]), [[64, undefined], [undefined, 64]]);
            // a kind that names it from the start
            model.options = { limitField: "max_completion_tokens" };
            compare(ask("newparam").ok, true);
            compare(root.sent("local").length, before + 3);
            model.options = ({});
        }

        function test_07_through_the_backend() {
            const ai = backendComponent.createObject(root);
            answered.target = ai; failed.target = ai; answered.clear(); failed.clear();
            let made = null;
            ai.connect("local", { server: "127.0.0.1:" + port }, r => made = r);
            compare([made.ok, made.error], [false, "Enter the server's address, starting with http:// or https://."]);
            made = null;
            ai.connect("local", { server: "http://127.0.0.1:9/v1" }, r => made = r);
            tryVerify(() => made !== null, 5000);
            compare([made.ok, made.error, ai.sourcesJson], [false, "The model server on this computer did not answer. Is it running?", "[]"]);
            made = null;
            ai.connect("local", { server: base + "/" }, r => made = r);
            tryVerify(() => made !== null, 5000);
            compare([made.ok, made.kept, Object.keys(nativeCore.entries).length], [true, true, 0], "no key, nothing for the wallet");
            const s = ai.source(made.id);
            compare([s.server, s.kind, ai.whereOf(s), ai.label(s), s.model], [base, "local", "device", "Local model server · 127.0.0.1", "boom"]);
            verify(ai.noticeText(s).indexOf("stays on this device") > 0);

            ai.setModel(made.id, "tiny-1");
            compare(ai.send("hello there"), "consent");
            ai.acknowledge(made.id);
            compare(ai.send("hello there"), "");
            tryCompare(answered, "count", 1, 5000);
            compare(ai.messages[1].text, "REPLY[1]: hello there");
            compare(ai.send("and again"), "");
            tryCompare(answered, "count", 2, 5000);
            compare(ai.messages[3].text, "REPLY[3]: and again");
            verify(last().body.messages[0].content.indexOf("text only") > 0, "the island's instruction goes first");

            // Stop from the chat: what was written so far stays
            ai.setModel(made.id, "slow");
            compare(ai.send("a long one"), "");
            tryVerify(() => ai.streaming.length > 10, 5000);
            ai.stop();
            compare([ai.busy, ai.messages[5].stopped, ai.messages[5].text.length > 10], [false, true, true]);

            // no answer in time: the server takes the question and says nothing, or only its headers
            ai.timeoutSeconds = 1;
            for (const silent of ["hang", "silent"]) {
                failed.clear();
                ai.newChat();
                ai.setModel(made.id, silent);
                compare(ai.send("anyone?"), "");
                tryCompare(failed, "count", 1, 6000);
                compare([silent, ai.busy, ai.messages[0].problem.kind, ai.problemOf(ai.messages[0])], [silent, false, "timeout", "Local model server did not answer in time."]);
            }
            ai.destroy();
        }
    }
}
