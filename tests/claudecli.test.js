#!/usr/bin/env node
// Claude Code as the AI tab uses it (contents/ui/ai/ClaudeCli.js): the options
// it is started with, what is written to it and how its output is read.
// Run by tools/run-tests; tests/tst_ai_cli.qml asks the real command.
"use strict";
const fs = require("fs");
const path = require("path");

const UI = path.join(__dirname, "..", "org.phobby.dynamicisland", "contents", "ui");
function load(file) {
    const source = fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*$/m, "");
    const names = Array.from(source.matchAll(/^(?:function|const) (\w+)[ (=]/gm), m => m[1]);
    return new Function(source + "\nreturn { " + names.join(", ") + " };")();
}
const C = load(path.join(UI, "ai", "ClaudeCli.js"));

let failed = 0, checked = 0;
function check(what, got, want) {
    ++checked;
    const g = JSON.stringify(got), w = JSON.stringify(want);
    if (g === w) return;
    ++failed;
    console.log("    FAILED: " + what + "\n      got  " + g + "\n      want " + w);
}
function test(name, body) {
    const before = failed;
    body();
    console.log((failed === before ? "  ok    " : "  FAIL  ") + name);
}

test("Claude Code: the options", () => {
    const args = C.commandArguments("", "SYSTEM");
    const has = (...seq) => { for (let i = 0; i + seq.length <= args.length; ++i) if (seq.every((s, k) => args[i + k] === s)) return true; return false; };
    check("one answer, as lines of JSON", [has("-p"), has("--output-format", "stream-json"), has("--verbose"), has("--include-partial-messages")], [true, true, true, true]);
    check("no tools at all", has("--tools", ""), true);
    check("no MCP servers", has("--strict-mcp-config"), true);
    check("no settings of the user or a project", [has("--setting-sources", ""), has("--safe-mode"), has("--restricted"), has("--disable-slash-commands")], [true, true, true, true]);
    check("what would ask is refused", [has("--permission-mode", "dontAsk"), has("--permission-prompts", "none")], [true, true]);
    check("one turn", has("--max-turns", "1"), true);
    check("nothing kept", has("--no-session-persistence"), true);
    check("its own instruction", has("--system-prompt", "SYSTEM"), true);
    check("no model named", args.indexOf("--model"), -1);
    check("a model named", C.commandArguments("sonnet", "S").slice(-2), ["--model", "sonnet"]);
    for (const never of ["--dangerously-skip-permissions", "--allow-dangerously-skip-permissions", "--allowedTools", "--allowed-tools", "--add-dir", "--mcp-config",
                         "--continue", "-c", "--resume", "-r", "--bare", "bypassPermissions", "acceptEdits", "auto"])
        check("never " + never, args.indexOf(never), -1);
});

test("Claude Code: version and the model names of its own help", () => {
    check("version", C.version("2.1.289 (Claude Code)\n"), "2.1.289");
    check("no version", C.version("command not found"), "");
    const help = ["  --mcp-config <configs...>             Load MCP servers from JSON files or",
                  "                                        strings (space-separated)",
                  "  --model <model>                       Model for the current session. Provide",
                  "                                        an alias for the latest model (e.g.",
                  "                                        'fable', 'opus', or 'sonnet') or a",
                  "                                        model's full name.",
                  "  -n, --name <name>                     Set a display name for this session",
                  "                                        (shown in the 'prompt' box)"].join("\n");
    check("the names it gives", C.aliases(help), ["fable", "opus", "sonnet"]);
    check("a help without them", C.aliases("  --model <model>   Model for the current session.\n  -n, --name <name>  x 'y'"), []);
    check("no --model", C.aliases("Usage: claude"), []);
});

test("Claude Code: what is written to it", () => {
    check("one question as it is", C.transcript([{ role: "user", text: "What is 2+2?" }]), "What is 2+2?");
    const t = C.transcript([{ role: "user", text: "My number is 7." }, { role: "assistant", text: "Noted." }, { role: "user", text: "Plus one?" }]);
    check("a follow-up carries the earlier messages", t,
          "The conversation so far, oldest first:\n\n<message role=\"user\">\nMy number is 7.\n</message>\n<message role=\"assistant\">\nNoted.\n</message>\n"
          + "\nReply to this new message from the user:\n\n<message role=\"user\">\nPlus one?\n</message>");
    check("nothing", C.transcript([]), "");
});

