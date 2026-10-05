.pragma library
// SPDX-License-Identifier: GPL-2.0-or-later
//
// Antigravity's command (`agy`) as a plain question-and-answer box: the
// options it is started with, what is written to it and how its answer is
// read. No QML in here: tests/antigravity.test.js runs it with node.
//
// Found by running `agy --help` and trying it (1.2.17):
//
//   -p= --output-format stream-json --input-format stream-json
//                               print mode: one line of JSON with the question
//                               on standard input, lines of JSON while the
//                               answer is made, then the end. (-p wants a value;
//                               the empty one leaves the question to the input.)
//   --sandbox                   its terminal restrictions
//   --disable-slash-commands    no slash commands, no skills
//
// Unlike Claude Code it has no option that takes its tools away: its first
// line always lists them (files, commands, a browser, the web). What keeps
// them unused is seen from outside, in AntigravityProvider.qml. Nor has it
// an option for an instruction of its own or for keeping nothing: the
// island's instruction goes in front of the question, and Antigravity keeps
// every question in its own history.

function commandArguments(model) {
    const list = ["--output-format", "stream-json", "--input-format", "stream-json", "--sandbox", "--disable-slash-commands"];
    if (model && model.length > 0) list.push("--model", model);
    list.push("-p=");
    return list;
}

// "1.2.17" → "1.2.17"
function version(text) {
    const m = /(\d+\.\d+\.\d+)/.exec(String(text || ""));
    return m ? m[1] : "";
}

// `agy models`: a line per model, its id, a tab, its name.
function models(text) {
    const found = [];
    for (const line of String(text || "").split("\n")) {
        const parts = line.split("\t");
        if (parts.length < 2) continue;
        const id = parts[0].trim(), name = parts.slice(1).join(" ").trim();
        if (/^[A-Za-z0-9][A-Za-z0-9._:\/-]*$/.test(id) && !found.some(m => m.id === id)) found.push({ id: id, name: name.length > 0 ? name : id });
    }
    return found;
}

// The line written to the command: the island's instruction, the earlier
// messages of a follow-up (the command is started anew for every question),
// then the question.
function input(messages, system) {
    let text = system && system.length > 0 ? "<instructions>\n" + system + "\n</instructions>\n\n" : "";
    if (messages.length > 0) {
        const last = messages[messages.length - 1];
        if (messages.length > 1) {
            text += "The conversation so far, oldest first:\n\n";
            for (const m of messages.slice(0, -1)) text += "<message role=\"" + m.role + "\">\n" + m.text + "\n</message>\n";
            text += "\nReply to this new message from the user:\n\n<message role=\"user\">\n" + last.text + "\n</message>";
        } else {
            text += last.text;
        }
    }
    return JSON.stringify({ event: "user", message: { content: text } }) + "\n";
}

// One line of the command's output → what it means here, each key only when it is there:
//   init    { mode, cwd }      before anything is asked of the model
//   text    a piece of the answer
//   tool    the name of a tool the model reached for
//   result  { ok, text, error, denials }
function event(line) {
    let o;
    try { o = JSON.parse(line); } catch (e) { return {}; }
    if (o === null || typeof o !== "object") return {};
    if (o.event === "init" && o.init) return { init: { mode: String(o.init.permission_mode || ""), cwd: typeof o.init.cwd === "string" ? o.init.cwd : "" } };
    if (o.event === "step_update" && o.step_update) {
        const step = o.step_update, type = String(step.step_type || "");
        if (type === "user_input") return {};
        if (type === "agent_response") return typeof step.text_delta === "string" && step.text_delta.length > 0 ? { text: step.text_delta } : {};
        if (/think|reason/i.test(type)) return {};
        // a tool, or a kind of step this file does not know: not a text answer either way
        return { tool: String(step.tool_name || type || "step") };
    }
    if (o.event === "result" && o.result) {
        const r = o.result;
        return { result: { ok: r.status === "SUCCESS", text: typeof r.response === "string" ? r.response : "", error: String(r.error || ""),
                           denials: Array.isArray(r.denied_actions) ? r.denied_actions.length : 0 } };
    }
    return {};
}

function signedOut(text) { return /not authenticated|unauthenticated|not (logged|signed) in|sign in|log ?in required|invalid credentials/i.test(text); }

// A result that is an error → { kind, detail } (the kinds of AiStream.js).
function failure(result) {
    const text = String(result.error || result.text || "").replace(/\s+/g, " ").trim().slice(0, 300);
    if (signedOut(text)) return { kind: "auth", detail: "" };
    if (result.denials > 0) return { kind: "tools", detail: "" };
    if (/quota|rate limit|resource.?exhausted|too many requests|\b429\b/i.test(text)) return { kind: "limit", detail: text };
    if (/model/i.test(text) && /not found|unknown|invalid|unsupported|not available/i.test(text)) return { kind: "model", detail: text };
    if (/unavailable|internal error|overloaded|\b50\d\b/i.test(text)) return { kind: "server", detail: text };
    return { kind: "unknown", detail: text };
}

// The command ended without a result: why, from its exit code and what it wrote to standard error.
function exitFailure(exitCode, errorOutput) {
    const first = String(errorOutput || "").split("\n").map(l => l.trim()).find(l => l.length > 0) || "";
    if (/flag provided but not defined|unknown flag|flag needs an argument|invalid value/i.test(first)) return { kind: "version", detail: first.slice(0, 200) };
    if (signedOut(first)) return { kind: "auth", detail: "" };
    if (exitCode < 0 && first.length === 0) return { kind: "missing", detail: "" };
    return { kind: "unknown", detail: first.slice(0, 200) };
}
