/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Suggestions: what the island has learned from the answers to them. Rule
    based and local: no network, no model, only counters per rule, kept as a
    small JSON text (providers/SuggestionProvider.qml stores it in a file).

      { v, last, rules: { id: { mode, why, yes, later, yesRow, laterRow, last, asked, told } } }

    mode      "suggest" (ask), "auto" (do it and say so) or "off"
    why       why it is off: "never" (the user said so), "ignored" (five
              unanswered in a row) or "settings"
    yes       how often the answer was yes; later: "not now" or no answer
    yesRow    yes answers in a row; laterRow: "not now" / no answer in a row
    last      when it was last suggested (ms); the state's own `last` is the
              last suggestion of any rule (the pause between two)
    asked     "do this automatically from now on?" was asked (it is asked once)
    told      "I will not show this any more" was said (it is said once)

    How it learns:
      * "never": the rule is off for good (until it is switched on in the settings)
      * "not now" or no answer three times in a row: the rule waits longer
        before it suggests again (an hour, then twice that); five times: it
        is switched off, and the island says so once
      * yes three times in a row: the island asks once whether to do it
        automatically; then it acts without asking and offers "Undo", which
        puts the rule back to asking

    Every function takes the moment it is asked about (ms), so nothing here
    reads the clock; none changes the state it is given.
*/
.pragma library

// The rules the island knows, in the order the settings list them.
const RULES = ["meeting", "recording", "call", "battery", "pomodoro", "headphones"];
const SLOWER_AFTER = 3;             // "not now" / no answer in a row: wait longer from here on
const OFF_AFTER = 5;                // …and switched off here
const AUTO_AFTER = 3;               // yes in a row: offer to do it automatically
const FIRST_WAIT = 60 * 60000;      // the first longer wait; it doubles with every further one

function empty() { return { v: 1, last: 0, rules: {} }; }
function fresh() { return { mode: "suggest", why: "", yes: 0, later: 0, yesRow: 0, laterRow: 0, last: 0, asked: 0, told: 0 }; }

function parse(json) {
    const out = empty();
    let given = null;
    try { given = JSON.parse(json || "{}"); } catch (e) {}
    if (!given || typeof given !== "object") return out;
    const count = v => Math.max(0, Math.floor(Number(v)) || 0);
    out.last = count(given.last);
    for (const id of RULES) {
        const g = given.rules && given.rules[id];
        if (!g || typeof g !== "object") continue;
        const r = fresh();
        if (g.mode === "auto" || g.mode === "off") r.mode = g.mode;
        if (r.mode === "off") r.why = g.why === "never" || g.why === "ignored" ? g.why : "settings";
        for (const key of ["yes", "later", "yesRow", "laterRow", "last"]) r[key] = count(g[key]);
        r.asked = g.asked ? 1 : 0;
        r.told = g.told ? 1 : 0;
        out.rules[id] = r;
    }
    return out;
}
function text(state) { return JSON.stringify(state); }
function copy(state) { return parse(JSON.stringify(state)); }
// What is known about a rule (a rule nobody answered yet: asks, with all counters at zero).
function rule(state, id) { return state.rules[id] !== undefined ? state.rules[id] : fresh(); }
function touched(state, id) {
    const next = copy(state);
    if (next.rules[id] === undefined) next.rules[id] = fresh();
    return next;
}

// How long a rule waits after it was suggested before it may be suggested again (ms).
function wait(record) {
    return record.laterRow < SLOWER_AFTER ? 0 : FIRST_WAIT * Math.pow(2, record.laterRow - SLOWER_AFTER);
}
// What to do now that the rule's moment has come: "auto" (do it), "suggest" (ask) or ""
// (nothing: it is off, the last suggestion of any rule is less than `gap` ms ago, or the
// rule itself still waits).
function decide(state, id, now, gap) {
    const r = rule(state, id);
    if (r.mode === "off") return "";
    if (r.mode === "auto") return "auto";
    if (state.last > 0 && now - state.last < gap) return "";
    if (r.last > 0 && now - r.last < wait(r)) return "";
    return "suggest";
}
// The suggestion was shown at `now`.
function shown(state, id, now) {
    const next = touched(state, id);
    next.last = now;
    next.rules[id].last = now;
    return next;
}
// The answer to a suggestion: "yes", "later" (not now), "timeout" (no answer) or "never".
// { state, offer (ask now whether to do it automatically), notice (say now that it was switched off) }
function answer(state, id, what) {
    const next = touched(state, id), r = next.rules[id];
    let offer = false, notice = false;
    if (what === "yes") {
        r.yes += 1; r.yesRow += 1; r.laterRow = 0;
        if (r.mode === "suggest" && r.yesRow >= AUTO_AFTER && !r.asked) { offer = true; r.asked = 1; }
    } else if (what === "never") {
        r.mode = "off"; r.why = "never"; r.yesRow = 0;
    } else {
        r.later += 1; r.laterRow += 1; r.yesRow = 0;
        if (r.mode === "suggest" && r.laterRow >= OFF_AFTER) {
            r.mode = "off"; r.why = "ignored";
            notice = !r.told;
            r.told = 1;
        }
    }
    return { state: next, offer: offer, notice: notice };
}
// The answer to "do this automatically from now on?".
function automatic(state, id, accept) {
    const next = touched(state, id), r = next.rules[id];
    r.asked = 1;
    if (accept && r.mode !== "off") r.mode = "auto";
    return next;
}
// An automatic action was undone: the rule asks again.
function undone(state, id) {
    const r = rule(state, id);
    if (r.mode !== "auto") return state;
    const next = touched(state, id);
    next.rules[id].mode = "suggest";
    next.rules[id].yesRow = 0;
    return next;
}
// Set in the settings: "suggest", "auto" or "off". Asking again starts with a clean slate
// of unanswered ones, or it would be switched off again at once.
function setMode(state, id, mode) {
    const r = rule(state, id);
    if (r.mode === mode || (mode !== "suggest" && mode !== "auto" && mode !== "off")) return state;
    const next = touched(state, id), n = next.rules[id];
    n.mode = mode;
    n.why = mode === "off" ? "settings" : "";
    if (mode !== "off") { n.laterRow = 0; n.told = 0; }
    return next;
}
// What was learned about one rule is forgotten.
function reset(state, id) {
    if (state.rules[id] === undefined) return state;
    const next = copy(state);
    delete next.rules[id];
    return next;
}
