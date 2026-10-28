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
// A turn always free, and one the test counts (as the Worker's counter would, with the rules of
// relay.mjs), with a clock of its own.
const free = async () => ({ ok: true, retryAfter: 0, undo: async () => {} });
function counter(W, limit, clock) {
    const times = {};
    let undone = 0;
    return {
        get undone() { return undone; },
        take: async who => {
            const r = W.slide(times[who] || [], clock.now, limit, W.WINDOW_MS);
            times[who] = r.times;
            const at = clock.now;
            return { ok: r.ok, retryAfter: r.retryAfter, undo: async () => { ++undone; times[who].splice(times[who].lastIndexOf(at), 1); } };
        }
    };
}
// A Durable Object's storage, for the counter's own side.
function storage() {
    const data = {};
    return { data, alarm: 0, async get(k) { return data[k]; }, async put(k, v) { data[k] = v; }, async setAlarm(t) { this.alarm = t; } };
}

(async () => {
    const W = await import(path.join(__dirname, "..", "tools", "feedback-relay", "relay.mjs"));

    await test("the limits are the island's (Feedback.js)", async () => {
        const source = fs.readFileSync(path.join(__dirname, "..", "org.phobby.dynamicisland", "contents", "ui", "Feedback.js"), "utf8");
        for (const name of ["MAX_MESSAGE", "MAX_CONTACT", "MAX_REPORT"])
            check(name, Number((source.match(new RegExp("const " + name + " = (\\d+)")) || [])[1]), W[name]);
        check("three an hour", Number((source.match(/const PER_HOUR = (\d+)/) || [])[1]), W.PER_SENDER);
    });

    await test("a message goes to the chat as plain text", async () => {
        const t = telegram("ok");
        const res = await W.handle(post({ message: "The cat is <b>great</b>", contact: "@someone", island: "0.2.2", language: "tr", session: "Wayland" }), env, { fetch: t.fetch, take: free });
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
        const res = await W.handle(post({ message: "It hides over full screen", report: "Dynamic Island diagnostics\nisland: 0.2.2" }), env, { fetch: t.fetch, take: free });
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
        const deps = { fetch: t.fetch, take: free };
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

    await test("three an hour from one sender, then how long to wait", async () => {
        const clock = { now: Date.UTC(2026, 9, 28, 12, 0, 0) };
        const t = telegram("ok");
        const c = counter(W, W.PER_SENDER, clock);
        const send = async (msg, ip) => W.handle(post({ message: msg }, ip ? { "CF-Connecting-IP": ip } : {}), env, { fetch: t.fetch, take: c.take });
        check("1", (await send("one")).status, 200);
        clock.now += 10 * 60000;
        check("2", (await send("two")).status, 200);
        clock.now += 10 * 60000;
        check("3", (await send("three")).status, 200);
        clock.now += 5 * 60000;
        const fourth = await send("four");
        check("4 is refused", fourth.status, 429);
        // (the first went 25 minutes ago: its hour is over in 35)
        check("Retry-After", fourth.headers.get("Retry-After"), String(35 * 60));
        check("retryAfter", JSON.parse(await fourth.text()).retryAfter, 35 * 60);
        check("another sender meanwhile", (await send("from elsewhere", "198.51.100.4")).status, 200);
        clock.now += 35 * 60000;
        check("an hour after the first, one more", (await send("five")).status, 200);
        check("again full", (await send("six")).status, 429);
        check("Telegram asked five times", t.calls.length, 5);
    });

    await test("a message Telegram did not take is not counted", async () => {
        const clock = { now: 1e12 };
        const c = counter(W, 1, clock);
        check("refused by Telegram", (await W.handle(post({ message: "hi" }), env, { fetch: telegram("refuse").fetch, take: c.take })).status, 502);
        check("given back", c.undone, 1);
        check("so the next one goes", (await W.handle(post({ message: "hi" }), env, { fetch: telegram("ok").fetch, take: c.take })).status, 200);
    });

    await test("no counter, no message", async () => {
        const t = telegram("ok");
        const res = await W.handle(post({ message: "hi" }), env, { fetch: t.fetch, take: async () => ({ ok: false, retryAfter: 0, undo: async () => {} }) });
        check("not set up", res.status, 500);
        check("not sent", t.calls.length, 0);
        const real = await W.take({}, "203.0.113.9");
        check("the Worker's take without LIMITS", real.ok, false);
    });

    await test("the sliding window", async () => {
        const H = W.WINDOW_MS;
        check("empty", W.slide([], 1000, 3, H), { ok: true, times: [1000], retryAfter: 0 });
        check("two before", W.slide([10, 20], 30, 3, H).ok, true);
        check("full", W.slide([10, 20, 30], 40, 3, H), { ok: false, times: [10, 20, 30], retryAfter: Math.ceil((10 + H - 40) / 1000) });
        check("the oldest went out", W.slide([10, 20, 30], 10 + H, 3, H).ok, true);
        check("not a list", W.slide("x", 5, 3, H).ok, true);
        check("from the future: dropped", W.slide([999999999999999], 5, 1, H).ok, true);
    });

    await test("one sender: an address, an IPv6 one by its /64", async () => {
        check("IPv4", W.sender("203.0.113.9"), "203.0.113.9");
        check("IPv6", W.sender("2001:db8:abcd:12:1:2:3:4"), "2001:db8:abcd:12::/64");
        check("IPv6, another in the same block", W.sender("2001:0db8:abcd:0012:ffff::1"), "2001:db8:abcd:12::/64");
        check("IPv6 shortened", W.sender("2001:db8::1"), "2001:db8:0:0::/64");
        check("none", W.sender(""), "unknown");
    });

    await test("the counter: take, refuse with the wait, give back, forget", async () => {
        const st = storage();
        const now = 5e12;
        const take = async (at) => (await W.count(st, "https://feedback-limit/take?limit=2", at)).json();
        const a = await take(now);
        check("first", [a.ok, a.at], [true, now]);
        check("an alarm an hour on", st.alarm, now + W.WINDOW_MS + 1000);
        check("second", (await take(now + 1000)).ok, true);
        const c = await take(now + 2000);
        check("third refused", [c.ok, c.retryAfter], [false, Math.ceil((W.WINDOW_MS - 2000) / 1000)]);
        await W.count(st, "https://feedback-limit/release?at=" + (now + 1000), now + 3000);
        check("given back", st.data.times, [now]);
        check("so one more", (await take(now + 4000)).ok, true);
    });

    await test("the Worker's take: the sender's count, then everybody's", async () => {
        // (a stand-in for env.LIMITS: one storage per name, run through count())
        const names = {};
        let clock = 7e12;
        const LIMITS = {
            idFromName: n => n,
            get: n => ({ fetch: async u => W.count(names[n] = names[n] || storage(), u, clock) })
        };
        const e = { LIMITS, PER_SENDER_HOURLY: "2", TOTAL_HOURLY: "3" };
        check("a 1", (await W.take(e, "a")).ok, true);
        check("a 2", (await W.take(e, "a")).ok, true);
        const a3 = await W.take(e, "a");
        check("a 3: the sender's limit", [a3.ok, a3.retryAfter > 0], [false, true]);
        check("b 1", (await W.take(e, "b")).ok, true);
        const b2 = await W.take(e, "b");
        check("b 2: everybody's limit", [b2.ok, b2.retryAfter > 0], [false, true]);
        check("b's turn given back", names["sender:b"].data.times.length, 1);
        const c1 = await W.take(e, "c");
        check("c: everybody's still full", c1.ok, false);
        clock += W.WINDOW_MS + 1;
        const d = await W.take(e, "d");
        check("an hour later", d.ok, true);
        await d.undo();
        check("undo: both counts", [names["sender:d"].data.times.length, names["total"].data.times.length], [0, 0]);
    });

    await test("Telegram not there, or refusing; the relay not set up", async () => {
        check("down", (await W.handle(post({ message: "hi" }), env, { fetch: telegram("down").fetch, take: free })).status, 502);
        check("refused", (await W.handle(post({ message: "hi" }), env, { fetch: telegram("refuse").fetch, take: free })).status, 502);
        const t = telegram("ok");
        const res = await W.handle(post({ message: "hi" }), {}, { fetch: t.fetch, take: free });
        check("no secrets", res.status, 500);
        check("not sent", t.calls.length, 0);
    });

    if (failed > 0) { console.log(failed + " of " + checked + " checks failed"); process.exit(1); }
    console.log(checked + " checks passed");
})();
