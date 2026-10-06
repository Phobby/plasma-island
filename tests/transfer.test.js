#!/usr/bin/env node
// The transfers' own arithmetic and words (contents/ui/TransferFormat.js): sizes
// in the language's form, times, the smoothed speed, and the table of commands
// the watcher is given. Run by tools/run-tests.
"use strict";
const fs = require("fs");
const path = require("path");

const UI = path.join(__dirname, "..", "org.phobby.dynamicisland", "contents", "ui");
function load(file) {
    const source = fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*$/m, "");
    const names = Array.from(source.matchAll(/^(?:function|const) (\w+)[ (=]/gm), m => m[1]);
    return new Function(source + "\nreturn { " + names.join(", ") + " };")();
}
const F = load(path.join(UI, "TransferFormat.js"));

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

test("sizes, in the language's own form", () => {
    check("bytes", F.bytes(512), "512 B");
    check("MB", F.bytes(412 * 1048576), "412 MB");
    check("GB", F.bytes(1.8 * 1073741824), "1.8 GB");
    check("GB, Turkish", F.bytes(1.8 * 1073741824, true), "1,8 GB");
    check("no decimals from ten up", F.bytes(12.4 * 1048576, true), "12 MB");
    check("never negative", F.bytes(-5), "0 B");
});

test("times", () => {
    check("seconds", F.duration(8), "0:08");
    check("minutes", F.duration(95), "1:35");
    check("hours", F.duration(3725), "1:02:05");
    check("not known", F.duration(-1), "");
    check("remaining", [F.eta(95), F.eta(0), F.eta(Infinity)], ["1:35", "", ""]);
});

test("the smoothed speed", () => {
    check("the first sample as it is", F.smooth(0, 1000), 1000);
    check("then a part of each new one", F.smooth(1000, 2000, 0.3), 1300);
    let v = 0;
    for (const s of [1000, 1000, 9000, 1000, 1000]) v = F.smooth(v, s, 0.3);
    check("one burst does not carry it away", v > 1000 && v < 3000, true);
});

test("the commands that are looked for", () => {
    const all = F.commandTable(true, true, true, "", "");
    check("all of them", all.length, F.COMMANDS.length);
    check("apt only for what downloads", all.find(c => c.name === "apt").actions.includes("list"), false);
    check("git only for clone", all.find(c => c.name === "git").actions, ["clone"]);
    check("kinds switched off", F.commandTable(false, false, true, "", "").some(c => c.kind !== "download"), false);
    check("nothing on", F.commandTable(false, false, false, "rsync", ""), []);
    check("taken out", F.commandTable(true, true, true, "", "apt\nwget").some(c => c.name === "apt" || c.name === "wget"), false);
    const own = F.commandTable(true, true, true, "rsync\n  rclone \nnot a name!\n../../etc\nwget", "");
    check("the user's own, as downloads; only plain names", own.slice(F.COMMANDS.length), [{ name: "rsync", kind: "download", actions: [] }, { name: "rclone", kind: "download", actions: [] }]);
});

test("whose transfer a KDE job is", () => {
    check("a browser's", F.classify({ app: "Firefox", desktopEntry: "firefox" }), "browser");
    check("the phone's", F.classify({ app: "KDE Connect", desktopEntry: "org.kde.kdeconnect" }), "kdeconnect");
    check("a USB drive's", F.classify({ app: "Dolphin", value2: "/media/me/USB DISK/x.bin" }), "removable");
    check("else KIO's", F.classify({ app: "Dolphin", value1: "/home/me/a", value2: "/home/me/b" }), "kio");
});

console.log(failed === 0 ? `${checked} checks passed` : `${failed} of ${checked} checks FAILED`);
process.exit(failed > 0 ? 1 : 0);
