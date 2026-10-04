.pragma library
// SPDX-License-Identifier: GPL-2.0-or-later
//
// What the AI tab's network providers read: an answer that is written piece by
// piece (server-sent events) by an OpenAI-compatible server or by the
// Anthropic API, and what went wrong in words every provider shares. No QML,
// no network in here: tests/ai.test.js runs it with node.

// ---- what went wrong ------------------------------------------------------------
// One vocabulary for every provider (AiBackend.problemText turns it into a sentence):
//   auth     the key or sign-in was not accepted        limit    a rate or usage limit, or billing
//   network  no connection, or it was cut               timeout  no answer in time
//   model    the model (or the address) was not found   server   the service itself failed
//   refused  the model declined to answer               tools    Claude Code tried to use a tool
//   version  Claude Code does not take the safety options    missing  the command is gone
//   unknown  anything else (`detail` says what the service said)
function problem(kind, detail) {
    return { kind: kind, detail: String(detail === undefined || detail === null ? "" : detail).replace(/\s+/g, " ").trim().slice(0, 300) };
}

// The message of a service's error body: { error: { message } }, { error: "…" },
// { message }, or the same inside a list (Gemini). "" when it is no JSON (an HTML page is never shown).
function errorMessage(body) {
    let o;
    try { o = JSON.parse(body); } catch (e) { return ""; }
    if (Array.isArray(o)) o = o[0];
    if (o === null || typeof o !== "object") return "";
    const e = o.error !== undefined && o.error !== null ? o.error : o;
    if (typeof e === "string") return e;
    return typeof e.message === "string" ? e.message : typeof e.detail === "string" ? e.detail : "";
}

// An HTTP answer that is not the stream: status 0 = no connection.
function httpProblem(status, body) {
    const message = errorMessage(body || "");
    if (status === 0) return problem("network", "");
    if (status === 401 || status === 403) return problem("auth", message);
    // (Gemini answers a wrong key with 400)
    if (status === 400 && /api[ _-]?key|authenticat|credential|unauthori[sz]ed/i.test(message)) return problem("auth", message);
    if (status === 402 || status === 429) return problem("limit", message);
    if (status === 404) return problem("model", message);
    if (status === 408 || status === 504) return problem("timeout", message);
    if (status >= 500) return problem("server", message);
    return problem("unknown", message.length > 0 ? message : "HTTP " + status);
}

// The Anthropic API names its errors (also inside a stream).
function anthropicProblem(type, message) {
    const kinds = { authentication_error: "auth", permission_error: "auth", rate_limit_error: "limit", billing_error: "limit",
                    not_found_error: "model", overloaded_error: "server", api_error: "server", timeout_error: "timeout" };
    return problem(kinds[type] || "unknown", message);
}

// `text` without the secret (a key must never show in a message).
function scrub(text, secret) {
    const s = String(text || "");
    return secret && secret.length > 0 ? s.split(secret).join("…") : s;
}

// ---- server-sent events ---------------------------------------------------------
// XMLHttpRequest hands over everything received so far, again and again:
// the reader remembers how far it has read and only takes whole lines, so a
// character that arrived in two halves is never read half.
function reader() {
    return { at: 0, event: "", data: [] };
}
// The events completed since the last call: [{ event, data }].
function events(state, text) {
    const out = [];
    let end;
    while ((end = text.indexOf("\n", state.at)) >= 0) {
        let line = text.slice(state.at, end);
        state.at = end + 1;
        if (line.charAt(line.length - 1) === "\r") line = line.slice(0, -1);
        if (line.length === 0) {                        // an empty line ends an event
            if (state.data.length > 0) out.push({ event: state.event, data: state.data.join("\n") });
            state.event = "";
            state.data = [];
            continue;
        }
        if (line.charAt(0) === ":") continue;           // a comment (keep-alive)
        const colon = line.indexOf(":");
        const field = colon < 0 ? line : line.slice(0, colon);
        let value = colon < 0 ? "" : line.slice(colon + 1);
        if (value.charAt(0) === " ") value = value.slice(1);
        if (field === "event") state.event = value;
        else if (field === "data") state.data.push(value);
    }
    return out;
}

