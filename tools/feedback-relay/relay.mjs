// SPDX-License-Identifier: GPL-2.0-or-later
// feedback-relay's rules (worker.mjs is what Cloudflare runs). Where the island's Settings ›
// Diagnostics › Feedback is sent: a Cloudflare Worker that takes the few lines a user wrote and
// passes them on to the author's Telegram chat.
// The bot's token and the chat's id are this Worker's secrets (BOT_TOKEN, CHAT_ID): they are
// never in the island, which is public and could not keep them.
//
// It takes one thing: POST / with a JSON body { message, contact, report, island, language,
// session } (contents/ui/Feedback.js makes it; the limits are the same). It answers 200 when
// Telegram took it, 429 with `retryAfter` (seconds, also as Retry-After) when the sender has
// sent three in the last hour or everybody together twenty (PER_SENDER, TOTAL; the Worker's vars
// PER_SENDER_HOURLY and TOTAL_HOURLY change them), 400/413/415 when the body is not what it
// should be, 502 when Telegram did not take it (that one is not counted), 500 when the secrets
// or the counter are not set up. The text is sent as plain text (no markup is read in it), the
// report as a file beside it. Nothing of the text is kept; the counter keeps only the times of
// the last hour's messages, per sender.
//
// Setup: tools/feedback-relay/README.md. Tests: tests/feedbackrelay.test.js.
// (Kept apart from worker.mjs: Cloudflare's runtime takes every export of the main module for a
// handler of its own, and refuses to start on a constant.)

export const MAX_MESSAGE = 2000;
export const MAX_CONTACT = 120;
export const MAX_REPORT = 12000;
export const MAX_BODY = 32 * 1024;
const META = { island: 32, language: 8, session: 16 };
// At most this many messages in any hour: from one sender, and from everybody together.
export const PER_SENDER = 3;
export const TOTAL = 20;
export const WINDOW_MS = 60 * 60 * 1000;

function answer(status, error, retryAfter) {
    const headers = { "Content-Type": "application/json" };
    const body = error ? { ok: false, error } : { ok: true };
    if (retryAfter > 0) { body.retryAfter = retryAfter; headers["Retry-After"] = String(retryAfter); }
    return new Response(JSON.stringify(body), { status, headers });
}

// A sliding window: `times` (ms) of what was taken; whether one more fits at `now`, the times to
// keep, and in how many seconds the next one would fit when it does not.
export function slide(times, now, limit, windowMs) {
    const kept = (Array.isArray(times) ? times : []).filter(t => typeof t === "number" && t > now - windowMs && t <= now).sort((a, b) => a - b);
    if (kept.length < limit) return { ok: true, times: kept.concat([now]), retryAfter: 0 };
    return { ok: false, times: kept, retryAfter: Math.max(1, Math.ceil((kept[kept.length - limit] + windowMs - now) / 1000)) };
}

// Who is counted as one sender: the address, an IPv6 one by its /64 (one line's own block, which
// a sender could otherwise walk through).
export function sender(ip) {
    const a = String(ip || "").trim().toLowerCase();
    if (!a.includes(":")) return a || "unknown";
    let parts = a.split("::");
    const head = parts[0] ? parts[0].split(":") : [];
    const tail = parts.length > 1 && parts[1] ? parts[1].split(":") : [];
    const full = parts.length > 1 ? head.concat(Array(Math.max(0, 8 - head.length - tail.length)).fill("0"), tail) : head;
    return full.slice(0, 4).map(h => (h || "0").replace(/^0+(?=.)/, "")).join(":") + "::/64";
}

// The body as it may be sent on, or null.
export function validate(data) {
    if (!data || typeof data !== "object" || Array.isArray(data)) return null;
    const out = {};
    const fields = Object.assign({ message: MAX_MESSAGE, contact: MAX_CONTACT, report: MAX_REPORT }, META);
    for (const [key, max] of Object.entries(fields)) {
        const value = data[key] === undefined ? "" : data[key];
        if (typeof value !== "string") return null;
        const clean = value.replace(/\r\n?/g, "\n").replace(/[\u0000-\u0008\u000b-\u001f\u007f]/g, "").trim();
        if (clean.length > max) return null;
        out[key] = clean;
    }
    return out.message.length > 0 ? out : null;
}

// The message as it shows in the chat.
export function text(v) {
    const about = [v.island && "island " + v.island, v.language, v.session].filter(Boolean).join(" · ");
    const lines = ["Dynamic Island feedback"];
    if (about) lines.push(about);
    if (v.contact) lines.push("answer to: " + v.contact);
    lines.push("", v.message);
    return lines.join("\n");
}

