/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Antigravity's command as the AI tab uses it (ai/AntigravityProvider.qml),
    through the native helper that runs a command and reads it while it runs,
    with tests/fake-agy standing in for the command: nobody is asked and no
    usage is spent. Where the command runs, what it is started with, where
    the question goes, and that it is stopped when it would not ask before a
    tool, starts in another folder, or reaches for a tool. Also the words the
    kind has of its own, and that it and the model servers are only offered
    once found. Needs the native module (skipped when it is not built).
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"
import "../org.phobby.dynamicisland/contents/ui/ai"
import "../org.phobby.dynamicisland/contents/ui/backend"
import "../org.phobby.dynamicisland/contents/ui/ai/Antigravity.js" as Cli

Item {
    id: root
    width: 200
    height: 100

    Loader { id: tools; source: "../org.phobby.dynamicisland/contents/ui/LocalBridge.qml" }
    Loader { id: streams; source: "../org.phobby.dynamicisland/contents/ui/StreamBridge.qml" }
    readonly property var local: tools.status === Loader.Ready ? tools.item : null
    readonly property var stream: streams.status === Loader.Ready ? streams.item : null
    readonly property string here: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, ""))
    readonly property string run: here + "/.run/agy-" + Math.floor(Math.random() * 1e9).toString(36)
    readonly property string record: here + "/.run/fake-agy"

    QtObject {
        id: nativeCore
        readonly property var local: root.local
        readonly property var stream: root.stream
        readonly property bool secretsAvailable: false
    }
    AiBackend { id: ai }

    property string written: ""
    property var result: null
    Component {
        id: providerComponent
        AntigravityProvider {
            core: nativeCore
            onDelta: text => root.written += text
            onFinished: result => root.result = result
        }
    }
    function shell(test, program, args) {
        let out = null;
        root.local.run(program, args, (code, text) => out = text);
        test.tryVerify(() => out !== null, 5000);
        return out.trim();
    }
    readonly property string system: "Answer with text only. You have no tools. Be brief."

    TestCase {
        name: "AiAntigravity"
        when: windowShown

        property var cli: null
        readonly property string box: root.run + "/dynamicisland/ai-sandbox"
        function recorded(name) { return root.local.readTextFile(root.record + "/" + name); }
        function ask(scene, text) {
            root.written = ""; root.result = null;
            cli.send([{ role: "user", text: text || "What is 2+2?" }], scene, { system: root.system, maxTokens: 500 });
            tryVerify(() => root.result !== null, 8000);
            return root.result;
        }

        function initTestCase() {
            if (root.local === null || root.stream === null) skip("the native module is not built: ./install.sh");
            Lang.setting = "en";
            root.local.removeFile(root.record + "/signed-out");     // (left by a run that broke off)
            cli = providerComponent.createObject(root, { commandName: root.here + "/fake-agy", sandbox: box });
        }
        function cleanupTestCase() { if (cli !== null) cli.destroy(); }

        function test_01_found_and_connected_with_its_models() {
            let found = null;
            cli.detect(r => found = r);
            tryVerify(() => found !== null);
            compare(found, { found: true, helper: true, version: "9.9.9" });
            let answer = null;
            cli.verify(r => answer = r);
            tryVerify(() => answer !== null);
            compare(answer.models, [{ id: "", name: "Antigravity's own choice" }, { id: "flash-low", name: "Flash (Low)" }, { id: "pro-high", name: "Pro (High)" }]);
            compare(recorded("models-cwd").trim(), box, "asked in the island's folder too");

            // signed out: it cannot say which models it has
            const out = providerComponent.createObject(root, { commandName: root.here + "/fake-agy", sandbox: box });
            root.local.writeTextFile(root.record + "/signed-out", "");
            answer = null;
            out.verify(r => answer = r);
            tryVerify(() => answer !== null);
            compare([answer.ok, answer.problem.kind], [false, "auth"]);
            root.local.removeFile(root.record + "/signed-out");
            out.destroy();

            const missing = providerComponent.createObject(root, { commandName: "no-such-agy-command-xyz", sandbox: box });
            found = null;
            missing.detect(r => found = r);
            tryVerify(() => found !== null);
            compare(found, { found: false, helper: true, version: "" });
            missing.destroy();
        }

        function test_02_an_answer_and_how_the_command_was_started() {
            const question = "What is 2+2? (a question nobody else may see: PRIVATE-QUESTION-7)";
            const r = ask("", question);
            compare([r.ok, r.problem, root.written], [true, null, "2+2 is 4."]);
            compare(recorded("cwd").trim(), box, "it ran in the island's own folder");
            compare(recorded("stdin"), Cli.input([{ role: "user", text: question }], root.system), "the instruction and the question went to its standard input");
            const args = recorded("args").split("\n").slice(0, -1);
            compare(args, Cli.commandArguments(""));
            verify(args.join("\n").indexOf("PRIVATE-QUESTION") < 0, "the question is in no argument");
            verify(args.indexOf("--dangerously-skip-permissions") < 0);
            compare(root.shell(this, "ls", ["-A", box]), "", "the folder stays empty");
            // no pieces, only the result: that is shown
            compare([ask("whole").ok, root.written], [true, "All at once."]);
            compare(ask("flash-low").ok, true);
            compare(recorded("args").split("\n").slice(-4, -2), ["--model", "flash-low"]);
        }

        function test_03_stopped_when_it_does_not_start_as_asked() {
            for (const scene of ["yolo", "elsewhere"]) {
                const r = ask(scene);
                compare([scene, r.ok, r.problem.kind, root.written], [scene, false, "version", ""], "nothing of its answer is shown");
            }
            compare(ask("yolo").problem.detail, "skip-all");
            tryCompare(root.stream, "running", false, 4000);
        }

        function test_04_stopped_when_the_model_reaches_for_a_tool() {
            const r = ask("reaches");
            compare([r.ok, r.problem.kind, root.written], [false, "tools", "Let me look. "]);
            // left alone, the stand-in would make a file three seconds later
            wait(4000);
            compare([root.stream.running, root.shell(this, "ls", ["-A", box])], [false, ""], "it was stopped: nothing was made");
            compare(ask("denied").problem.kind, "tools", "a tool the command refused by itself is no answer either");
        }

        function test_05_what_went_wrong_in_its_own_words() {
            compare(ask("signedout").problem, { kind: "auth", detail: "" });
            compare(ask("limit").problem.kind, "limit");
            compare(ask("oldcli").problem.kind, "version");
            const own = ai.catalog.kind("antigravity-cli").texts;
            const said = kind => ai.problemText({ kind: kind, detail: "" }, "cli", "Antigravity", own);
            compare(said("auth"), "Antigravity is not signed in. Run “agy” in a terminal, sign in, then ask again.");
            compare(said("tools"), "Antigravity reached for a tool. It was stopped at once; this box only takes text answers.");
            compare(said("missing"), "Antigravity could not be started.");
            compare(ai.problemText({ kind: "version", detail: "skip-all" }, "cli", "Antigravity", own), "This Antigravity would use its tools without asking, so it is not used. (skip-all)");
            compare(said("timeout"), "Antigravity did not answer in time.");
            // Claude Code keeps its own
            compare(ai.problemText({ kind: "tools", detail: "" }, "cli", "Claude Code", undefined), "Claude Code reached for a tool. It was stopped at once; this box only takes text answers.");
            ai.sourcesJson = JSON.stringify([{ id: "a1", kind: "antigravity-cli", server: "", model: "" }]);
            verify(ai.noticeText(ai.sources[0]).indexOf("kept in Antigravity's own history") > 0);
            verify(ai.noticeText(ai.sources[0]).indexOf("cannot be started without its tools") > 0);
            ai.sourcesJson = "[]";
        }

        // Looked for by themselves, shown only once found.
        function test_06_the_kinds_that_are_looked_for() {
            const c = ai.catalog;
            const probed = c.order.filter(k => c.kind(k).probe === true);
            compare(probed, ["claude-cli", "antigravity-cli", "ollama", "lmstudio", "llamacpp", "jan", "koboldcpp"]);
            compare(probed.filter(k => c.kind(k).quiet === true), ["antigravity-cli", "lmstudio", "llamacpp", "jan", "koboldcpp"]);
            compare(["lmstudio", "llamacpp", "jan", "koboldcpp"].map(k => c.kind(k).server),
                    ["http://localhost:1234/v1", "http://127.0.0.1:8080/v1", "http://localhost:1337/v1", "http://localhost:5001/v1"]);
            for (const k of probed) compare(c.kind(k).key === true, false, k + " needs no key");
        }
    }
}