// ---- OpenAI-compatible chat completions -------------------------------------------
// One event's data → { text, finish, done, problem }, each only when it is there.
// finish: "stop" | "length" (cut off at the limit) | "content_filter" | …
function openAiEvent(data) {
    if (data.trim() === "[DONE]") return { done: true };
    let o;
    try { o = JSON.parse(data); } catch (e) { return {}; }
    if (o === null || typeof o !== "object") return {};
    if (o.error !== undefined && o.error !== null) {
        const code = Number(typeof o.error === "object" ? o.error.code : 0) || 0;
        const p = httpProblem(code >= 400 ? code : 500, data);
        return { problem: p };
    }
    const choice = Array.isArray(o.choices) ? o.choices[0] : null;
    if (!choice) return {};
    const out = {};
    const delta = choice.delta || choice.message || {};
    // (what a model thinks, `reasoning` / `reasoning_content`, is not shown)
    if (typeof delta.content === "string") {
        if (delta.content.length > 0) out.text = delta.content;
    } else if (Array.isArray(delta.content)) {
        const text = delta.content.map(part => part && typeof part.text === "string" ? part.text : "").join("");
        if (text.length > 0) out.text = text;
    }
    if (typeof choice.finish_reason === "string" && choice.finish_reason.length > 0) out.finish = choice.finish_reason;
    return out;
}

// What is sent: the system prompt first, then the conversation.
function openAiBody(model, system, messages, limit, limitField) {
    const body = { model: model, stream: true, messages: [] };
    if (system.length > 0) body.messages.push({ role: "system", content: system });
    for (const m of messages) body.messages.push({ role: m.role, content: m.text });
    if (limit > 0) body[limitField || "max_tokens"] = limit;
    return body;
}
// A service that knows the length limit under its newer name says so in its error.
function wantsNewLimitField(status, body) {
    return status === 400 && /max_completion_tokens/.test(errorMessage(body || ""));
}

// The models of GET /models: [{ id, name }], sorted by id.
function openAiModels(body) {
    let o;
    try { o = JSON.parse(body); } catch (e) { return []; }
    const list = o && Array.isArray(o.data) ? o.data : Array.isArray(o) ? o : [];
    return list.filter(m => m && typeof m.id === "string" && m.id.length > 0)
               .map(m => ({ id: m.id, name: m.id }))
               .sort((a, b) => a.id < b.id ? -1 : a.id > b.id ? 1 : 0);
}

// ---- the Anthropic API ------------------------------------------------------------
// One event's data → { text, stop, done, problem }. Only text is taken; what
// the model thinks (thinking blocks) is not shown, and no tools are ever sent.
// stop: "end_turn" | "max_tokens" (cut off) | "refusal" | …
function anthropicEvent(data) {
    let o;
    try { o = JSON.parse(data); } catch (e) { return {}; }
    if (o === null || typeof o !== "object") return {};
    if (o.type === "content_block_delta" && o.delta && o.delta.type === "text_delta" && typeof o.delta.text === "string")
        return o.delta.text.length > 0 ? { text: o.delta.text } : {};
    if (o.type === "message_delta" && o.delta && typeof o.delta.stop_reason === "string") return { stop: o.delta.stop_reason };
    if (o.type === "message_stop") return { done: true };
    if (o.type === "error") return { problem: anthropicProblem(o.error ? o.error.type : "", o.error ? o.error.message : "") };
    return {};
}

function anthropicBody(model, system, messages, limit) {
    const body = { model: model, max_tokens: limit, stream: true, messages: messages.map(m => ({ role: m.role, content: m.text })) };
    if (system.length > 0) body.system = system;
    return body;
}

// The models of GET /v1/models (newest first, as the service lists them): [{ id, name }].
function anthropicModels(body) {
    let o;
    try { o = JSON.parse(body); } catch (e) { return []; }
    const list = o && Array.isArray(o.data) ? o.data : [];
    return list.filter(m => m && typeof m.id === "string" && m.id.length > 0)
               .map(m => ({ id: m.id, name: typeof m.display_name === "string" && m.display_name.length > 0 ? m.display_name : m.id }));
}

// ---- addresses ----------------------------------------------------------------------
// "http://localhost:11434/v1/" → { ok, scheme, host, base ("http://localhost:11434/v1") }
function address(text) {
    const m = /^(https?):\/\/(\[[0-9a-fA-F:.]+\]|[^\s\/:?#@]+)(:\d{1,5})?(\/[^\s?#]*)?$/i.exec(String(text || "").trim());
    if (!m) return { ok: false, scheme: "", host: "", base: "" };
    const path = (m[4] || "").replace(/\/+$/, "");
    return { ok: true, scheme: m[1].toLowerCase(), host: m[2].toLowerCase(), base: m[1].toLowerCase() + "://" + m[2] + (m[3] || "") + path };
}
// This computer itself: what is sent there does not leave it.
function isThisDevice(host) {
    const h = String(host || "").toLowerCase();
    return h === "localhost" || h === "[::1]" || /^127(\.\d{1,3}){3}$/.test(h);
}