test("Claude Code: its output", () => {
    const line = o => C.event(JSON.stringify(o));
    check("the start", line({ type: "system", subtype: "init", cwd: "/x/ai-sandbox", tools: [], mcp_servers: [], model: "m" }),
          { init: { tools: [], servers: [], cwd: "/x/ai-sandbox" } });
    check("a start with tools", line({ type: "system", subtype: "init", cwd: "/x", tools: ["Bash", "mcp__a__b"], mcp_servers: [{ name: "a", status: "connected" }] }).init,
          { tools: ["Bash", "mcp__a__b"], servers: ["a"], cwd: "/x" });
    check("a piece", line({ type: "stream_event", event: { type: "content_block_delta", index: 0, delta: { type: "text_delta", text: "2+2" } } }), { text: "2+2" });
    check("thinking", line({ type: "stream_event", event: { type: "content_block_start", index: 0, content_block: { type: "thinking", thinking: "" } } }), {});
    check("a text block opens", line({ type: "stream_event", event: { type: "content_block_start", index: 0, content_block: { type: "text", text: "" } } }), {});
    check("a tool block opens", line({ type: "stream_event", event: { type: "content_block_start", index: 1, content_block: { type: "tool_use", name: "Read" } } }), { tool: "Read" });
    check("a server tool", line({ type: "stream_event", event: { type: "content_block_start", index: 1, content_block: { type: "server_tool_use", name: "web_search" } } }), { tool: "web_search" });
    check("a whole message", line({ type: "assistant", message: { content: [{ type: "thinking", thinking: "" }, { type: "text", text: "4." }] } }), { whole: "4." });
    check("a whole message with a tool", line({ type: "assistant", message: { content: [{ type: "text", text: "Let me look." }, { type: "tool_use", name: "Bash", input: {} }] } }), { tool: "Bash" });
    check("a tool's result", line({ type: "user", message: { content: [{ type: "tool_result", tool_use_id: "t", content: "x" }] } }), { tool: "tool_result" });
    check("the usage limit", line({ type: "rate_limit_event", rate_limit_info: { status: "rejected" } }), { limited: true });
    check("a warning is no limit", line({ type: "rate_limit_event", rate_limit_info: { status: "allowed_warning" } }), {});
    check("the result", line({ type: "result", subtype: "success", is_error: false, result: "4.", api_error_status: null, permission_denials: [] }),
          { result: { ok: true, text: "4.", status: 0, subtype: "success", denials: 0 } });
    check("not a line of JSON", C.event("Warning: something"), {});
    check("other", line({ type: "system", subtype: "status", status: "requesting" }), {});

    const result = (text, more) => Object.assign({ ok: false, text: text, status: 0, subtype: "success", denials: 0 }, more || {});
    check("not signed in", C.failure(result("Not logged in · Please run /login"), false), { kind: "auth", detail: "" });
    check("a tool loop was ended", C.failure(result("", { subtype: "error_max_turns" }), false).kind, "tools");
    check("a refused permission", C.failure(result("x", { denials: 1 }), false).kind, "tools");
    check("the limit", C.failure(result("You've hit your limit · resets 3pm"), false).kind, "limit");
    check("the limit event", C.failure(result("stopped"), true).kind, "limit");
    check("429", C.failure(result("Too many", { status: 429 }), false).kind, "limit");
    check("an unknown model", C.failure(result("There's an issue with the selected model (x).", { status: 404 }), false),
          { kind: "model", detail: "There's an issue with the selected model (x)." });
    check("the service", C.failure(result("Overloaded", { status: 529 }), false).kind, "server");
    check("anything else", C.failure(result("Something odd"), false), { kind: "unknown", detail: "Something odd" });
    check("an option it does not know", C.exitFailure(1, "error: unknown option '--safe-mode'\n(use --help)"), { kind: "version", detail: "error: unknown option '--safe-mode'" });
    check("could not be started", C.exitFailure(-1, ""), { kind: "missing", detail: "" });
    check("ended some other way", C.exitFailure(3, "\n  boom\n").detail, "boom");
});

console.log(failed === 0 ? `${checked} checks passed` : `${failed} of ${checked} checks FAILED`);
process.exit(failed > 0 ? 1 : 0);
