/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Claude Code as the AI tab uses it (ai/ClaudeCliProvider.qml), through the
    native helper that runs a command and reads it while it runs, with
    tests/fake-claude standing in for the command: nobody is asked and no
    usage is spent. Where the command runs, what it is started with, where
    the question goes, and that it is stopped when it starts with a tool, in
    another folder, or reaches for a tool. Needs the native module (skipped
    when it is not built).

    The same provider with the real `claude` of this computer:
    tests/ai-real-claude.qml, run by tools/ai-cli-check.
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"
import "../org.phobby.dynamicisland/contents/ui/ai"
import "../org.phobby.dynamicisland/contents/ui/ai/ClaudeCli.js" as Cli

Item {
    id: root
    width: 200
    height: 100

    Loader { id: tools; source: "../org.phobby.dynamicisland/contents/ui/LocalBridge.qml" }
    Loader { id: streams; source: "../org.phobby.dynamicisland/contents/ui/StreamBridge.qml" }
    readonly property var local: tools.status === Loader.Ready ? tools.item : null
    readonly property var stream: streams.status === Loader.Ready ? streams.item : null
    readonly property string here: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, ""))
    readonly property string run: here + "/.run/cli-" + Math.floor(Math.random() * 1e9).toString(36)
    readonly property string record: here + "/.run/fake-claude"

    // What the provider needs of the native core.
    QtObject {
        id: nativeCore
        readonly property var local: root.local
        readonly property var stream: root.stream
        readonly property bool secretsAvailable: false
    }

    property string written: ""
    property var pieces: []
    property var result: null
    Component {
        id: providerComponent
        ClaudeCliProvider {
            core: nativeCore
            onDelta: text => { root.written += text; root.pieces.push(text); }
            onFinished: result => root.result = result
        }
    }

    // ---- helpers both test cases use ------------------------------------------------------
    function shell(test, program, args) {
        let out = null;
        root.local.run(program, args, (code, text) => out = text);
        test.tryVerify(() => out !== null, 5000);
        return out.trim();
    }
    function reset() { written = ""; pieces = []; result = null; }
    readonly property string system: "Answer with text only. You have no tools. Be brief."

    TestCase {
        name: "AiCli"
        when: windowShown

        property var cli: null
        readonly property string box: root.run + "/dynamicisland/ai-sandbox"
        function recorded(name) { return root.local.readTextFile(root.record + "/" + name); }
        function ask(scene, text, wait) {
            root.reset();
            cli.send([{ role: "user", text: text || "What is 2+2?" }], scene, { system: root.system, maxTokens: 500 });
            tryVerify(() => root.result !== null, wait || 8000);
            return root.result;
        }

        function initTestCase() {
            if (root.local === null || root.stream === null) skip("the native module is not built: ./install.sh");
            Lang.setting = "en";
            cli = providerComponent.createObject(root, { commandName: root.here + "/fake-claude", sandbox: box });
        }
        function cleanupTestCase() { if (cli !== null) cli.destroy(); }

        function test_01_found_with_its_version_and_model_names() {
            let found = null;
            cli.detect(r => found = r);
            tryVerify(() => found !== null);
            compare(found, { found: true, helper: true, version: "9.9.9" });
            compare([cli.command, cli.names], [root.here + "/fake-claude", ["fable", "opus", "sonnet"]]);
            let models = null;
            cli.listModels(r => models = r);
            compare(models.models, [{ id: "", name: "Claude Code's own choice" }, { id: "fable", name: "fable" }, { id: "opus", name: "opus" }, { id: "sonnet", name: "sonnet" }]);

            const missing = providerComponent.createObject(root, { commandName: "no-such-claude-command-xyz", sandbox: box });
            found = null;
            missing.detect(r => found = r);
            tryVerify(() => found !== null);
            compare(found, { found: false, helper: true, version: "" });
            root.reset();
            missing.send([{ role: "user", text: "hi" }], "", { system: root.system });
            tryVerify(() => root.result !== null);
            compare(root.result.problem.kind, "missing");
            missing.destroy();
        }

        function test_02_connecting_asks_the_command_whether_it_is_signed_in() {
            let answer = null;
            cli.verify(r => answer = r);
            tryVerify(() => answer !== null);
            compare([answer.ok, answer.models.length], [true, 4]);
            compare(recorded("auth-cwd").trim(), box, "asked in the island's folder too");
            root.local.writeTextFile(root.record + "/signed-out", "");
            answer = null;
            cli.verify(r => answer = r);
            tryVerify(() => answer !== null);
            compare([answer.ok, answer.problem.kind], [false, "auth"]);
            root.local.removeFile(root.record + "/signed-out");
        }

        function test_03_an_answer_and_how_the_command_was_started() {
            const question = "What is 2+2? (a question nobody else may see: PRIVATE-QUESTION-7)";
            const r = ask("", question);
            compare([r.ok, r.problem, root.written, root.pieces], [true, null, "2+2 is 4.", ["2+2 ", "is 4."]]);
            compare(recorded("cwd").trim(), box, "it ran in the island's own folder");
            compare(recorded("stdin"), question, "the question went to its standard input");
            const args = recorded("args").split("\n").slice(0, -1);
            compare(args, Cli.commandArguments("", root.system), "started with exactly the options of ClaudeCli.js");
            verify(args.join("\n").indexOf("PRIVATE-QUESTION") < 0, "the question is in no argument");
            for (const option of ["--strict-mcp-config", "--safe-mode", "--restricted", "--disable-slash-commands", "--no-session-persistence"])
                verify(args.indexOf(option) >= 0, option);
            compare([args[args.indexOf("--tools") + 1], args[args.indexOf("--setting-sources") + 1], args[args.indexOf("--permission-mode") + 1],
                     args[args.indexOf("--permission-prompts") + 1], args[args.indexOf("--max-turns") + 1]], ["", "", "dontAsk", "none", "1"]);
            compare(root.shell(this, "ls", ["-A", box]), "", "the folder stays empty");
            compare(root.shell(this, "stat", ["-c", "%a", box]), "700");
        }

        function test_04_a_follow_up_and_a_model() {
            root.reset();
            cli.send([{ role: "user", text: "My number is 7." }, { role: "assistant", text: "Noted." }, { role: "user", text: "Plus one?" }], "sonnet", { system: root.system });
            tryVerify(() => root.result !== null, 8000);
            compare(root.result.ok, true);
            compare(recorded("stdin"), Cli.transcript([{ role: "user", text: "My number is 7." }, { role: "assistant", text: "Noted." }, { role: "user", text: "Plus one?" }]));
            compare(recorded("args").split("\n").slice(-3, -1), ["--model", "sonnet"]);
            // a Claude Code that sends no pieces: the finished message is shown
            compare([ask("whole").ok, root.written], [true, "All at once."]);
        }

        // The command says what it runs with before anything is asked of the model.
        function test_05_stopped_when_it_does_not_start_as_asked() {
            for (const scene of ["tools-on", "mcp-on", "elsewhere", "noinit"]) {
                const r = ask(scene);
                compare([scene, r.ok, r.problem.kind, root.written], [scene, false, "version", ""], "nothing of its answer is shown");
            }
            compare(ask("tools-on").problem.detail, "Bash, Read");
            compare(ask("mcp-on").problem.detail, "notes");
            compare(ask("elsewhere").problem.detail, "/home/someone/project");
            tryCompare(root.stream, "running", false, 4000);
        }

        function test_06_stopped_when_the_model_reaches_for_a_tool() {
            const r = ask("reaches");
            compare([r.ok, r.problem.kind, root.written], [false, "tools", "Let me look. "]);
            // left alone, the stand-in would make a file three seconds later
            wait(4000);
            compare([root.stream.running, root.shell(this, "ls", ["-A", box])], [false, ""], "it was stopped: nothing was made");
        }

        function test_07_what_went_wrong() {
            compare(ask("signedout").problem, { kind: "auth", detail: "" });
            compare(ask("limit").problem.kind, "limit");
            compare(ask("nomodel").problem.kind, "model");
            const old = ask("oldcli");
            compare([old.ok, old.problem.kind, old.problem.detail], [false, "version", "error: unknown option '--safe-mode'"], "not tried again with fewer options");
            compare(recorded("args").split("\n").filter(a => a === "--safe-mode").length, 1);
        }

        function test_08_stop_and_a_question_right_after_another() {
            root.reset();
            cli.send([{ role: "user", text: "Tell me a long story" }], "slow", { system: root.system });
            tryVerify(() => root.pieces.length >= 2, 5000);
            const pid = root.stream.processId;
            verify(pid > 0);
            compare(root.shell(this, "readlink", ["/proc/" + pid + "/cwd"]), box);
            cli.cancel();
            tryCompare(root.stream, "running", false, 4000);
            const after = root.pieces.length;
            wait(500);
            compare([root.result, root.pieces.length, root.shell(this, "sh", ["-c", "kill -0 " + pid + " 2>/dev/null && echo alive || echo gone"])], [null, after, "gone"]);

            // the next question while the command of the one before still runs: that one ends, this one is answered
            root.reset();
            cli.send([{ role: "user", text: "first" }], "slow", { system: root.system });
            tryVerify(() => root.pieces.length >= 1, 5000);
            root.reset();
            cli.send([{ role: "user", text: "second" }], "", { system: root.system });
            tryVerify(() => root.result !== null, 8000);
            compare([root.result.ok, root.written, recorded("stdin")], [true, "2+2 is 4.", "second"]);
        }
    }
}
