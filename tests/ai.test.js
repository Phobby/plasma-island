#!/usr/bin/env node
// The AI tab's network providers without a network: how an answer is read
// while it is written, what a service's error means and which address is
// this computer (contents/ui/ai/AiStream.js). Run by tools/run-tests.
"use strict";
const fs = require("fs");
const path = require("path");

const UI = path.join(__dirname, "..", "org.phobby.dynamicisland", "contents", "ui");
function load(file) {
    const source = fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*$/m, "");
    const names = Array.from(source.matchAll(/^(?:function|const) (\w+)[ (=]/gm), m => m[1]);
    return new Function(source + "\nreturn { " + names.join(", ") + " };")();
}
const S = load(path.join(UI, "ai", "AiStream.js"));

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

test("server-sent events: whole lines only, in pieces", () => {
    const r = S.reader();
    let text = ": comment\n\ndata: {\"a\":1}\n\nevent: ping\nda";
    check("first two", S.events(r, text), [{ event: "", data: "{\"a\":1}" }]);
    text += "ta: x\r\ndata: y\r\n\r\ndata: half";
    check("an event of two data lines, CRLF", S.events(r, text), [{ event: "ping", data: "x\ny" }]);
    check("nothing new", S.events(r, text), []);
    text += " ü\n\n";
    check("the rest", S.events(r, text), [{ event: "", data: "half ü" }]);
    check("data without a space", S.events(S.reader(), "data:{\"b\":2}\n\n"), [{ event: "", data: "{\"b\":2}" }]);
});

test("OpenAI-compatible stream", () => {
    const chunk = (delta, finish) => JSON.stringify({ choices: [{ index: 0, delta: delta, finish_reason: finish || null }] });
    check("role only", S.openAiEvent(chunk({ role: "assistant", content: "" })), {});
    check("text", S.openAiEvent(chunk({ content: "Mer" })), { text: "Mer" });
    check("what the model thinks is not shown", S.openAiEvent(chunk({ reasoning_content: "hmm", content: "" })), {});
    check("parts", S.openAiEvent(chunk({ content: [{ type: "text", text: "a" }, { type: "text", text: "b" }] })), { text: "ab" });
    check("end", S.openAiEvent(chunk({}, "stop")), { finish: "stop" });
    check("cut off", S.openAiEvent(chunk({ content: "x" }, "length")), { text: "x", finish: "length" });
    check("done", S.openAiEvent(" [DONE] "), { done: true });
    check("no choices (usage chunk)", S.openAiEvent(JSON.stringify({ choices: [], usage: {} })), {});
    check("not JSON", S.openAiEvent("oops"), {});
    check("an error inside the stream", S.openAiEvent(JSON.stringify({ error: { message: "The upstream provider failed.", code: 502 } })).problem,
          { kind: "server", detail: "The upstream provider failed." });
    check("a limit inside the stream", S.openAiEvent(JSON.stringify({ error: { message: "slow down", code: 429 } })).problem.kind, "limit");
    check("body", S.openAiBody("m", "sys", [{ role: "user", text: "q" }, { role: "assistant", text: "a" }, { role: "user", text: "q2" }], 256, ""),
          { model: "m", stream: true, messages: [{ role: "system", content: "sys" }, { role: "user", content: "q" }, { role: "assistant", content: "a" }, { role: "user", content: "q2" }], max_tokens: 256 });
    check("the newer name of the limit", S.openAiBody("m", "", [{ role: "user", text: "q" }], 9, "max_completion_tokens").max_completion_tokens, 9);
    check("asked for by the service", S.wantsNewLimitField(400, JSON.stringify({ error: { message: "Unsupported parameter: 'max_tokens' is not supported with this model. Use 'max_completion_tokens' instead." } })), true);
    check("not by another 400", S.wantsNewLimitField(400, JSON.stringify({ error: { message: "bad request" } })), false);
    check("models, sorted", S.openAiModels(JSON.stringify({ data: [{ id: "b" }, { id: "a" }, { nope: 1 }, { id: "" }] })), [{ id: "a", name: "a" }, { id: "b", name: "b" }]);
    check("models: nonsense", S.openAiModels("<html>"), []);
});

