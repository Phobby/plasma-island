#!/usr/bin/env node
// Antigravity's command as the AI tab uses it (contents/ui/ai/Antigravity.js):
// the options it is started with, what is written to it and how its output
// is read. Run by tools/run-tests; tests/tst_ai_agy.qml runs the provider.
"use strict";
const fs = require("fs");
const path = require("path");

const UI = path.join(__dirname, "..", "org.phobby.dynamicisland", "contents", "ui");
function load(file) {
    const source = fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*$/m, "");
    const names = Array.from(source.matchAll(/^(?:function|const) (\w+)[ (=]/gm), m => m[1]);
    return new Function(source + "\nreturn { " + names.join(", ") + " };")();
}
const A = load(path.join(UI, "ai", "Antigravity.js"));

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

test("Antigravity: the options", () => {
    const plain = A.commandArguments("");
    check("print mode, lines of JSON both ways", plain.slice(0, 4), ["--output-format", "stream-json", "--input-format", "stream-json"]);
    check("its restrictions", [plain.includes("--sandbox"), plain.includes("--disable-slash-commands")], [true, true]);
    check("never the option that allows every tool", plain.includes("--dangerously-skip-permissions"), false);
    check("the empty prompt comes last", plain[plain.length - 1], "-p=");
    check("no model named", plain.includes("--model"), false);
    const named = A.commandArguments("pro-high");
    check("a model", named.slice(named.indexOf("--model"), named.indexOf("--model") + 2), ["--model", "pro-high"]);
});

test("Antigravity: version and models", () => {
    check("version", A.version("1.2.17\n"), "1.2.17");
    check("no version", A.version("command not found"), "");
    check("models", A.models("Fetching available models...\ngemini-3.8-flash-low\tGemini 3.8 Flash (Low)\nclaude-sonnet-4-6\tClaude Sonnet 4.6 (Thinking)\n\n"),
          [{ id: "gemini-3.8-flash-low", name: "Gemini 3.8 Flash (Low)" }, { id: "claude-sonnet-4-6", name: "Claude Sonnet 4.6 (Thinking)" }]);
    check("an error is no model", A.models("Error: not authenticated\n"), []);
});

test("Antigravity: what is written to it", () => {
    const one = JSON.parse(A.input([{ role: "user", text: "What is 2+2?" }], "Text only."));
    check("one line", A.input([{ role: "user", text: "a\nb" }], "").split("\n").length, 2);
    check("the event", [one.event, Object.keys(one.message)], ["user", ["content"]]);
    check("the instruction, then the question", one.message.content, "<instructions>\nText only.\n</instructions>\n\nWhat is 2+2?");
    const more = JSON.parse(A.input([{ role: "user", text: "Q1" }, { role: "assistant", text: "A1" }, { role: "user", text: "Q2" }], "")).message.content;
    check("a follow-up carries the earlier messages", [more.includes("<message role=\"user\">\nQ1"), more.includes("<message role=\"assistant\">\nA1"), more.endsWith("<message role=\"user\">\nQ2\n</message>")], [true, true, true]);
});

test("Antigravity: its output", () => {
    const step = s => JSON.stringify({ event: "step_update", step_update: s });
    check("how it runs", A.event(JSON.stringify({ event: "init", init: { cwd: "/box", tools: ["run_command"], permission_mode: "request-review" } })), { init: { mode: "request-review", cwd: "/box" } });
    check("the question itself", A.event(step({ step_type: "user_input", state: "DONE" })), {});
    check("a piece", A.event(step({ step_type: "agent_response", state: "ACTIVE", text_delta: "Hi" })), { text: "Hi" });
    check("a step without text", A.event(step({ step_type: "agent_response", state: "DONE" })), {});
    check("a tool", A.event(step({ step_type: "tool", state: "ACTIVE", tool_name: "view_file" })), { tool: "view_file" });
    check("a step it does not know is no text", A.event(step({ step_type: "browser", state: "ACTIVE" })), { tool: "browser" });
    check("the end", A.event(JSON.stringify({ event: "result", result: { status: "SUCCESS", response: "Hi\n", denied_actions: [{ action: "read_file" }] } })),
          { result: { ok: true, text: "Hi\n", error: "", denials: 1 } });
    check("not JSON", A.event("jetski: no output"), {});
});

test("Antigravity: what went wrong", () => {
    const result = (error, denials) => ({ ok: false, text: "", error: error, denials: denials || 0 });
    check("signed out", A.failure(result("not authenticated: sign in first")), { kind: "auth", detail: "" });
    check("a refused tool", A.failure(result("turn ended", 1)), { kind: "tools", detail: "" });
    check("the quota", A.failure(result("RESOURCE_EXHAUSTED: quota exceeded")).kind, "limit");
    check("a model it does not have", A.failure(result("model xyz not found")).kind, "model");
    check("anything else", A.failure(result("Something odd")), { kind: "unknown", detail: "Something odd" });
    check("an option it does not know", A.exitFailure(2, "flag provided but not defined: -input-format\nUsage of agy:").kind, "version");
    check("could not be started", A.exitFailure(-1, ""), { kind: "missing", detail: "" });
    check("signed out, said on the way out", A.exitFailure(1, "Error: not authenticated. Run agy to sign in."), { kind: "auth", detail: "" });
});

console.log(failed === 0 ? `${checked} checks passed` : `${failed} of ${checked} checks FAILED`);
process.exit(failed > 0 ? 1 : 0);
