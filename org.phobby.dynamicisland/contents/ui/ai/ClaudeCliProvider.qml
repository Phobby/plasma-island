/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Claude Code on this computer as a plain question-and-answer box. The user
    is signed in there already, so no key is needed and the island never sees
    an account: it only starts the `claude` command and reads what it prints.
    Nothing under ~/.claude is opened, copied or shown by the island.

    Not an agent. Three layers, the first two enforced, the third only asked:
      1. no tools exist for the model: the built-in ones are switched off, no
         MCP server is loaded, and whatever would ask for a permission is
         refused (the options and what each is for: ClaudeCli.js);
      2. one turn: the answer, then the end;
      3. the instruction says so too (AiBackend.systemPrompt).
    And the island checks what the command says about itself: its first line
    lists its tools, its MCP servers and its folder. If any tool or server is
    there, or the folder is not the island's, the command is stopped before a
    question is answered. If the model reaches for a tool all the same, the
    command is stopped at that moment. A Claude Code that does not know one
    of the options ends with an error; it is not tried again with fewer.

    The command always runs in `sandbox`, an empty folder of the island's
    own, never where the shell or a project happens to be. The user's own
    settings, hooks, MCP servers, skills and CLAUDE.md files are not loaded.
    The question goes to the command's standard input, not to its arguments.
    Nothing of a chat is written to ~/.claude (no session is kept), which is
    why a follow-up carries the earlier messages along (ClaudeCli.transcript).

    The model: the command's own choice, one of the names its --help gives as
    examples, or a name the user typed in the settings. No list is kept here.

    Needs the native module (a command read while it runs).
*/
import QtQuick
import ".."
import "ClaudeCli.js" as Cli

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
    property string commandName: "claude"
    property string command: ""             // its full path, once found
    property string version: ""
    property var names: []                  // the model names of its own --help

    // The command itself is asked (version, help, sign-in state), in the island's folder too.
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
            run(["--help"], (code2, help) => {
                names = code2 === 0 ? Cli.aliases(help) : [];
                done({ found: version.length > 0, helper: true, version: version });
            });
        });
    }
    // Connecting: the command is there, and it says it is signed in.
    function verify(done: var): void {
        detect(found => {
            if (!found.found) { done({ ok: false, models: [], problem: { kind: "missing", detail: "" } }); return; }
            run(["auth", "status", "--json"], (code, out) => {
                let signedIn = true;
                // (a Claude Code that cannot say is taken at its word when the first question is asked)
                try { signedIn = JSON.parse(out).loggedIn !== false; } catch (e) { signedIn = true; }
                if (!signedIn) done({ ok: false, models: [], problem: { kind: "auth", detail: "" } });
                else listModels(done);
            });
        });
    }
    function listModels(done: var): void {
        const answer = () => {
            const list = [{ id: "", name: Lang.i18n("Claude Code's own choice") }];
            for (const name of names) list.push({ id: name, name: name });
            done({ ok: true, models: list, problem: null });
        };
        if (ready() && command.length === 0) detect(answer); else answer();
    }

    // ---- one question ----------------------------------------------------------------
    property bool asking: false             // a question of ours is with the command
    property bool checked: false            // its first line: no tools, no servers, the island's folder
    property bool wrote: false
    property bool limited: false
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
            asking = true; checked = false; wrote = false; limited = false;
            if (process.start(command, Cli.commandArguments(model, options.system), Cli.transcript(messages), sandbox)) return;
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
            const extra = e.init.tools.concat(e.init.servers);
            if (extra.length > 0) fail("version", extra.slice(0, 3).join(", "));
            else if (!inBox) fail("version", e.init.cwd);
            else checked = true;
            return;
        }
        if (e.tool !== undefined) { fail("tools", ""); return; }
        if (e.limited === true) { limited = true; return; }
        if (e.text !== undefined || e.whole !== undefined) {
            // an answer before the command has said what it runs with is not shown
            if (!checked) { fail("version", ""); return; }
            if (e.text !== undefined) { wrote = true; delta(e.text); }
            else if (!wrote && e.whole.length > 0) { wrote = true; delta(e.whole); }
            return;
        }
        if (e.result === undefined) return;
        if (!e.result.ok) {
            asking = false;
            finished({ ok: false, cut: false, problem: Cli.failure(e.result, limited) });
        } else if (!checked) fail("version", "");
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
