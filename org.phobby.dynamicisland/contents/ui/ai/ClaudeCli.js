.pragma library
// SPDX-License-Identifier: GPL-2.0-or-later
//
// Claude Code as a plain question-and-answer box: the options it is started
// with, what is written to it and how its answer is read. No QML in here:
// tests/ai.test.js runs it with node.
//
// The options were found by running `claude --help` and trying them (2.1.289);
// what each one is for, and what was seen without it:
//
//   -p --output-format stream-json --verbose --include-partial-messages
//                               one answer, then exit; written as lines of JSON
//                               while it is made
//   --tools ""                  none of the built-in tools (files, commands, web,
//                               sub-agents, notebooks…)
//   --strict-mcp-config         no MCP servers either (none is named): without
//                               it the user's own stay, `--tools ""` or not
//   --setting-sources ""        the user's, the project's and the local settings
//   --safe-mode                 are not read: no hooks, no CLAUDE.md of the
//                               folder, of a folder above it or of the user, no
//                               skills, plugins, own commands or agents
//   --restricted                the command and web tools stay off even if
//                               something names them; no bypassing of permissions
//   --disable-slash-commands    no skills
//   --permission-mode dontAsk   what would ask for a permission is refused,
//   --permission-prompts none   never allowed; there is nobody to ask
//   --max-turns 1               the answer, then the end. (Not in --help, but
//                               taken. Not a guard by itself: with a tool
//                               allowed, one call ran before the limit ended it.)
//   --no-session-persistence    nothing of the chat is written to ~/.claude
//   --system-prompt …           the island's own instruction instead of the
//                               coding assistant's
//
// `--bare` would also do most of this but does not use the subscription
// sign-in ("Not logged in"), so it cannot be used.

const SAFETY = ["--tools", "", "--strict-mcp-config", "--setting-sources", "", "--safe-mode", "--restricted",
                "--disable-slash-commands", "--permission-mode", "dontAsk", "--permission-prompts", "none",
                "--max-turns", "1", "--no-session-persistence"];

// The arguments of one question. Nothing the user wrote is among them: the
// question goes to standard input.
function commandArguments(model, system) {
    const list = ["-p", "--output-format", "stream-json", "--verbose", "--include-partial-messages"].concat(SAFETY);
    list.push("--system-prompt", system);
    if (model && model.length > 0) list.push("--model", model);
    return list;
}

// "2.1.289 (Claude Code)" → "2.1.289"
function version(text) {
    const m = /(\d+\.\d+\.\d+)/.exec(String(text || ""));
    return m ? m[1] : "";
}

