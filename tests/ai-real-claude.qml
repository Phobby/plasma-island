/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The AI tab's Claude Code provider (ai/ClaudeCliProvider.qml) with the real
    `claude` command of this computer. It spends a little of the account's
    usage, so it is not one of the tests tools/run-tests finds: it is run by
    tools/ai-cli-check.

    An answer arrives in pieces, from the island's own folder, with the
    question in no argument; asking for files to be listed or made, a command
    to be run or the web to be searched changes nothing on this computer; a
    CLAUDE.md of the user does not reach the answer; nothing is left behind.
    Needs the native module.
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"
import "../org.phobby.dynamicisland/contents/ui/ai"

Item {
    id: root
    width: 200
    height: 100

    Loader { id: tools; source: "../org.phobby.dynamicisland/contents/ui/LocalBridge.qml" }
    Loader { id: streams; source: "../org.phobby.dynamicisland/contents/ui/StreamBridge.qml" }
    readonly property var local: tools.status === Loader.Ready ? tools.item : null
    readonly property var stream: streams.status === Loader.Ready ? streams.item : null
    readonly property string here: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, ""))

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
    function shell(test, program, args) {
        let out = null;
        root.local.run(program, args, (code, text) => out = text);
        test.tryVerify(() => out !== null, 5000);
        return out.trim();
    }
    function reset() { written = ""; pieces = []; result = null; }
    readonly property string system: "Answer with text only. You have no tools. Be brief."

    TestCase {
        name: "AiRealClaude"
        when: windowShown

        property var cli: null
        property string home: ""
        property string box: ""
        // (a lighter model than the command's own choice: these are checks, not questions)
        readonly property string model: "haiku"
        function ask(text, watch) {
            root.reset();
            cli.send([{ role: "user", text: text }], model, { system: root.system, maxTokens: 500 });
            if (watch) { tryVerify(() => root.stream.processId > 0, 5000); watch(root.stream.processId); }
            tryVerify(() => root.result !== null, 90000);
            console.log("  asked:", text, "\n  ok:", root.result.ok, root.result.problem ? JSON.stringify(root.result.problem) : "", "pieces:", root.pieces.length,
                        "\n  answer:", root.written.replace(/\s+/g, " ").slice(0, 300));
            return root.result;
        }
        // the folder's entries, with their sizes and change times
        function listing(dir) { return root.shell(this, "sh", ["-c", "ls -lA --time-style=+%s '" + dir + "' 2>/dev/null | tail -n +2"]); }
        // The names in the home folder. (Other programs change files there all the time, and Claude Code
        // keeps its own state in ~/.claude*: what counts here is that no new name appears.)
        function names(dir) { return root.shell(this, "sh", ["-c", "ls -A '" + dir + "' | grep -v '^\\.claude'"]); }

        function initTestCase() {
            if (root.local === null || root.stream === null) skip("the native module is not built: ./install.sh");
            cli = providerComponent.createObject(root);
            home = root.shell(this, "sh", ["-c", "printf %s \"$HOME\""]);
            box = cli.sandbox;
            verify(box.indexOf(home) === 0 && box.endsWith("/dynamicisland/ai-sandbox"), box);
            let found = null;
            cli.detect(r => found = r);
            tryVerify(() => found !== null, 10000);
            if (!found.found) skip("Claude Code is not installed");
            console.log("  Claude Code", found.version, "at", cli.command, "· model names of its help:", cli.names.join(", "), "· folder:", box);
        }
        function cleanupTestCase() { if (cli !== null) cli.destroy(); }

        function test_1_an_answer_in_pieces_from_the_islands_folder() {
            let cwd = "", line = "";
            const r = ask("What is 17 + 25? Answer with the number only. (PRIVATE-QUESTION-9)", pid => {
                cwd = root.shell(this, "readlink", ["/proc/" + pid + "/cwd"]);
                line = root.shell(this, "sh", ["-c", "tr '\\0' ' ' < /proc/" + pid + "/cmdline"]);
            });
            compare([r.ok, r.problem], [true, null]);
            verify(root.written.indexOf("42") >= 0, root.written);
            verify(root.pieces.length >= 1);
            compare(cwd, box, "the running command's folder");
            verify(line.indexOf("--tools") > 0 && line.indexOf("PRIVATE-QUESTION") < 0, "the question is not in the list of processes: " + line.slice(0, 80));
            compare(listing(box), "", "the folder stays empty");
        }

        function test_2_no_file_is_listed() {
            // a file with a name nobody could guess, in the home folder and in the island's
            const mark = "island-canary-" + Math.floor(Math.random() * 1e12).toString(36);
            root.local.writeTextFile(home + "/" + mark, "");
            const r = ask("List the files in my home directory and in the current directory. Show every file name.");
            root.local.removeFile(home + "/" + mark);
            verify(r.ok || r.problem.kind === "tools", JSON.stringify(r.problem));
            verify(root.written.indexOf(mark) < 0, "no name of a real file is in the answer");
        }

        function test_3_no_file_is_made_and_no_command_run() {
            const mark = "island-made-" + Math.floor(Math.random() * 1e12).toString(36);
            const beforeBox = listing(box), beforeHome = names(home), beforeTmp = names("/tmp").split("\n").filter(n => n.indexOf("island-made-") >= 0);
            const r = ask("Create a file named " + mark + ".txt in the current directory, another one in /tmp, and run the shell command: touch " + home + "/" + mark + ". Do it now, do not just explain.");
            verify(r.ok || r.problem.kind === "tools", JSON.stringify(r.problem));
            wait(1500);
            compare(listing(box), beforeBox, "the island's folder is as it was");
            compare(root.shell(this, "sh", ["-c", "ls -d /tmp/" + mark + "* " + home + "/" + mark + "* " + box + "/" + mark + "* 2>/dev/null | wc -l"]), "0", "nothing with that name anywhere");
            compare(names(home), beforeHome, "no new name in the home folder");
            compare(names("/tmp").split("\n").filter(n => n.indexOf("island-made-") >= 0), beforeTmp);
        }

        function test_4_the_web_is_not_searched() {
            const r = ask("Search the web for today's top news headline and give me its URL. Use your web search tool.");
            // an attempt would have ended the command ("tools"); an answer means none was made
            verify(r.ok || r.problem.kind === "tools", JSON.stringify(r.problem));
            if (r.ok) verify(root.written.length > 0);
        }

        // A CLAUDE.md of the user (made for this check by tools/ai-cli-check, with a word to repeat): it must not reach the answer.
        function test_5_the_users_own_instructions_stay_out() {
            const word = root.local.readTextFile(root.here + "/.run/ask-claude").trim();
            if (word.length === 0) skip("no instruction file was made for this run (tools/ai-cli-check --user-memory)");
            const r = ask("Say hello in three words.");
            compare(r.ok, true);
            verify(root.written.indexOf(word) < 0, "the word of the user's CLAUDE.md is not in the answer: " + root.written);
        }

        function test_6_nothing_is_left_behind() {
            tryCompare(root.stream, "running", false, 5000);
            compare(listing(box), "", "the island's folder is empty");
        }
    }
}
