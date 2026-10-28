// SPDX-License-Identifier: GPL-2.0-or-later
// feedback-relay's rules (worker.mjs is what Cloudflare runs). Where the island's Settings ›
// Diagnostics › Feedback is sent: a Cloudflare Worker that takes the few lines a user wrote and
// passes them on to the author's Telegram chat.
// The bot's token and the chat's id are this Worker's secrets (BOT_TOKEN, CHAT_ID): they are
// never in the island, which is public and could not keep them.
//
// It takes one thing: POST / with a JSON body { message, contact, report, island, language,
// session } (contents/ui/Feedback.js makes it; the limits are the same). It answers 200 when
// Telegram took it, 429 when the same address sent one a moment ago, 400/413/415 when the body
// is not what it should be, 502 when Telegram did not take it, 500 when the secrets are not set.
// The text is sent as plain text (no markup is read in it), the report as a file beside it.
// Nothing is kept: no log of the text, no store.
//
// Setup: tools/feedback-relay/README.md. Tests: tests/feedbackrelay.test.js.
// (Kept apart from worker.mjs: Cloudflare's runtime takes every export of the main module for a
// handler of its own, and refuses to start on a constant.)

export const MAX_MESSAGE = 2000;
export const MAX_CONTACT = 120;
export const MAX_REPORT = 12000;
export const MAX_BODY = 32 * 1024;
const META = { island: 32, language: 8, session: 16 };

function answer(status, error) {
    return new Response(JSON.stringify(error ? { ok: false, error } : { ok: true }),
                        { status, headers: { "Content-Type": "application/json" } });
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

// `deps`: { fetch, limited(key) → Promise<bool> }, so that the tests hand in their own.
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

    const who = request.headers.get("CF-Connecting-IP") || "unknown";
    if (await deps.limited(who)) return answer(429, "wait a minute");

    const api = (env.TELEGRAM_API || "https://api.telegram.org") + "/bot" + env.BOT_TOKEN;
    let sent;
    try {
        sent = await deps.fetch(api + "/sendMessage", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ chat_id: env.CHAT_ID, text: text(v), link_preview_options: { is_disabled: true } })
        });
    } catch (e) { return answer(502, "Telegram could not be reached"); }
    if (!sent.ok) return answer(502, "Telegram did not take it");
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
