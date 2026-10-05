/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Antigravity's command (`agy`) on this computer as a plain
    question-and-answer box. The user is signed in there already, so no key
    is needed and the island never sees an account: it only starts the
    command and reads what it prints. Nothing under ~/.gemini is opened,
    copied or shown by the island.

    Not an agent, but less tightly so than Claude Code (ClaudeCliProvider.qml):
    this command cannot be started without its tools. What keeps them unused:
      1. nobody can be asked: started this way, the command itself refuses
         whatever needs a permission (seen with 1.2.17: reading a file outside
         its folder was refused). Its first line says which way it runs; any
         other than the asking one ("request-review"), or a folder that is not
         the island's, and it is stopped before a question is answered;
      2. the island watches the steps: the first one that is not text (a tool,
         allowed or not) stops the command at once. A tool that needs no
         permission, or one the user allowed in Antigravity's own settings,
         may have run by then; in the island's empty folder there is nothing
         for it to read;
      3. the instruction says so too (AiBackend.systemPrompt), in front of the
         question: the command takes no instruction of its own.

    The command always runs in `sandbox`, the island's own empty folder. The
    question goes to its standard input, not to its arguments. It is started
    anew for every question, so a follow-up carries the earlier messages
    along (Antigravity.input). Antigravity itself keeps every question in its
    history; it has no option not to.

    The model: the command's own choice, or one of `agy models`.

    Needs the native module (a command read while it runs).
*/
import QtQuick
import ".."
import "Antigravity.js" as Cli

AiProvider {
    id: provider

    readonly property var local: core !== null ? core.local : null
    // The native helper that runs the command; asked of the core when first needed.
    property var process: null
    function ready(): bool {
        if (process === null && core !== null) process = typeof core.streamProcess === "function" ? core.streamProcess() : core.stream || null;
        return local !== null && process !== null;
    }
    property string sandbox: local ? local.dataHome() + "/dynamicisland/ai-sandbox" : ""
    // The command's name: looked for on the PATH and in ~/.local/bin.
    property string commandName: "agy"
    property string command: ""             // its full path, once found
    property string version: ""
    property var names: []                  // [{ id, name }] of `agy models`

    function run(args: var, done: var): void {
        if (typeof local.runIn === "function") local.runIn(sandbox, command, args, done); else local.run(command, args, done);
    }
    // done({ found, helper, version }): helper = the native module is there.
    function detect(done: var): void {
        if (!ready()) { done({ found: false, helper: false, version: "" }); return; }
        command = local.findExecutable(commandName);
        if (command.length === 0) { version = ""; names = []; done({ found: false, helper: true, version: "" }); return; }
        run(["--version"], (code, out) => {
            version = code === 0 ? Cli.version(out) : "";
            done({ found: version.length > 0, helper: true, version: version });
        });
    }
    // Connecting: the command is there, and it can say which models it has (it cannot when signed out).
    function verify(done: var): void {
        detect(found => {
            if (!found.found) { done({ ok: false, models: [], problem: { kind: "missing", detail: "" } }); return; }
            run(["models"], (code, out, errorOutput) => {
                names = Cli.models(out);
                if (names.length > 0) listModels(done);
                else done({ ok: false, models: [], problem: Cli.exitFailure(code === 0 ? 1 : code, String(errorOutput || "") + "\n" + out) });
            });
        });
    }
    function listModels(done: var): void {
        const answer = () => done({ ok: true, models: [{ id: "", name: Lang.i18n("Antigravity's own choice") }].concat(names), problem: null });
        if (names.length > 0 || !ready()) { answer(); return; }
        const ask = () => {
            if (command.length === 0) { answer(); return; }
            run(["models"], (code, out) => { names = Cli.models(out); answer(); });
        };
        if (command.length === 0) detect(ask); else ask();
    }

    // ---- one question ----------------------------------------------------------------
    property bool asking: false             // a question of ours is with the command
    property bool checked: false            // its first line: it asks before a tool, in the island's folder
    property bool wrote: false
    property var queued: null               // a question waiting for the command of the one before to end

    function send(messages: var, model: string, options: var): void {
        if (!ready()) { finished({ ok: false, cut: false, problem: { kind: "missing", detail: "" } }); return; }
        const start = () => {
            if (command.length === 0) { finished({ ok: false, cut: false, problem: { kind: "missing", detail: "" } }); return; }
            if (process.running) {
                // (the command of the question before has not ended yet: that one is given up)
                asking = false;
                queued = { messages: messages, model: model, options: options };
                process.stop();
                return;
            }
            asking = true; checked = false; wrote = false;
            if (process.start(command, Cli.commandArguments(model), Cli.input(messages, String(options.system || "")), sandbox)) return;
            asking = false;
            finished({ ok: false, cut: false, problem: { kind: "missing", detail: "" } });
        };
        if (command.length === 0) detect(start); else start();
    }
    function cancel(): void {
        asking = false;
        queued = null;
        if (process !== null && process.running) process.stop();
    }
    function fail(kind: string, detail: string): void {
        asking = false;
        if (process.running) process.stop();
        finished({ ok: false, cut: false, problem: { kind: kind, detail: detail } });
    }

    function take(line: string): void {
        const e = Cli.event(line);
        alive();
        if (e.init !== undefined) {
            const inBox = e.init.cwd === sandbox || e.init.cwd.endsWith("/dynamicisland/ai-sandbox");
            if (e.init.mode !== "request-review") fail("version", e.init.mode);
            else if (!inBox) fail("version", e.init.cwd);
            else checked = true;
            return;
        }
        if (e.tool !== undefined) { fail("tools", ""); return; }
        if (e.text !== undefined) {
            // an answer before the command has said how it runs is not shown
            if (!checked) { fail("version", ""); return; }
            wrote = true;
            delta(e.text);
            return;
        }
        if (e.result === undefined) return;
        if (!e.result.ok) {
            asking = false;
            finished({ ok: false, cut: false, problem: Cli.failure(e.result) });
        } else if (!checked) fail("version", "");
        else if (e.result.denials > 0) fail("tools", "");
        else {
            asking = false;
            if (!wrote && e.result.text.length > 0) delta(e.result.text);
            finished({ ok: true, cut: false, problem: null });
        }
    }
    readonly property Connections watch: Connections {
        target: provider.process
        function onLines(lines) {
            for (const line of lines) {
                if (!provider.asking) return;
                provider.take(line);
            }
        }
        function onFinished(exitCode, errorOutput) {
            if (provider.asking) {
                provider.asking = false;
                provider.finished({ ok: false, cut: false, problem: Cli.exitFailure(exitCode, errorOutput) });
            }
            const next = provider.queued;
            provider.queued = null;
            if (next !== null) provider.send(next.messages, next.model, next.options);
        }
    }
    Component.onDestruction: cancel()
}
