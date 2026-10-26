#!/usr/bin/env node
// Over a window that fills the screen (contents/ui/Fullscreen.js): which windows count, on
// which screen, a window reaching under the notch, and what the strip at the edge says
// (an incoming call first, and only that opens the island). Run by tools/run-tests.
"use strict";
const fs = require("fs");
const path = require("path");

const UI = path.join(__dirname, "..", "org.phobby.dynamicisland", "contents", "ui");
function load(file) {
    const source = fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*$/m, "");
    const names = Array.from(source.matchAll(/^(?:function|const) (\w+)[ (=]/gm), m => m[1]);
    return new Function(source + "\nreturn { " + names.join(", ") + " };")();
}
const F = load(path.join(UI, "Fullscreen.js"));

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
const rect = (x, y, width, height) => ({ x, y, width, height });
// Two screens side by side; the task manager hands in only the windows of one.
const left = rect(0, 0, 1920, 1080), right = rect(1920, 0, 2560, 1440);
const win = more => Object.assign({ fullScreen: false, maximized: false, minimized: false, active: false, geometry: rect(100, 100, 800, 600) }, more);

test("a window that says it is full screen, while it is the active one", () => {
    check("active", F.fills([win({ fullScreen: true, active: true, geometry: left })], left), true);
    check("minimised", F.fills([win({ fullScreen: true, active: true, minimized: true, geometry: left })], left), false);
    check("another is active on this screen", F.fills([win({ fullScreen: true, geometry: left }), win({ active: true })], left), false);
    check("the active one is on another screen", F.fills([win({ fullScreen: true, geometry: left })], left), true);
    check("no windows", F.fills([], left), false);
});

test("the active one as large as the screen without saying so; a maximised one is not", () => {
    check("borderless game", F.fills([win({ active: true, geometry: left })], left), true);
    check("larger", F.fills([win({ active: true, geometry: rect(-2, -2, 1924, 1084) })], left), true);
    check("maximised on a screen without panels", F.fills([win({ active: true, maximized: true, geometry: left })], left), false);
    check("smaller", F.fills([win({ active: true, geometry: rect(0, 30, 1920, 1050) })], left), false);
    check("not active", F.fills([win({ geometry: left }), win({ active: true })], left), false);
    check("no screen given: only what says so", F.fills([win({ active: true, geometry: left })], null), false);
});

test("several screens: each island looks at its own", () => {
    // the task manager filters by screen: the right one's windows only
    const onRight = [win({ fullScreen: true, active: true, geometry: right })];
    check("the right screen", F.fills(onRight, right), true);
    check("the left screen sees none of them", F.fills([], left), false);
    // as large as the left screen, but on the right one (smaller than it)
    check("size measured on its own screen", F.fills([win({ active: true, geometry: rect(1920, 0, 1920, 1080) })], right), false);
});

test("a window that reaches under the notch", () => {
    const notch = rect(860, 0, 200, 32);
    check("maximised under it", F.reaches([win({ maximized: true, geometry: left })], notch), true);
    check("moved up to the edge", F.reaches([win({ geometry: rect(700, 10, 400, 300) })], notch), true);
    check("below it", F.reaches([win({ geometry: rect(700, 40, 400, 300) })], notch), false);
    check("beside it", F.reaches([win({ geometry: rect(0, 0, 500, 300) })], notch), false);
    check("minimised", F.reaches([win({ minimized: true, geometry: left })], notch), false);
    check("no area", F.reaches([win({ geometry: left })], rect(0, 0, 0, 0)), false);
});

test("what the strip says: a call first, then a recording, a warning, the microphone", () => {
    check("nothing", F.signalOf({}), "");
    check("microphone", F.signalOf({ privacy: true }), "privacy");
    check("warning over microphone", F.signalOf({ privacy: true, critical: true }), "critical");
    check("recording over warning", F.signalOf({ privacy: true, critical: true, recording: true }), "recording");
    check("call over all", F.signalOf({ privacy: true, critical: true, recording: true, calling: true }), "call");
    check("ringing", F.signalOf({ ringing: true }), "call");
});

test("only a call ringing opens it, and only if wanted", () => {
    check("ringing", F.opens({ ringing: true }, true), true);
    check("not wanted", F.opens({ ringing: true }, false), false);
    check("on a call", F.opens({ calling: true }, true), false);
    check("recording", F.opens({ recording: true, critical: true, privacy: true }, true), false);
});

console.log(failed === 0 ? `${checked} checks passed` : `${failed} of ${checked} checks FAILED`);
process.exit(failed > 0 ? 1 : 0);
