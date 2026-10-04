#!/usr/bin/env node
// Suggestions (contents/ui/Suggestions.js): what is learned from the answers.
// Every moment is handed in (ms); the clock is never read. Run by tools/run-tests.
"use strict";
const fs = require("fs");
const path = require("path");

function load(file) {
    const source = fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*$/m, "");
    const names = Array.from(source.matchAll(/^(?:function|const) (\w+)[ (=]/gm), m => m[1]);
    return new Function(source + "\nreturn { " + names.join(", ") + " };")();
}
const S = load(path.join(__dirname, "..", "org.phobby.dynamicisland", "contents", "ui", "Suggestions.js"));

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

const MIN = 60000, HOUR = 60 * MIN, GAP = 5 * MIN;
// Monday 5 October 2026, 09:00: every moment below is counted from it.
const T0 = new Date(2026, 9, 5, 9, 0).getTime();
// A suggestion that was shown at `at` and answered with `what`.
const round = (state, id, at, what) => S.answer(S.shown(state, id, at), id, what).state;

console.log("Suggestions.js");

test("a rule nobody answered yet asks", () => {
    const s = S.empty();
    check("asks", S.decide(s, "meeting", T0, GAP), "suggest");
    check("what is known", S.rule(s, "meeting"), { mode: "suggest", why: "", yes: 0, later: 0, yesRow: 0, laterRow: 0, last: 0, asked: 0, told: 0 });
    check("the rules", S.RULES, ["meeting", "recording", "call", "battery", "pomodoro", "headphones"]);
});

test("at least five minutes between two suggestions, of whatever rule", () => {
    const s = S.shown(S.empty(), "meeting", T0);
    check("the same rule, 4:59 later", S.decide(s, "meeting", T0 + 5 * MIN - 1000, GAP), "");
    check("another rule, 4:59 later", S.decide(s, "battery", T0 + 5 * MIN - 1000, GAP), "");
    check("5:00 later", [S.decide(s, "meeting", T0 + 5 * MIN, GAP), S.decide(s, "battery", T0 + 5 * MIN, GAP)], ["suggest", "suggest"]);
    check("the pause is a setting", [S.decide(s, "battery", T0 + 2 * MIN, 1 * MIN), S.decide(s, "battery", T0 + 20 * MIN, 30 * MIN)], ["suggest", ""]);
});

test("never again is for good", () => {
    let s = round(S.empty(), "call", T0, "never");
    check("off", [S.rule(s, "call").mode, S.rule(s, "call").why], ["off", "never"]);
    for (const later of [HOUR, 24 * HOUR, 365 * 24 * HOUR]) check("still off after " + later / HOUR + " h", S.decide(s, "call", T0 + later, GAP), "");
    check("the other rules go on", S.decide(s, "battery", T0 + HOUR, GAP), "suggest");
    // read back after a restart
    s = S.parse(S.text(s));
    check("off after a restart", S.decide(s, "call", T0 + 48 * HOUR, GAP), "");
    // switched on again in the settings
    s = S.setMode(s, "call", "suggest");
    check("on again", [S.decide(s, "call", T0 + 49 * HOUR, GAP), S.rule(s, "call").why], ["suggest", ""]);
});

test("three times \"not now\" in a row: suggested less often", () => {
    let s = S.empty(), at = T0;
    for (let i = 1; i <= 2; ++i) { s = round(s, "pomodoro", at, "later"); at += 10 * MIN; }
    check("twice: as often as before", [S.wait(S.rule(s, "pomodoro")), S.decide(s, "pomodoro", at, GAP)], [0, "suggest"]);
    s = round(s, "pomodoro", at, "later");
    const third = at;
    check("three in a row", [S.rule(s, "pomodoro").laterRow, S.wait(S.rule(s, "pomodoro"))], [3, HOUR]);
    check("not for an hour", [S.decide(s, "pomodoro", third + 10 * MIN, GAP), S.decide(s, "pomodoro", third + HOUR - 1, GAP), S.decide(s, "pomodoro", third + HOUR, GAP)], ["", "", "suggest"]);
    check("other rules are not slowed", S.decide(s, "battery", third + 10 * MIN, GAP), "suggest");
    // the fourth: twice as long
    s = round(s, "pomodoro", third + HOUR, "timeout");
    check("four in a row: two hours", [S.wait(S.rule(s, "pomodoro")), S.decide(s, "pomodoro", third + 3 * HOUR - 1, GAP), S.decide(s, "pomodoro", third + 3 * HOUR, GAP)], [2 * HOUR, "", "suggest"]);
    // a yes in between: as often as before again
    const yes = round(s, "pomodoro", third + 3 * HOUR, "yes");
    check("a yes ends the row", [S.rule(yes, "pomodoro").laterRow, S.wait(S.rule(yes, "pomodoro"))], [0, 0]);
});

test("no answer counts like \"not now\"; five in a row switch the rule off, said once", () => {
    let s = S.empty(), at = T0, result = null;
    for (let i = 1; i <= 5; ++i) {
        check("round " + i + " is asked", S.decide(s, "headphones", at, GAP), "suggest");
        result = S.answer(S.shown(s, "headphones", at), "headphones", i % 2 ? "timeout" : "later");
        s = result.state;
        if (i < 5) check("round " + i + ": still on, nothing said", [S.rule(s, "headphones").mode, result.notice], ["suggest", false]);
        at += 4 * HOUR;
    }
    check("the fifth: off, and it is said", [S.rule(s, "headphones").mode, S.rule(s, "headphones").why, result.notice], ["off", "ignored", true]);
    check("not suggested any more", S.decide(s, "headphones", at + 100 * HOUR, GAP), "");
    // switched on in the settings and ignored five times again: said again (it was switched on on purpose)
    s = S.setMode(s, "headphones", "suggest");
    check("on again, with a clean slate", [S.rule(s, "headphones").laterRow, S.decide(s, "headphones", at, GAP)], [0, "suggest"]);
    for (let i = 1; i <= 5; ++i) { result = S.answer(S.shown(s, "headphones", at), "headphones", "timeout"); s = result.state; at += 4 * HOUR; }
    check("off again, said again", [S.rule(s, "headphones").mode, result.notice], ["off", true]);
});

