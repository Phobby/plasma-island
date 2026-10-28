// SPDX-License-Identifier: GPL-2.0-or-later
// Settings › Diagnostics › Feedback (FeedbackForm.qml): what is sent when the user presses Send,
// and what the answer of the feedback address means. The address is a small relay of the
// project's own (tools/feedback-relay), which passes the text on to the author's Telegram; the
// bot's token is kept there, never in the island. Nothing is sent without the button, and at
// most three in an hour: the island counts what it sent, the relay counts what it took (per
// sender, and everybody's together) and answers 429 with how long to wait.
//
// The limits are the relay's too (tools/feedback-relay/worker.js checks the same).
// Pure functions of plain values; tests/feedback.test.js.
.pragma library

const MAX_MESSAGE = 2000;
const MAX_CONTACT = 120;
const MAX_REPORT = 12000;
// At most this many in any hour (the relay's PER_SENDER).
const PER_HOUR = 3;
const HOUR_MS = 60 * 60 * 1000;

// A text as it is sent: no control characters but line breaks and tabs, trimmed, at most `max`.
function clean(text, max) {
    const value = String(text || "").replace(/\r\n?/g, "\n").replace(/[\u0000-\u0008\u000b-\u001f\u007f]/g, "").trim();
    return value.length > max ? value.slice(0, max) : value;
}

// What is sent: { ok, error ("empty" | "long" | ""), body }. `meta` { island, language, session }.
// The diagnostics report only when the user asked for it (it is already without who and where).
function payload(message, contact, withReport, report, meta) {
    const raw = String(message || "").trim();
    if (raw.length === 0) return { ok: false, error: "empty", body: null };
    if (raw.length > MAX_MESSAGE) return { ok: false, error: "long", body: null };
    const m = meta || {};
    const body = {
        message: clean(raw, MAX_MESSAGE),
        contact: clean(contact, MAX_CONTACT),
        report: withReport ? clean(report, MAX_REPORT) : "",
        island: clean(m.island, 32),
        language: clean(m.language, 8),
        session: clean(m.session, 16)
    };
    return { ok: true, error: "", body: body };
}

// The body as the user is shown it before sending, the same text that leaves the computer.
function preview(body) {
    return body ? JSON.stringify(body, null, 2) : "";
}

// What the relay's answer means: "sent", "busy" (asked to wait), "refused" (the text was not
// taken), "failed" (no connection, or the relay or Telegram did not answer as they should).
function outcome(status) {
    const s = Number(status);
    return s === 200 ? "sent" : s === 429 ? "busy" : s === 400 || s === 413 || s === 415 ? "refused" : "failed";
}

// Whether an address can be sent to: https only (a local http address for tests and a relay
// run on this computer).
function usable(url) {
    const u = String(url || "");
    return /^https:\/\/[^\s/]+/.test(u) || /^http:\/\/(127\.0\.0\.1|localhost)(:\d+)?(\/|$)/.test(u);
}

// The times (ms) of what was sent within the hour before `now`, oldest first.
function recent(times, now) {
    return (Array.isArray(times) ? times : []).map(Number).filter(t => t > now - HOUR_MS && t <= now).sort((a, b) => a - b);
}

// How long (ms) until one more may be sent: 0 while fewer than PER_HOUR went in the last hour.
function waitFor(times, now) {
    const r = recent(times, now);
    return r.length < PER_HOUR ? 0 : r[r.length - PER_HOUR] + HOUR_MS - now;
}

// A wait as whole minutes, at least one.
function minutes(ms) {
    return Math.max(1, Math.ceil(Number(ms) / 60000));
}

// How long (ms) the relay asked to wait (its 429 answer: { retryAfter: seconds }); an hour when
// it did not say.
function retryAfter(answer) {
    try {
        const s = Number(JSON.parse(String(answer || "")).retryAfter);
        if (s > 0 && s <= 3600) return s * 1000;
    } catch (e) {}
    return HOUR_MS;
}

// The stored times as a list (they are kept as JSON in the settings window's own file).
function parseTimes(text) {
    try { const v = JSON.parse(String(text || "[]")); return Array.isArray(v) ? v.map(Number).filter(t => t > 0) : []; } catch (e) { return []; }
}
