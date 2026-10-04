#!/usr/bin/env node
// What the suggestions learn (contents/ui/Suggestions.js), simulated over
// weeks with dates handed in: nothing here reads or changes the clock.
// Run by tools/run-tests; tests/tst_suggestions.qml runs the provider.
"use strict";
const fs = require("fs");
const path = require("path");

const UI = path.join(__dirname, "..", "org.phobby.dynamicisland", "contents", "ui");
function load(file) {
    const source = fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*$/m, "");
    const names = Array.from(source.matchAll(/^(?:function|const) (\w+)[ (=]/gm), m => m[1]);
    return new Function(source + "\nreturn { " + names.join(", ") + " };")();
}
const S = load(path.join(UI, "Suggestions.js"));

let failed = 0, checked = 0;
function check(what, got, want) {
    ++checked;
    const g = JSON.stringify(got), w = JSON.stringify(want);
    if (g === w) return;
    ++failed;
    console.log(`FAILED ${what}\n   got  ${g}\n   want ${w}`);
}
const MIN = 60000, HOUR = 3600000, DAY = 86400000;
const monday = new Date(2026, 9, 5, 14, 0).getTime();        // a Monday, 14:00
const saturday = monday + 5 * DAY;
const WD = "wd|noon", WE = "we|noon";
const many = (state, id, ctx, signal, n, from, step) => { for (let i = 0; i < n; ++i) state = S.record(state, id, ctx, signal, from + i * step).state; return state; };
const st = (state, id, ctx, at, t) => S.status(state, id, ctx, at, t);
const conf = (state, id, ctx, at) => Math.round(S.estimate(state, id, ctx, at).confidence * 100);

// ---- contexts: coarse buckets, nothing else
check("the kind of day and the part of the day", [S.timeFeatures(monday), S.timeFeatures(saturday + 8 * HOUR), S.timeFeatures(new Date(2026, 9, 5, 6, 0).getTime()).part, S.timeFeatures(new Date(2026, 9, 5, 19, 0).getTime()).part],
      [{ day: "wd", part: "noon" }, { day: "we", part: "night" }, "am", "eve"]);
check("a context", S.context({ day: "wd", part: "eve", calendar: "Work | x\ny", duration: S.durationBucket(45), video: true, output: "hp" }), "wd|eve|cal:Work   x y|dur:mid|video|out:hp");
check("…and back", S.features("we|am|cal:Home|dur:long|bat|media|out:spk"), { day: "we", part: "am", calendar: "Home", duration: "long", power: "bat", media: true, output: "spk" });
check("a title or an application is nothing a context can hold", Object.keys(S.features(S.context({ day: "wd", title: "Secret", app: "x", window: "y" }))), ["day"]);

// ---- nothing known: it asks; rules that guess are off
check("at first", [st(S.empty(), "meeting", WD, monday), conf(S.empty(), "meeting", WD, monday), st(S.empty(), "headphones", WD, monday), S.rule(S.empty(), "headphones").why], ["ask", 50, "off", "experimental"]);

// ---- five yeses in one context, on different days: "shall I do it by myself?", then automatic
let s = S.empty();
const seen = [];
for (let i = 0; i < 5; ++i) { seen.push(st(s, "meeting", WD, monday + i * DAY)); s = S.record(s, "meeting", WD, "yes", monday + i * DAY).state; }
check("asked while it learns, then the offer", [seen, st(s, "meeting", WD, monday + 5 * DAY)], [["ask", "ask", "ask", "ask", "offer"], "offer"]);
check("four on one day are not enough (two days are needed)", st(many(S.empty(), "meeting", WD, "yes", 5, monday, MIN), "meeting", WD, monday + HOUR), "ask");
let auto = S.automatic(s, "meeting", WD, true, monday + 5 * DAY);
check("accepted: automatic there, and only there", [st(auto, "meeting", WD, monday + 7 * DAY), st(auto, "meeting", "wd|eve", monday + 7 * DAY)], ["auto", "ask"]);
const declined = S.automatic(s, "meeting", WD, false, monday + 5 * DAY);
check("declined: it keeps asking and does not offer again", [st(declined, "meeting", WD, monday + 6 * DAY), st(S.record(declined, "meeting", WD, "yes", monday + 6 * DAY).state, "meeting", WD, monday + 7 * DAY)], ["ask", "ask"]);
check("\"always\" makes it automatic at once", st(S.record(S.empty(), "meeting", WD, "always", monday).state, "meeting", WD, monday), "auto");

// ---- weekdays welcome, weekend not: the weekend falls silent, the weekdays are untouched
let w = S.record(s, "meeting", WE, "no", saturday).state;
check("one no in a new context: mixed with the rule's estimate, still asked", [st(w, "meeting", WE, saturday), conf(w, "meeting", WE, saturday) > 40, st(w, "meeting", WD, saturday)], ["ask", true, "offer"]);
w = S.record(w, "meeting", WE, "no", saturday + DAY).state;
check("a second no: silent there", [st(w, "meeting", WE, saturday + DAY), st(w, "meeting", WD, saturday + DAY), conf(w, "meeting", WD, saturday + DAY) >= 80], ["silent", "offer", true]);

