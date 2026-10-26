// SPDX-License-Identifier: GPL-2.0-or-later
// The Diagnostics page's report (configDiagnostics.qml): what was found, as text to paste into a
// bug report, with what says who and where the user is left out.
//
// Pure functions of plain values; tests/diagnostics.test.js.
.pragma library

function escaped(text) {
    return String(text).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

// The text with the home folder written as "~", the user's name as "<user>" and the computer's
// name as "<host>" (also inside paths and addresses, in any case). Names shorter than three
// letters are left as they are: they would replace parts of ordinary words.
function redact(text, who) {
    let out = String(text || "");
    const home = String(who && who.home || "").replace(/\/+$/, "");
    if (home.length > 1) out = out.replace(new RegExp(escaped(home) + "(?=/|\\b|$)", "g"), "~");
    for (const [name, mark] of [[who && who.host, "<host>"], [who && who.user, "<user>"]]) {
        const value = String(name || "");
        if (value.length < 3) continue;
        out = out.replace(new RegExp("(^|[^A-Za-z0-9])" + escaped(value) + "(?=$|[^A-Za-z0-9])", "gi"), (m, before) => before + mark);
    }
    return out;
}

// How a command was found, in words for the report (the page translates its own).
function viaText(via) {
    return via === "setting" ? "path set by hand" : via === "path" ? "on PATH" : via === "folder" ? "in a user folder"
         : via === "appimage" ? "AppImage" : "";
}

// The report: `info` { island, plasma, qt, session, os, kernel, native, effects }, `rows` [{ id, name,
// state ("found", "missing", "unknown"), path, via, version, given }], `searched` [folders].
function report(info, rows, searched, who) {
    const lines = [];
    lines.push("Dynamic Island diagnostics");
    lines.push("island: " + (info.island || "?") + "; plasma: " + (info.plasma || "?") + "; qt: " + (info.qt || "?"));
    lines.push("session: " + (info.session || "?") + "; os: " + (info.os || "?") + "; kernel: " + (info.kernel || "?"));
    lines.push("native module: " + (info.native ? "loaded" : "not loaded") + "; effects module: " + (info.effects ? "loaded" : "not loaded"));
    lines.push("");
    for (const r of rows) {
        let line = "- " + r.id + ": " + r.state;
        if (r.path) line += " at " + r.path;
        if (r.via) line += " (" + viaText(r.via) + ")";
        if (r.version) line += "; " + r.version;
        if (r.given && r.state !== "found") line += "; path set by hand not usable: " + r.given;
        lines.push(line);
    }
    if (searched && searched.length > 0) {
        lines.push("");
        lines.push("searched: " + searched.join(":"));
    }
    return redact(lines.join("\n"), who);
}

// The first line of what `--version` printed that has a number in it (pw-dump prints its own path
// first), without a terminal's colours, short.
function versionOf(out) {
    const lines = String(out || "").replace(/\x1b\[[0-9;]*[A-Za-z]/g, "").split("\n").map(l => l.trim()).filter(l => l.length > 0);
    const line = lines.find(l => /\d/.test(l) && !/^\//.test(l)) || lines[0] || "";
    return line.length > 80 ? line.slice(0, 80) + "…" : line;
}
