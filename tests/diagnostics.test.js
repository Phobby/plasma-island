#!/usr/bin/env node
// Settings › Diagnostics (contents/ui/Diagnostics.js): what is copied for a bug report leaves out
// the user's name, the computer's name and the home folder; versions are read from what a
// command prints. Run by tools/run-tests.
"use strict";
const fs = require("fs");
const path = require("path");

const UI = path.join(__dirname, "..", "org.phobby.dynamicisland", "contents", "ui");
function load(file) {
    const source = fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*$/m, "");
    const names = Array.from(source.matchAll(/^(?:function|const) (\w+)[ (=]/gm), m => m[1]);
    return new Function(source + "\nreturn { " + names.join(", ") + " };")();
}
const D = load(path.join(UI, "Diagnostics.js"));

let failed = 0, checked = 0;
function check(what, got, want) {
    ++checked;
    const g = JSON.stringify(got), w = JSON.stringify(want);
    if (g === w) return;
    ++failed;
    console.log("    FAILED: " + what + "\n      got  " + g + "\n      want " + w);
}
function test(name, body) {
    const before = failed;
    body();
    console.log((failed === before ? "  ok    " : "  FAIL  ") + name);
}
// (made-up names; none is anybody's)
const who = { user: "quillon", host: "tëstbox-7", home: "/home/quillon" };

test("the home folder, the user and the computer are left out", () => {
    check("home", D.redact("/home/quillon/.local/bin/claude", who), "~/.local/bin/claude");
    check("home alone", D.redact("HOME=/home/quillon", who), "HOME=~");
    check("a longer name is not home", D.redact("/home/quillonx/bin", who), "/home/<user>x/bin".replace("<user>x", "quillonx"));
    check("user in a path elsewhere", D.redact("/run/user/quillon/x", who), "/run/user/<user>/x");
    check("user in any case", D.redact("Quillon@tëstbox-7", who), "<user>@<host>");
    check("host", D.redact("ssh tëstbox-7.local", who), "ssh <host>.local");
    check("not inside other words", D.redact("unquillonable", who), "unquillonable");
    check("short names are left", D.redact("bo at pc", { user: "bo", host: "pc", home: "" }), "bo at pc");
    check("nothing to leave out", D.redact("rclone v1.75", {}), "rclone v1.75");
});

test("the report says what was found, and nothing of who", () => {
    const text = D.report({ island: "0.2.2", plasma: "6.6.6", qt: "6.10.2", session: "Wayland", os: "Kubuntu 26.04", kernel: "7.0", native: true, effects: false },
        [{ id: "claude", state: "found", path: "/home/quillon/.local/bin/claude", via: "folder", version: "2.1.3 (Claude Code)" },
         { id: "rclone", state: "missing", path: "", via: "", given: "/home/quillon/Apps/rclone" }],
        ["/usr/bin", "/home/quillon/.local/bin"], who);
    check("no name left", /quillon|tëstbox/i.test(text), false);
    check("claude", text.includes("- claude: found at ~/.local/bin/claude (in a user folder); 2.1.3 (Claude Code)"), true);
    check("a path given that is not there", text.includes("path set by hand not usable: ~/Apps/rclone"), true);
    check("modules", text.includes("native module: loaded; effects module: not loaded"), true);
    check("searched", text.includes("searched: /usr/bin:~/.local/bin"), true);
});

test("a version from what a command printed", () => {
    check("plain", D.versionOf("rclone v1.75.1\n- os/version: x"), "rclone v1.75.1");
    check("pw-dump prints its path first", D.versionOf("/usr/bin/pw-dump\nCompiled with libpipewire 1.4.7\nLinked with libpipewire 1.4.7"), "Compiled with libpipewire 1.4.7");
    check("terminal colours", D.versionOf("btop version: \u001b[1m1.4.6\u001b[0m"), "btop version: 1.4.6");
    check("nothing", D.versionOf(""), "");
});

console.log(failed === 0 ? `${checked} checks passed` : `${failed} of ${checked} checks FAILED`);
process.exit(failed > 0 ? 1 : 0);
