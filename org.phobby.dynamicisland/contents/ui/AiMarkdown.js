.pragma library
// SPDX-License-Identifier: GPL-2.0-or-later
//
// An answer of the AI tab, made ready to be shown: cut into text and code
// blocks (a code block gets its own box with a Copy button), and the text
// made harmless for Qt's Markdown. No QML in here: tests/ai.test.js runs it
// with node.

// [{ code: false, text } | { code: true, text, lang, open }] in order. A code
// block is what stands between two fence lines (``` or ~~~); `open` = its
// closing fence has not arrived yet (the answer is still being written).
function segments(text) {
    const out = [];
    const lines = String(text === undefined || text === null ? "" : text).replace(/\r\n?/g, "\n").split("\n");
    let buffer = [], fence = "", lang = "";
    const pushText = () => {
        while (buffer.length > 0 && buffer[0].trim().length === 0) buffer.shift();
        while (buffer.length > 0 && buffer[buffer.length - 1].trim().length === 0) buffer.pop();
        if (buffer.length > 0) out.push({ code: false, text: buffer.join("\n") });
        buffer = [];
    };
    const pushCode = open => {
        out.push({ code: true, text: buffer.join("\n"), lang: lang, open: open });
        buffer = [];
    };
    for (const line of lines) {
        const m = /^ {0,3}(`{3,}|~{3,})(.*)$/.exec(line);
        if (fence.length === 0) {
            // (a line of backticks with more backticks after it is no fence)
            if (m && (m[1].charAt(0) === "~" || m[2].indexOf("`") < 0)) {
                pushText();
                fence = m[1];
                lang = m[2].trim().split(/\s+/)[0].replace(/[^A-Za-z0-9+#._-]/g, "").slice(0, 24);
            } else buffer.push(line);
        } else if (m && m[1].charAt(0) === fence.charAt(0) && m[1].length >= fence.length && m[2].trim().length === 0) {
            pushCode(false);
            fence = "";
        } else buffer.push(line);
    }
    if (fence.length > 0) pushCode(true); else pushText();
    return out;
}

// A text segment for a Markdown text item. Two things are taken out, outside
// of inline code (which shows as it is):
//   pictures  "![…](address)" becomes the link "[…](address)". Qt would fetch
//             the address by itself the moment the answer is shown; nothing
//             may be fetched because an answer says so.
//   HTML      "<" is shown as a character, so no tag is ever made of it.
function safe(text) {
    const s = String(text === undefined || text === null ? "" : text);
    let out = "", i = 0;
    const plain = part => part.replace(/!\[/g, "[").replace(/</g, "&lt;");
    while (i < s.length) {
        const start = s.indexOf("`", i);
        if (start < 0) { out += plain(s.slice(i)); break; }
        let run = 1;
        while (s.charAt(start + run) === "`") ++run;
        // the closing run: as many backticks, no more, no fewer
        let close = -1, from = start + run;
        while (from < s.length) {
            const at = s.indexOf("`", from);
            if (at < 0) break;
            let n = 1;
            while (s.charAt(at + n) === "`") ++n;
            if (n === run) { close = at; break; }
            from = at + n;
        }
        out += plain(s.slice(i, start));
        if (close < 0) { out += s.slice(start, start + run); i = start + run; }
        else { out += s.slice(start, close + run); i = close + run; }
    }
    return out;
}

// A link an answer contains may only be opened when it is a web address (and then only after asking).
function webLink(link) {
    const s = String(link || "").trim();
    return /^https?:\/\/[^\s]+$/i.test(s) ? s : "";
}

// The first words of an answer without its Markdown signs, for one line on the island.
function firstLine(text, max) {
    const line = String(text || "").split("\n").map(l => l.trim()).find(l => l.length > 0 && !/^(`{3,}|~{3,})/.test(l)) || "";
    const plain = line.replace(/^#{1,6}\s+/, "").replace(/^[-*+]\s+/, "").replace(/!?\[([^\]]*)\]\([^)]*\)/g, "$1").replace(/[*_`]/g, "").trim();
    return plain.length > max ? plain.slice(0, max - 1).trimEnd() + "…" : plain;
}