// ---- no answer is not a no
let ignored = many(S.empty(), "call", WD, "timeout", 5, monday, DAY);
check("five unanswered: still asked", [st(ignored, "call", WD, monday + 5 * DAY), conf(ignored, "call", WD, monday + 5 * DAY) > 25], ["ask", true]);
const afterCard = S.record(ignored, "call", WD, "shown", monday + 5 * DAY).state;
check("…but less often: the wait has doubled five times", [S.waits(afterCard, "call", monday + 5 * DAY, null, 0) / MIN, S.waits(afterCard, "call", monday + 5 * DAY + 641 * MIN, null, 0)], [640, 0]);
check("a yes ends that", S.waits(S.record(S.record(afterCard, "call", WD, "yes", monday + 6 * DAY).state, "call", WD, "shown", monday + 6 * DAY).state, "call", monday + 6 * DAY, null, 0) / MIN, 20);
check("two plain noes silence a context; \"not now\" twice does not", [st(many(S.empty(), "call", WD, "no", 2, monday, DAY), "call", WD, monday + 2 * DAY), st(many(S.empty(), "call", WD, "later", 2, monday, DAY), "call", WD, monday + 2 * DAY)], ["silent", "ask"]);
check("a suggestion nobody saw teaches nothing", [conf(S.record(S.empty(), "call", WD, "shown", monday).state, "call", WD, monday), conf(S.record(S.empty(), "call", WD, "auto", monday).state, "call", WD, monday)], [50, 50]);

// ---- what was decided long ago counts less
const old = many(S.empty(), "call", WD, "no", 2, monday, DAY);
check("ninety days later the noes have faded: it asks again", [conf(old, "call", WD, monday + 2 * DAY), conf(old, "call", WD, monday + 92 * DAY) > 35, st(old, "call", WD, monday + 92 * DAY)], [20, true, "ask"]);
const longHalf = S.tuning("balanced", 0, 0, 365);
check("with a longer half-life they have not", st(old, "call", WD, monday + 92 * DAY, longHalf), "silent");

// ---- done by hand: learned without asking, and one question after four
let hand = S.empty();
const handSeen = [];
for (let i = 0; i < 4; ++i) { hand = S.record(hand, "pomodoro", WD, "implicit", monday + i * DAY).state; handSeen.push(st(hand, "pomodoro", WD, monday + i * DAY)); }
check("four times by hand: the offer", handSeen, ["ask", "ask", "ask", "offer"]);
check("why", [S.why(hand, "pomodoro", WD, monday + 4 * DAY), S.why(s, "meeting", WD, monday + 5 * DAY), S.why(S.empty(), "meeting", WD, monday), S.why(s, "meeting", WE, saturday)],
      [{ kind: "hand", n: 4 }, { kind: "answers", yes: 5, of: 5 }, { kind: "new" }, { kind: "similar", welcome: true }]);
hand = S.automatic(hand, "pomodoro", WD, false, monday + 4 * DAY);
check("asked once: not again, however often it is done by hand", st(many(hand, "pomodoro", WD, "implicit", 3, monday + 5 * DAY, DAY), "pomodoro", WD, monday + 9 * DAY), "ask");

// ---- undo: asks again there; a second undo closes the rule there
let u = S.record(auto, "meeting", WD, "auto", monday + 7 * DAY).state;
let r1 = S.record(u, "meeting", WD, "undo", monday + 7 * DAY);
check("undone once: it asks again, and is noted in the log", [r1.closed, st(r1.state, "meeting", WD, monday + 8 * DAY), r1.state.log.map(l => l.undone)], [false, "ask", [1]]);
u = S.record(r1.state, "meeting", WD, "always", monday + 8 * DAY).state;
u = S.record(u, "meeting", WD, "auto", monday + 9 * DAY).state;
const r2 = S.record(u, "meeting", WD, "undo", monday + 9 * DAY);
check("undone twice: closed there, open elsewhere", [r2.closed, st(r2.state, "meeting", WD, monday + 10 * DAY), st(r2.state, "meeting", WE, saturday + 7 * DAY)], [true, "off", "ask"]);
check("switched on again in the settings: open again", st(S.setMode(S.setMode(r2.state, "meeting", "off"), "meeting", "learn"), "meeting", WD, monday + 10 * DAY) !== "off", true);

// ---- the settings' modes, forgetting
check("modes", [st(S.setMode(s, "meeting", "ask"), "meeting", WD, monday + 5 * DAY), st(S.setMode(S.empty(), "call", "auto"), "call", WD, monday), st(S.setMode(s, "meeting", "off"), "meeting", WD, monday),
                S.rule(S.never(s, "meeting"), "meeting").why, st(S.setMode(S.empty(), "headphones", "learn"), "headphones", WD, monday)], ["ask", "auto", "off", "never", "ask"]);