// The names `claude --help` gives as examples for --model ("an alias for the
// latest model (e.g. 'fable', 'opus', or 'sonnet')"): the list is the
// command's own, never one written down here.
function aliases(help) {
    const lines = String(help || "").split("\n");
    const start = lines.findIndex(l => /^\s+--model\b/.test(l));
    if (start < 0) return [];
    let text = lines[start];
    for (let i = start + 1; i < lines.length && !/^\s+-{1,2}[A-Za-z]/.test(lines[i]) && lines[i].trim().length > 0; ++i) text += " " + lines[i];
    const sentence = text.split(/\bor a model's full name\b/i)[0];
    const found = [];
    const quoted = /'([a-z][a-z0-9.-]{1,40})'/g;
    let m;
    while ((m = quoted.exec(sentence)) !== null) if (found.indexOf(m[1]) < 0) found.push(m[1]);
    return found;
}

// What is written to the command. One question goes as it is. A follow-up
// carries the earlier messages with it: nothing of a chat is kept by the
// command (see --no-session-persistence), so it is told again each time.
function transcript(messages) {
    if (messages.length === 0) return "";
    const last = messages[messages.length - 1];
    if (messages.length === 1) return last.text;
    let text = "The conversation so far, oldest first:\n\n";
    for (const m of messages.slice(0, -1)) text += "<message role=\"" + m.role + "\">\n" + m.text + "\n</message>\n";
    return text + "\nReply to this new message from the user:\n\n<message role=\"user\">\n" + last.text + "\n</message>";
}

// One line of the command's output → what it means here, each key only when it is there:
//   init    { tools: [names], servers: [names], cwd }   before anything is asked of the model
//   text    a piece of the answer
//   whole   the text of a finished message (for a command that sends no pieces)
//   tool    the name of a tool the model reached for (must never happen)
//   limited the usage limit was hit
//   result  { ok, text, status, subtype, denials }
function event(line) {
    let o;
    try { o = JSON.parse(line); } catch (e) { return {}; }
    if (o === null || typeof o !== "object") return {};
    const quiet = type => type === "text" || type === "thinking" || type === "redacted_thinking";
    if (o.type === "system" && o.subtype === "init") {
        return { init: { tools: Array.isArray(o.tools) ? o.tools.map(String) : [],
                         servers: Array.isArray(o.mcp_servers) ? o.mcp_servers.map(s => String(s && s.name !== undefined ? s.name : s)) : [],
                         cwd: typeof o.cwd === "string" ? o.cwd : "" } };
    }
    if (o.type === "stream_event" && o.event) {
        const e = o.event;
        if (e.type === "content_block_start" && e.content_block && !quiet(e.content_block.type))
            return { tool: String(e.content_block.name || e.content_block.type) };
        if (e.type === "content_block_delta" && e.delta && e.delta.type === "text_delta" && typeof e.delta.text === "string" && e.delta.text.length > 0)
            return { text: e.delta.text };
        return {};
    }
    if (o.type === "assistant" && o.message && Array.isArray(o.message.content)) {
        const other = o.message.content.find(b => b && !quiet(b.type));
        if (other) return { tool: String(other.name || other.type) };
        return { whole: o.message.content.filter(b => b.type === "text" && typeof b.text === "string").map(b => b.text).join("") };
    }
    // a tool's result on its way back to the model
    if (o.type === "user" && o.message && Array.isArray(o.message.content) && o.message.content.some(b => b && b.type === "tool_result"))
        return { tool: "tool_result" };
    if (o.type === "rate_limit_event" && o.rate_limit_info && o.rate_limit_info.status === "rejected") return { limited: true };
    if (o.type === "result") {
        return { result: { ok: o.is_error !== true, text: typeof o.result === "string" ? o.result : "", status: Number(o.api_error_status) || 0,
                           subtype: String(o.subtype || ""), denials: Array.isArray(o.permission_denials) ? o.permission_denials.length : 0 } };
    }
    return {};
}

// A result that is an error → { kind, detail } (the kinds of AiStream.js).
function failure(result, limited) {
    const text = String(result.text || "").replace(/\s+/g, " ").trim().slice(0, 300);
    if (/not logged in|\/login\b|invalid api key|authentication/i.test(text) || result.status === 401 || result.status === 403) return { kind: "auth", detail: "" };
    if (result.subtype === "error_max_turns" || result.denials > 0) return { kind: "tools", detail: "" };
    if (limited || result.status === 429 || /\b(usage|rate) limit|limit (reached|exceeded)|hit your limit/i.test(text)) return { kind: "limit", detail: text };
    if (result.status === 404) return { kind: "model", detail: text };
    if (result.status >= 500) return { kind: "server", detail: text };
    return { kind: "unknown", detail: text };
}

// The command ended without a result: why, from its exit code and what it wrote to standard error.
function exitFailure(exitCode, errorOutput) {
    const first = String(errorOutput || "").split("\n").map(l => l.trim()).find(l => l.length > 0) || "";
    if (/unknown option|unknown argument|invalid (option|choice)|not allowed with/i.test(first)) return { kind: "version", detail: first.slice(0, 200) };
    if (exitCode < 0 && first.length === 0) return { kind: "missing", detail: "" };
    return { kind: "unknown", detail: first.slice(0, 200) };
}