test("three times yes in a row: asked once whether to do it automatically", () => {
    let s = S.empty(), at = T0, result = null;
    for (let i = 1; i <= 3; ++i) {
        result = S.answer(S.shown(s, "meeting", at), "meeting", "yes");
        s = result.state;
        check("yes " + i + ": offer", result.offer, i === 3);
        at += HOUR;
    }
    check("counted", [S.rule(s, "meeting").yes, S.rule(s, "meeting").yesRow, S.rule(s, "meeting").asked], [3, 3, 1]);
    // declined: it keeps asking, and the offer is not made again
    let no = S.automatic(s, "meeting", false);
    check("declined: still asks", [S.rule(no, "meeting").mode, S.decide(no, "meeting", at, GAP)], ["suggest", "suggest"]);
    for (let i = 0; i < 4; ++i) { result = S.answer(S.shown(no, "meeting", at), "meeting", "yes"); no = result.state; at += HOUR; check("no second offer", result.offer, false); }
    // accepted: automatic
    const yes = S.automatic(s, "meeting", true);
    check("accepted: automatic", [S.rule(yes, "meeting").mode, S.decide(yes, "meeting", at, GAP)], ["auto", "auto"]);
    check("automatic does not wait for the pause between suggestions", S.decide(S.shown(yes, "battery", at), "meeting", at + 1000, GAP), "auto");
    check("automatic after a restart", S.decide(S.parse(S.text(yes)), "meeting", at + 24 * HOUR, GAP), "auto");
    // a "not now" between the yeses starts the row again
    let mixed = S.empty();
    for (const what of ["yes", "yes", "later", "yes", "yes"]) { result = S.answer(S.shown(mixed, "call", at), "call", what); mixed = result.state; at += HOUR; }
    check("yes, yes, not now, yes, yes: no offer yet", [result.offer, S.rule(mixed, "call").yesRow], [false, 2]);
    check("the third in a row", S.answer(S.shown(mixed, "call", at), "call", "yes").offer, true);
});

test("undo puts an automatic rule back to asking", () => {
    let s = S.empty(), at = T0;
    for (let i = 0; i < 3; ++i) { s = round(s, "recording", at, "yes"); at += HOUR; }
    s = S.automatic(s, "recording", true);
    check("automatic", S.decide(s, "recording", at, GAP), "auto");
    s = S.undone(s, "recording");
    check("asks again", [S.rule(s, "recording").mode, S.decide(s, "recording", at + HOUR, GAP)], ["suggest", "suggest"]);
    check("and is not offered again by itself", S.answer(S.shown(s, "recording", at + HOUR), "recording", "yes").offer, false);
    check("undoing what was not automatic changes nothing", S.undone(S.empty(), "recording"), S.empty());
});

test("the settings: mode per rule, forget one rule, forget all", () => {
    let s = S.empty(), at = T0;
    s = S.setMode(s, "battery", "auto");
    check("automatic by hand", S.decide(s, "battery", at, GAP), "auto");
    s = S.setMode(s, "battery", "off");
    check("off by hand", [S.decide(s, "battery", at, GAP), S.rule(s, "battery").why], ["", "settings"]);
    check("the same mode again changes nothing", S.setMode(s, "battery", "off"), s);
    check("an unknown mode changes nothing", S.setMode(s, "battery", "sometimes"), s);
    for (let i = 0; i < 4; ++i) { s = round(s, "call", at, "later"); at += 4 * HOUR; }
    check("learned", [S.rule(s, "call").laterRow, S.wait(S.rule(s, "call"))], [4, 2 * HOUR]);
    s = S.reset(s, "call");
    check("forgotten", [S.rule(s, "call"), S.rule(s, "battery").mode], [S.fresh(), "off"]);
    check("forgetting what was never learned changes nothing", S.reset(s, "meeting"), s);
});

test("what is stored", () => {
    let s = S.empty(), at = T0;
    for (const what of ["yes", "later", "timeout"]) { s = round(s, "meeting", at, what); at += HOUR; }
    s = round(s, "call", at, "never");
    const stored = S.text(s);
    check("read back the same", S.parse(stored), s);
    check("small", stored.length < 400, true);
    check("a record per rule", S.parse(stored).rules.meeting, { mode: "suggest", why: "", yes: 1, later: 2, yesRow: 0, laterRow: 2, last: T0 + 2 * HOUR, asked: 0, told: 0 });
    check("a broken text is an empty record", [S.parse("{nope"), S.parse(""), S.parse("[]")], [S.empty(), S.empty(), S.empty()]);
    check("unknown rules and odd values are left out",
          S.parse(JSON.stringify({ last: "x", rules: { spy: { mode: "auto" }, meeting: { mode: "always", yes: -3, later: "2", why: "because" } } })),
          { v: 1, last: 0, rules: { meeting: { mode: "suggest", why: "", yes: 0, later: 2, yesRow: 0, laterRow: 0, last: 0, asked: 0, told: 0 } } });
    check("nothing is changed in place", S.text(S.empty()), '{"v":1,"last":0,"rules":{}}');
});

console.log(failed === 0 ? `${checked} checks passed` : `${failed} of ${checked} checks FAILED`);
process.exit(failed > 0 ? 1 : 0);
