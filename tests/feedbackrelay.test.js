#!/usr/bin/env node
// The feedback relay (tools/feedback-relay/relay.mjs): what it takes, what it passes on to
// Telegram and how, what it refuses, and that the bot's token never leaves it. Telegram is a
// stand-in here; nothing goes to the network. Run by tools/run-tests.
"use strict";
const fs = require("fs");
const path = require("path");

let failed = 0, checked = 0;
function check(what, got, want) {
    ++checked;
    const g = JSON.stringify(got), w = JSON.stringify(want);
    if (g === w) return;
    ++failed;
    console.log("    FAILED: " + what + "\n      got  " + g + "\n      want " + w);
}
async function test(name, body) {
    const before = failed;
    await body();
    console.log((failed === before ? "  ok    " : "  FAIL  ") + name);
}

const TOKEN = "123456:made-up-token";
const env = { BOT_TOKEN: TOKEN, CHAT_ID: "4242" };

// A stand-in Telegram: what it was asked, and what it answers.
function telegram(answer) {
    const calls = [];
    return {
        calls,
        fetch: async (url, options) => {
            calls.push({ url, options });
            if (answer === "down") throw new Error("no connection");
            return new Response(JSON.stringify({ ok: answer !== "refuse", result: { message_id: 77 } }), { status: answer === "refuse" ? 400 : 200 });
        }
    };
}
function post(body, headers) {
    const text = typeof body === "string" ? body : JSON.stringify(body);
    return new Request("https://island-feedback.example.workers.dev/", {
        method: "POST", body: text,
        headers: Object.assign({ "Content-Type": "application/json", "CF-Connecting-IP": "203.0.113.9" }, headers || {})
    });
}
const never = async () => false;

(async () => {
    const W = await import(path.join(__dirname, "..", "tools", "feedback-relay", "relay.mjs"));

    await test("the limits are the island's (Feedback.js)", async () => {
        const source = fs.readFileSync(path.join(__dirname, "..", "org.phobby.dynamicisland", "contents", "ui", "Feedback.js"), "utf8");
        for (const name of ["MAX_MESSAGE", "MAX_CONTACT", "MAX_REPORT"])
            check(name, Number((source.match(new RegExp("const " + name + " = (\\d+)")) || [])[1]), W[name]);
    });

    await test("a message goes to the chat as plain text", async () => {
        const t = telegram("ok");
        const res = await W.handle(post({ message: "The cat is <b>great</b>", contact: "@someone", island: "0.2.2", language: "tr", session: "Wayland" }), env, { fetch: t.fetch, limited: never });
        check("answered", res.status, 200);
        check("one call", t.calls.length, 1);
        check("to sendMessage with the token", t.calls[0].url, "https://api.telegram.org/bot" + TOKEN + "/sendMessage");
        const sent = JSON.parse(t.calls[0].options.body);
        check("the chat", sent.chat_id, "4242");
        check("no markup is read", sent.parse_mode, undefined);
        check("the text", sent.text, "Dynamic Island feedback\nisland 0.2.2 · tr · Wayland\nanswer to: @someone\n\nThe cat is <b>great</b>");
        const body = await res.text();
        check("the token is not in the answer", body.includes(TOKEN) || body.includes("made-up-token"), false);
    });

    await test("the report follows as a file, a reply to the message", async () => {
        const t = telegram("ok");
        const res = await W.handle(post({ message: "It hides over full screen", report: "Dynamic Island diagnostics\nisland: 0.2.2" }), env, { fetch: t.fetch, limited: never });
        check("answered", res.status, 200);
        check("two calls", t.calls.length, 2);
        check("sendDocument", t.calls[1].url.endsWith("/sendDocument"), true);
        const form = t.calls[1].options.body;
        check("the chat", form.get("chat_id"), "4242");
        check("a reply", JSON.parse(form.get("reply_parameters")).message_id, 77);
        const file = form.get("document");
        check("file name", file.name, "diagnostics.txt");
        check("file text", await file.text(), "Dynamic Island diagnostics\nisland: 0.2.2");
    });

    await test("what is not taken", async () => {
        const t = telegram("ok");
        const deps = { fetch: t.fetch, limited: never };
        check("GET", (await W.handle(new Request("https://x.example/"), env, deps)).status, 405);
        check("another path", (await W.handle(new Request("https://x.example/bot", { method: "POST" }), env, deps)).status, 404);
        check("not JSON as declared", (await W.handle(post({ message: "hi" }, { "Content-Type": "text/plain" }), env, deps)).status, 415);
        check("not JSON", (await W.handle(post("{ message"), env, deps)).status, 400);
        check("empty", (await W.handle(post({ message: "   " }), env, deps)).status, 400);
        check("too long", (await W.handle(post({ message: "x".repeat(W.MAX_MESSAGE + 1) }), env, deps)).status, 400);
        check("a number for text", (await W.handle(post({ message: 5 }), env, deps)).status, 400);
        check("a list", (await W.handle(post([{ message: "hi" }]), env, deps)).status, 400);
        check("too large a body", (await W.handle(post({ message: "hi", report: "y".repeat(W.MAX_BODY) }), env, deps)).status, 413);
        check("a long contact", (await W.handle(post({ message: "hi", contact: "c".repeat(W.MAX_CONTACT + 1) }), env, deps)).status, 400);
        check("nothing reached Telegram", t.calls.length, 0);
    });

    await test("control characters are taken out, line breaks kept", async () => {
        check("clean", W.validate({ message: " a\u0007b\r\nc\u001b[1m " }).message, "ab\nc[1m");
    });

    await test("one a minute from one address", async () => {
        const t = telegram("ok");
        const seen = new Set();
        const limited = async key => { const was = seen.has(key); seen.add(key); return was; };
        check("first", (await W.handle(post({ message: "one" }), env, { fetch: t.fetch, limited })).status, 200);
        check("second", (await W.handle(post({ message: "two" }), env, { fetch: t.fetch, limited })).status, 429);
        check("another address", (await W.handle(post({ message: "three" }, { "CF-Connecting-IP": "198.51.100.4" }), env, { fetch: t.fetch, limited })).status, 200);
        check("Telegram asked twice", t.calls.length, 2);
    });

    await test("Telegram not there, or refusing; the relay not set up", async () => {
        check("down", (await W.handle(post({ message: "hi" }), env, { fetch: telegram("down").fetch, limited: never })).status, 502);
        check("refused", (await W.handle(post({ message: "hi" }), env, { fetch: telegram("refuse").fetch, limited: never })).status, 502);
        const t = telegram("ok");
        const res = await W.handle(post({ message: "hi" }), {}, { fetch: t.fetch, limited: never });
        check("no secrets", res.status, 500);
        check("not sent", t.calls.length, 0);
    });

    if (failed > 0) { console.log(failed + " of " + checked + " checks failed"); process.exit(1); }
    console.log(checked + " checks passed");
})();