// `deps`: { fetch, take(sender) → Promise<{ ok, retryAfter, undo() }> } (ok false with
// retryAfter 0: the counter is not there), so that the tests hand in their own.
export async function handle(request, env, deps) {
    const url = new URL(request.url);
    if (url.pathname !== "/") return answer(404, "not found");
    if (request.method !== "POST") return answer(405, "POST only");
    if (!env || !env.BOT_TOKEN || !env.CHAT_ID) return answer(500, "not set up");
    if (!String(request.headers.get("Content-Type") || "").toLowerCase().startsWith("application/json")) return answer(415, "JSON only");
    const declared = Number(request.headers.get("Content-Length") || 0);
    if (declared > MAX_BODY) return answer(413, "too large");
    const raw = await request.text();
    if (raw.length > MAX_BODY) return answer(413, "too large");
    let data = null;
    try { data = JSON.parse(raw); } catch (e) { return answer(400, "not JSON"); }
    const v = validate(data);
    if (v === null) return answer(400, "not as expected");

    const turn = await deps.take(sender(request.headers.get("CF-Connecting-IP")));
    if (!turn.ok) return turn.retryAfter > 0 ? answer(429, "too many this hour", turn.retryAfter) : answer(500, "not set up");

    const api = (env.TELEGRAM_API || "https://api.telegram.org") + "/bot" + env.BOT_TOKEN;
    let sent;
    try {
        sent = await deps.fetch(api + "/sendMessage", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ chat_id: env.CHAT_ID, text: text(v), link_preview_options: { is_disabled: true } })
        });
    } catch (e) { await turn.undo(); return answer(502, "Telegram could not be reached"); }
    if (!sent.ok) { await turn.undo(); return answer(502, "Telegram did not take it"); }
    if (v.report) {
        let replyTo = 0;
        try { replyTo = Number((await sent.json()).result.message_id) || 0; } catch (e) {}
        const form = new FormData();
        form.append("chat_id", String(env.CHAT_ID));
        form.append("caption", "Diagnostics of the feedback above");
        if (replyTo > 0) form.append("reply_parameters", JSON.stringify({ message_id: replyTo }));
        form.append("document", new Blob([v.report], { type: "text/plain" }), "diagnostics.txt");
        // (the message is there already: a report that did not follow does not undo it)
        try { await deps.fetch(api + "/sendDocument", { method: "POST", body: form }); } catch (e) {}
    }
    return answer(200, null);
}

// The counter's side (worker.mjs, class FeedbackLimit, one per name): `/take?limit=n` takes a
// turn if one is free and says when the next one will be; `/release?at=t` gives one back.
// `storage`: { get, put, setAlarm } of a Durable Object.
export async function count(storage, address, now) {
    const url = new URL(address);
    const times = (await storage.get("times")) || [];
    if (url.pathname === "/release") {
        const i = times.lastIndexOf(Number(url.searchParams.get("at")));
        if (i >= 0) { times.splice(i, 1); await storage.put("times", times); }
        return Response.json({ ok: true });
    }
    const r = slide(times, now, Number(url.searchParams.get("limit")) || 1, WINDOW_MS);
    if (r.ok) {
        await storage.put("times", r.times);
        await storage.setAlarm(now + WINDOW_MS + 1000);
    }
    return Response.json({ ok: r.ok, retryAfter: r.retryAfter, at: r.ok ? now : 0 });
}

async function ask(env, name, path) {
    const stub = env.LIMITS.get(env.LIMITS.idFromName(name));
    return (await stub.fetch("https://feedback-limit" + path)).json();
}

// A turn for a sender (the Worker's side of `deps.take`): from the sender's count, then from
// everybody's; given back when everybody's count was full, or (`undo`) when Telegram did not take
// the message. Without the counter (env.LIMITS) there is no turn: the relay answers 500.
export async function take(env, who) {
    const none = async () => {};
    if (!env || !env.LIMITS) return { ok: false, retryAfter: 0, undo: none };
    const own = "sender:" + who;
    const a = await ask(env, own, "/take?limit=" + (Number(env.PER_SENDER_HOURLY) || PER_SENDER));
    if (!a.ok) return { ok: false, retryAfter: a.retryAfter, undo: none };
    const b = await ask(env, "total", "/take?limit=" + (Number(env.TOTAL_HOURLY) || TOTAL));
    if (!b.ok) {
        await ask(env, own, "/release?at=" + a.at);
        return { ok: false, retryAfter: b.retryAfter, undo: none };
    }
    return { ok: true, retryAfter: 0, undo: async () => { await ask(env, own, "/release?at=" + a.at); await ask(env, "total", "/release?at=" + b.at); } };
}