check("a context forgotten, a rule reset", [conf(S.forget(w, "meeting", WE), "meeting", WE, saturday + DAY) > 50, S.contexts(w, "meeting", saturday + DAY).map(c => c.ctx + ":" + c.status), S.reset(w, "meeting").events.length],
      [true, ["wd|noon:offer", "we|noon:silent"], 0]);

// ---- cards a day, the last week
let busy = S.empty();
for (let i = 0; i < 4; ++i) busy = S.record(busy, "call", WD, "shown", monday + i * HOUR).state;
busy = S.record(S.record(busy, "call", WD, "yes", monday).state, "call", WD, "auto", monday - 8 * DAY).state;
check("cards today, the last seven days", [S.cardsToday(busy, monday + 5 * HOUR), S.cardsToday(busy, monday + DAY), S.week(busy, monday + DAY)], [4, 0, { shown: 4, accepted: 1, automatic: 0 }]);
check("the levels", [S.tuning("quiet", 0, 0, 0).dailyCards, S.tuning("active", 0, 0, 0).cooldown / MIN, S.tuning("nonsense", 4, 45, 10), st(many(S.empty(), "call", WD, "no", 1, monday, DAY), "call", WD, monday, S.tuning("quiet", 0, 0, 0))],
      [2, 10, { silentBelow: 0.25, dailyCards: 4, cooldown: 45 * MIN, halfLife: 10 * DAY }, "silent"]);

// ---- kept small: old signals become sums, what they taught stays
let big = S.empty();
for (let i = 0; i < 260; ++i) big = S.record(big, i % 2 ? "meeting" : "call", WD, i % 5 === 0 ? "no" : "yes", monday + i * HOUR).state;
check("at most 200 signals; the rest folded", [big.events.length, Object.keys(big.folded).sort(), big.folded.call[WD].n > 0, conf(big, "meeting", WD, monday + 261 * HOUR) > 60, S.text(big).length < 16000], [200, ["call", "meeting"], true, true, true]);
let logged = S.empty();
for (let i = 0; i < 60; ++i) logged = S.record(logged, "call", WD, "auto", monday + i * MIN).state;
check("the log keeps the last 50", logged.log.length, 50);

// ---- the first version's data: nothing is lost
const v1 = JSON.stringify({ v: 1, last: monday, rules: { meeting: { mode: "auto", why: "", yes: 7, later: 1, yesRow: 4, laterRow: 0, last: monday, asked: 1, told: 0 },
                                                         call: { mode: "off", why: "never", yes: 0, later: 2, yesRow: 0, laterRow: 2, last: monday, asked: 0, told: 0 },
                                                         recording: { mode: "suggest", why: "", yes: 3, later: 0, yesRow: 3, laterRow: 0, last: monday, asked: 0, told: 0 },
                                                         battery: { mode: "off", why: "ignored", yes: 0, later: 5, yesRow: 0, laterRow: 5, last: monday, asked: 0, told: 1 } } });
const m = S.parse(v1);
check("migrated: the modes", [m.v, st(m, "meeting", WD, monday), S.rule(m, "call").why, S.rule(m, "battery").why, st(m, "recording", WD, monday)], [2, "auto", "never", "ignored", "ask"]);
check("migrated: the answers, as what is known of the rule in general", [conf(m, "recording", WD, monday), conf(m, "recording", WE, saturday) > 70, typeof m.legacy, S.parse(S.text(m)).folded.meeting["*"].n], [80, true, "string", 7]);
check("migrated: a rule that is experimental now stays off, with what it had learned", [S.rule(S.parse(JSON.stringify({ v: 1, last: 5, rules: { headphones: { mode: "suggest", yes: 0, later: 1, last: 5 } } })), "headphones").why,
       S.parse(JSON.stringify({ v: 1, last: 5, rules: { headphones: { mode: "suggest", yes: 0, later: 1, last: 5 } } })).folded.headphones["*"].neg,
       S.rule(S.parse(JSON.stringify({ v: 1, rules: { headphones: { mode: "auto", yes: 4 } } })), "headphones").mode], ["experimental", 0.4, "auto"]);
check("round trip, nonsense, a future version's fields", [S.text(S.parse(S.text(w))) === S.text(w), S.parse("{{").v, S.parse(JSON.stringify({ v: 2, rules: { bogus: {}, call: { mode: "x", closed: { a: 1 } } }, events: [{ r: "bogus", s: "yes" }, { r: "call", s: "zap" }] })).events.length], [true, 2, 0]);

console.log(failed === 0 ? `${checked} checks passed` : `${failed} of ${checked} checks FAILED`);
process.exit(failed > 0 ? 1 : 0);
