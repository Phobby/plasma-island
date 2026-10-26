#!/usr/bin/env node
// The settings brought up to date (contents/ui/SettingsMigration.js): a new island has
// the notch; one that ran before keeps what it showed (the notch where it was switched
// on, the oval layout otherwise) and is told once; what the notch did over a window that
// fills the screen is the full-screen mode of both layouts, as it was; each step is taken
// once, can be undone and taken again to the same end. Run by tools/run-tests.
"use strict";
const fs = require("fs");
const path = require("path");

const UI = path.join(__dirname, "..", "org.phobby.dynamicisland", "contents", "ui");
function load(file) {
    const source = fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*$/m, "");
    const names = Array.from(source.matchAll(/^(?:function|const) (\w+)[ (=]/gm), m => m[1]);
    return new Function(source + "\nreturn { " + names.join(", ") + " };")();
}
const M = load(path.join(UI, "SettingsMigration.js"));

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
// The settings as main.xml has them when nothing was written (what a new widget reads).
function fresh(more) {
    return Object.assign({ settingsSchema: 0, islandLayout: 0, notchMode: false, installedVersion: "", settingsKept: false, layoutNotice: 0,
                          notchFullscreen: 0, fullscreenMode: 0 }, more || {});
}
// What the settings are once the changes are written.
function after(c, restored) { return Object.assign({}, c, M.migrate(c, restored)); }

test("a new island: the notch, nothing to tell", () => {
    check("changes", M.migrate(fresh(), false), { settingsSchema: 2, fullscreenMode: M.HIDE });
    check("layout before", M.layoutOf(fresh(), false), M.NOTCH);
    check("layout after", M.layoutOf(after(fresh(), false), false), M.NOTCH);
});

test("one that ran before, notch never switched on: the oval layout, told once", () => {
    for (const earlier of [{ installedVersion: "0.2.2" }, { installedVersion: "0.2.0" }, { settingsKept: true }]) {
        const c = fresh(earlier);
        check("changes " + JSON.stringify(earlier), M.migrate(c, false), { settingsSchema: 2, islandLayout: M.OVAL, layoutNotice: 1, fullscreenMode: M.HIDE });
        check("layout before, as after", M.layoutOf(c, false), M.OVAL);
    }
    check("brought back from an earlier island", M.migrate(fresh(), true), { settingsSchema: 2, islandLayout: M.OVAL, layoutNotice: 1, fullscreenMode: M.HIDE });
});

test("one that ran before with the notch on: the notch, nothing to tell", () => {
    const c = fresh({ installedVersion: "0.2.2", notchMode: true });
    check("changes", M.migrate(c, false), { settingsSchema: 2, islandLayout: M.NOTCH, fullscreenMode: M.HIDE });
    check("layout before", M.layoutOf(c, false), M.NOTCH);
});

test("once: up to date, nothing more; what was chosen since stays", () => {
    const c = after(fresh({ installedVersion: "0.2.2" }), false);
    check("again", M.migrate(c, false), {});
    c.islandLayout = M.NOTCH;          // the user picks the notch
    check("still nothing", M.migrate(c, false), {});
    check("and it is the notch", M.layoutOf(c, false), M.NOTCH);
});

test("told only once", () => {
    const c = fresh({ installedVersion: "0.2.2", layoutNotice: 2 });
    check("already told", M.migrate(c, false).layoutNotice, undefined);
});

test("undone and taken again: the same", () => {
    for (const start of [fresh({ installedVersion: "0.2.2" }), fresh({ installedVersion: "0.2.2", notchMode: true })]) {
        const done = after(start, false);
        const undone = Object.assign({}, done, M.revert(done));
        check("back to version 0", undone.settingsSchema, 0);
        const again = after(undone, false);
        check("the same layout", again.islandLayout, done.islandLayout);
    }
    // the layout chosen in between is what it comes back to
    const done = after(fresh({ installedVersion: "0.2.2" }), false);
    done.islandLayout = M.NOTCH;
    const undone = Object.assign({}, done, M.revert(done));
    check("kept in notchMode", undone.notchMode, true);
    check("and back", after(undone, false).islandLayout, M.NOTCH);
    check("nothing to undo before", M.revert(fresh()), {});
});

test("what cannot be read is as new", () => {
    check("no values at all", M.migrate({}, false), { settingsSchema: 2, fullscreenMode: M.HIDE });
    check("a strange layout reads as the notch", M.layoutOf({ settingsSchema: 1, islandLayout: 7 }, false), M.NOTCH);
});

test("the full-screen mode: what the notch did, as it was (show = normal, hide = hide, dodge = peek)", () => {
    const pairs = [[0, M.HIDE], [1, M.NORMAL], [2, M.PEEK], [3, M.SHRINK], [7, M.HIDE], [undefined, M.HIDE]];
    for (const [old, mode] of pairs) {
        const c = fresh({ installedVersion: "0.2.2", notchMode: true, notchFullscreen: old });
        check("from " + old, M.migrate(c, false).fullscreenMode, mode);
        check("before the step, as after: " + old, M.fullscreenOf(c), mode);
        check("after the step", M.fullscreenOf(after(c, false)), mode);
    }
    // a new island: as before there was a choice, hidden
    check("new", M.fullscreenOf(after(fresh(), false)), M.HIDE);
    // the oval layout's island takes it as it was too
    check("oval", M.migrate(fresh({ installedVersion: "0.2.2", notchFullscreen: 1 }), false).fullscreenMode, M.NORMAL);
});

test("from version 1: only the full-screen mode, the layout stays", () => {
    const c = fresh({ installedVersion: "0.2.2", settingsSchema: 1, islandLayout: M.OVAL, notchFullscreen: 2, layoutNotice: 2 });
    check("changes", M.migrate(c, false), { settingsSchema: 2, fullscreenMode: M.PEEK });
    // what was chosen since stays: the mode once at version 2 is fullscreenMode, whatever notchFullscreen says
    const done = after(c, false);
    done.fullscreenMode = M.NORMAL;
    check("chosen since", M.fullscreenOf(done), M.NORMAL);
    check("nothing more", M.migrate(done, false), {});
    // undone: kept in notchFullscreen, and back to the same
    const undone = Object.assign({}, done, M.revert(done));
    check("kept", undone.notchFullscreen, M.NORMAL);
    check("and back", after(undone, false).fullscreenMode, M.NORMAL);
});

console.log(failed === 0 ? `${checked} checks passed` : `${failed} of ${checked} checks FAILED`);
process.exit(failed > 0 ? 1 : 0);