test("Anthropic stream", () => {
    const ev = o => S.anthropicEvent(JSON.stringify(o));
    check("text", ev({ type: "content_block_delta", index: 1, delta: { type: "text_delta", text: "Hi" } }), { text: "Hi" });
    check("thinking is not shown", ev({ type: "content_block_delta", index: 0, delta: { type: "thinking_delta", thinking: "secret" } }), {});
    check("signature", ev({ type: "content_block_delta", index: 0, delta: { type: "signature_delta", signature: "x" } }), {});
    check("ping", ev({ type: "ping" }), {});
    check("an event not known yet", ev({ type: "something_new", x: 1 }), {});
    check("stop", ev({ type: "message_delta", delta: { stop_reason: "max_tokens", stop_sequence: null } }), { stop: "max_tokens" });
    check("done", ev({ type: "message_stop" }), { done: true });
    check("overloaded", ev({ type: "error", error: { type: "overloaded_error", message: "Overloaded" } }).problem, { kind: "server", detail: "Overloaded" });
    check("body", S.anthropicBody("claude-x", "sys", [{ role: "user", text: "q" }], 512),
          { model: "claude-x", max_tokens: 512, stream: true, messages: [{ role: "user", content: "q" }], system: "sys" });
    check("models keep the service's order", S.anthropicModels(JSON.stringify({ data: [{ id: "z", display_name: "Zed" }, { id: "a" }], has_more: false })),
          [{ id: "z", name: "Zed" }, { id: "a", name: "a" }]);
});

test("what went wrong", () => {
    const body = m => JSON.stringify({ error: { message: m } });
    check("no connection", S.httpProblem(0, ""), { kind: "network", detail: "" });
    check("401", S.httpProblem(401, body("Incorrect API key provided.")), { kind: "auth", detail: "Incorrect API key provided." });
    check("403", S.httpProblem(403, "").kind, "auth");
    check("Gemini's 400 for a wrong key", S.httpProblem(400, JSON.stringify([{ error: { code: 400, message: "Please pass a valid API key" } }])).kind, "auth");
    check("another 400", S.httpProblem(400, body("messages: roles must alternate")), { kind: "unknown", detail: "messages: roles must alternate" });
    check("429", S.httpProblem(429, body("Rate limit reached")).kind, "limit");
    check("402", S.httpProblem(402, "").kind, "limit");
    check("404", S.httpProblem(404, body("The model `x` does not exist.")).kind, "model");
    check("500", S.httpProblem(500, "<html>Bad gateway</html>"), { kind: "server", detail: "" });
    check("529", S.httpProblem(529, "").kind, "server");
    check("504", S.httpProblem(504, "").kind, "timeout");
    check("418", S.httpProblem(418, "nope"), { kind: "unknown", detail: "HTTP 418" });
    check("Ollama's plain error", S.errorMessage(JSON.stringify({ error: "model 'x' not found" })), "model 'x' not found");
    check("Anthropic's error", S.errorMessage(JSON.stringify({ type: "error", error: { type: "authentication_error", message: "invalid x-api-key" } })), "invalid x-api-key");
    check("Anthropic's names", ["authentication_error", "permission_error", "rate_limit_error", "billing_error", "not_found_error", "overloaded_error", "api_error", "invalid_request_error"]
          .map(t => S.anthropicProblem(t, "").kind), ["auth", "auth", "limit", "limit", "model", "server", "server", "unknown"]);
    check("a long message is cut", S.problem("unknown", "x".repeat(900)).detail.length, 300);
    check("a key never shows", S.scrub("Incorrect API key provided: sk-secret-123.", "sk-secret-123"), "Incorrect API key provided: ….");
    check("nothing to hide", S.scrub("fine", ""), "fine");
});

test("addresses", () => {
    check("Ollama", S.address("http://localhost:11434/v1/"), { ok: true, scheme: "http", host: "localhost", base: "http://localhost:11434/v1" });
    check("no path", S.address(" https://API.example.org "), { ok: true, scheme: "https", host: "api.example.org", base: "https://API.example.org" });
    check("IPv6", S.address("http://[::1]:8080/v1").host, "[::1]");
    check("no scheme", S.address("localhost:11434").ok, false);
    check("another scheme", S.address("file:///etc/passwd").ok, false);
    check("a user in it", S.address("http://user:pw@example.org/v1").ok, false);
    check("a query", S.address("http://example.org/v1?key=abc").ok, false);
    check("this device", ["localhost", "LOCALHOST", "127.0.0.1", "127.5.6.7", "[::1]"].map(S.isThisDevice), [true, true, true, true, true]);
    check("not this device", ["192.168.1.5", "example.org", "localhost.example.org", "127.0.0.1.example.org", "10.0.0.1", ""].map(S.isThisDevice), [false, false, false, false, false, false]);
});

console.log(failed === 0 ? `${checked} checks passed` : `${failed} of ${checked} checks FAILED`);
process.exit(failed > 0 ? 1 : 0);
