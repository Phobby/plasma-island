/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Habits: what the user wants to do every day and how each day went, kept as
    a small JSON text in the widget's settings (`habitsData`) like the Pomodoro
    statistics: nothing else to install or open.

      { v, setup, next,
        habits: [{ id, name, gone }]     the permanent habits, in the user's order
        days:   { "YYYY-MM-DD": { r, on, off, x } }
        plan:   { "YYYY-MM-DD": [name] } one-time extras of a day whose list is not made yet
        runs:   { name: { last, n } }    extras: the last day each was listed, and for how many days in a row
        last, told, shut }

    A day's list is `on` (ids of the habits done) + `off` (ids not done) + `x`
    (the one-time extras: { n: name, d: done, q: the evening asked about it }),
    `r` says the evening review was done. A habit taken off one day only is in
    neither `on` nor `off` of that day. A deleted habit stays as `gone` while a
    day still names it, so what earlier days say never changes.

    `last` is the newest day whose list was made, `told` the day whose review
    the island announced, `shut` the day whose waiting review was closed.
    `days` holds the last year. Names are compared by fold(): no case, no spaces.

    Every function takes the day or the moment it is asked about, so nothing
    here reads the clock; and none changes the state it is given: the changed
    one is returned (the same object when there was nothing to change).
*/
.pragma library

const KEEP_DAYS = 370;
const NAME_LENGTH = 80;
// An extra listed this many days in a row becomes a permanent habit.
const PROMOTE_AFTER = 2;
const KEY = /^\d{4}-\d{2}-\d{2}$/;

// ---- days -------------------------------------------------------------------------
function dayKey(date) {
    const two = n => (n < 10 ? "0" : "") + n;
    return date.getFullYear() + "-" + two(date.getMonth() + 1) + "-" + two(date.getDate());
}
// The day `offset` days from `date` (noon: never trips over a clock change).
function shifted(date, offset) {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate() + offset, 12);
}
function dateOf(key) {
    const p = key.split("-");
    return new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]), 12);
}
function keyShift(key, offset) { return dayKey(shifted(dateOf(key), offset)); }

// ---- names ------------------------------------------------------------------------
function clean(name) { return String(name === undefined || name === null ? "" : name).replace(/\s+/g, " ").trim().slice(0, NAME_LENGTH); }
// "Pazara git" = "pazara  GİT" = "PAZARAGIT": the Turkish i's are one letter here.
function fold(name) {
    return String(name).replace(/\s+/g, "").replace(/[İIı]/g, "i").toLowerCase().replace(/̇/g, "");
}

// ---- the stored text ----------------------------------------------------------------
function empty() {
    return { v: 1, setup: 0, next: 1, habits: [], days: {}, plan: {}, runs: {}, last: "", told: "", shut: "" };
}

function parse(json) {
    const out = empty();
    let given = null;
    try { given = JSON.parse(json || "{}"); } catch (e) {}
    if (!given || typeof given !== "object") return out;

    out.setup = given.setup ? 1 : 0;
    const known = {};
    for (const h of Array.isArray(given.habits) ? given.habits : []) {
        const id = Math.floor(Number(h && h.id)), name = clean(h && h.name);
        if (!(id > 0) || known[id] || name.length === 0) continue;
        known[id] = true;
        out.habits.push(h.gone ? { id: id, name: name, gone: 1 } : { id: id, name: name });
        out.next = Math.max(out.next, id + 1);
    }
    out.next = Math.max(out.next, Math.floor(Number(given.next)) || 1);

    for (const key in given.days || {}) {
        const d = given.days[key];
        if (!KEY.test(key) || !d || typeof d !== "object") continue;
        // an id is on a list once, and only the id of a habit
        const seen = {};
        const ids = list => (Array.isArray(list) ? list : []).map(n => Math.floor(Number(n))).filter(id => {
            if (!known[id] || seen[id]) return false;
            seen[id] = true;
            return true;
        });
        const day = { r: d.r ? 1 : 0, on: ids(d.on), off: ids(d.off), x: [] };
        for (const e of Array.isArray(d.x) ? d.x : []) {
            const name = clean(e && e.n);
            if (name.length === 0) continue;
            const extra = { n: name, d: e.d ? 1 : 0 };
            if (e.q) extra.q = 1;
            day.x.push(extra);
        }
        out.days[key] = day;
    }
    for (const key in given.plan || {}) {
        const names = (Array.isArray(given.plan[key]) ? given.plan[key] : []).map(clean).filter(n => n.length > 0);
        if (KEY.test(key) && names.length > 0) out.plan[key] = names;
    }
    for (const name in given.runs || {}) {
        const run = given.runs[name], n = Math.floor(Number(run && run.n));
        if (run && KEY.test(run.last) && n > 0) out.runs[name] = { last: run.last, n: n };
    }
    for (const field of ["last", "told", "shut"]) if (KEY.test(given[field])) out[field] = given[field];
    return out;
}

// What is written to the settings: the state without its empty parts.
function text(state) {
    const days = {};
    for (const key of Object.keys(state.days).sort()) {
        const d = state.days[key], o = {};
        if (d.r) o.r = 1;
        if (d.on.length > 0) o.on = d.on;
        if (d.off.length > 0) o.off = d.off;
        if (d.x.length > 0) o.x = d.x;
        days[key] = o;
    }
    return JSON.stringify(Object.assign({}, state, { days: days }));
}
function copy(state) { return parse(JSON.stringify(state)); }

// ---- reading ------------------------------------------------------------------------
function active(state) { return state.habits.filter(h => !h.gone); }
function hasHabit(state, name) {
    const k = fold(name);
    return state.habits.some(h => !h.gone && fold(h.name) === k);
}
function listed(day, id) { return day.on.indexOf(id) >= 0 || day.off.indexOf(id) >= 0; }

// The list of a day, the habits in their order and then the extras:
// [{ ref, name, done, extra, asked }]; ref is "h<id>" or "x<index>".
function items(state, key) {
    const day = state.days[key], out = [];
    if (!day) return out;
    for (const h of state.habits) {
        const done = day.on.indexOf(h.id) >= 0;
        if (done || day.off.indexOf(h.id) >= 0) out.push({ ref: "h" + h.id, name: h.name, done: done, extra: false, asked: false });
    }
    day.x.forEach((e, i) => out.push({ ref: "x" + i, name: e.n, done: e.d === 1, extra: true, asked: e.q === 1 }));
    return out;
}
function counts(state, key) {
    const day = state.days[key];
    if (!day) return { done: 0, total: 0 };
    const extrasDone = day.x.filter(e => e.d === 1).length;
    return { done: day.on.length + extrasDone, total: day.on.length + day.off.length + day.x.length };
}

// GitHub's five shades: 0 = nothing done, 1 = up to 25 %, 2 = up to 50 %, 3 = up to 75 %, 4 = more.
function level(done, total) {
    if (!(total > 0) || !(done > 0)) return 0;
    const percent = 100 * done / total;
    return percent <= 25 ? 1 : percent <= 50 ? 2 : percent <= 75 ? 3 : 4;
}
// A day as the calendar shows it: { listed, done, total, level, reviewed, known }.
// `known` = there is something to show a shade for; a day that was neither
// reviewed nor touched is "no data", which is not the same as level 0.
function cell(state, key) {
    const day = state.days[key], c = counts(state, key);
    const reviewed = day !== undefined && day.r === 1;
    return { listed: c.total > 0, done: c.done, total: c.total, level: level(c.done, c.total),
             reviewed: reviewed, known: c.total > 0 && (reviewed || c.done > 0) };
}
// The `count` weeks up to the one `date` is in, oldest first; each is Monday
// to Sunday: { key, date } with cell()'s fields, or null for a day after `date`.
function weeks(state, date, count) {
    const monday = shifted(date, -((date.getDay() + 6) % 7)), today = dayKey(date), out = [];
    for (let w = count - 1; w >= 0; --w) {
        const week = [];
        for (let i = 0; i < 7; ++i) {
            const day = shifted(monday, i - 7 * w), key = dayKey(day);
            week.push(key > today ? null : Object.assign({ key: key, date: day }, cell(state, key)));
        }
        out.push(week);
    }
    return out;
}
// The `days` days up to `date`: how many have something to show, and their average share done (0..1).
function summary(state, date, days) {
    let known = 0, sum = 0;
    for (let i = 0; i < days; ++i) {
        const c = cell(state, dayKey(shifted(date, -i)));
        if (!c.known) continue;
        ++known;
        sum += c.done / c.total;
    }
    return { days: known, average: known > 0 ? sum / known : 0 };
}

// The one-time extras of a day, listed or still planned: their names.
function extrasOf(state, key) {
    const day = state.days[key];
    return (day ? day.x.map(e => e.n) : []).concat(state.plan[key] || []);
}
// The extras of a day the evening has not asked about yet: [{ index, name }].
function unasked(state, key) {
    const day = state.days[key], out = [];
    if (day) day.x.forEach((e, i) => { if (!e.q) out.push({ index: i, name: e.n }); });
    return out;
}

function minutesOf(time) {
    const p = String(time).split(":"), h = Number(p[0]), m = Number(p[1]);
    return p.length === 2 && h >= 0 && h < 24 && m >= 0 && m < 60 ? Math.floor(h) * 60 + Math.floor(m) : 21 * 60 + 30;
}
// The day whose evening review is to be asked at `now`: today from `time`
// ("HH:MM") on, yesterday before that, so a review that was missed (the
// computer was off, asleep or locked) is asked later and still belongs to
// its own day. Only this one day is asked; earlier ones stay not reviewed.
function due(state, now, time) {
    const passed = now.getHours() * 60 + now.getMinutes() >= minutesOf(time);
    const key = dayKey(passed ? now : shifted(now, -1));
    const day = state.days[key];
    return day && !day.r && counts(state, key).total > 0 ? key : "";
}

// ---- changing -----------------------------------------------------------------------
// (helpers on a copy)
function listOf(next, key) {
    if (!next.days[key]) next.days[key] = { r: 0, on: [], off: [], x: [] };
    return next.days[key];
}
function strip(day, id) {
    day.on = day.on.filter(n => n !== id);
    day.off = day.off.filter(n => n !== id);
}
// Habit `id` on the list of `key`; an extra of that name there turns into it,
// and the name is no extra any more.
function place(next, id, name, key) {
    const day = listOf(next, key), k = fold(name);
    const i = day.x.findIndex(e => fold(e.n) === k);
    const done = i >= 0 && day.x[i].d === 1;
    if (i >= 0) day.x.splice(i, 1);
    if (!listed(day, id)) (done ? day.on : day.off).push(id);
}
function forget(next, name) {
    const k = fold(name);
    delete next.runs[k];
    for (const key in next.plan) {
        next.plan[key] = next.plan[key].filter(n => fold(n) !== k);
        if (next.plan[key].length === 0) delete next.plan[key];
    }
}
function prune(next, date) {
    const today = dayKey(date), oldest = dayKey(shifted(date, -KEEP_DAYS)), yesterday = dayKey(shifted(date, -1));
    for (const key in next.days) if (key < oldest) delete next.days[key];
    for (const key in next.plan) if (key < today) delete next.plan[key];
    // a run can only go on from yesterday
    for (const name in next.runs) if (next.runs[name].last < yesterday) delete next.runs[name];
    const keys = Object.keys(next.days);
    next.habits = next.habits.filter(h => !h.gone || keys.some(key => listed(next.days[key], h.id)));
}

// The lists of the days up to `date` that have none yet: the habits and the
// extras planned for the day. Days the computer was off get theirs too, not
// reviewed, so they can be filled in from the calendar later.
function roll(state, date) {
    const today = dayKey(date);
    if (state.last >= today) return state;
    // never used: nothing to make, nothing to write
    if (state.last === "" && state.habits.length === 0 && Object.keys(state.plan).length === 0) return state;
    const next = copy(state), ids = active(next).map(h => h.id);
    const oldest = dayKey(shifted(date, -KEEP_DAYS));
    let key = next.last === "" ? today : keyShift(next.last, 1);
    if (key < oldest) key = oldest;
    for (; key <= today; key = keyShift(key, 1)) {
        const names = next.plan[key] || [];
        delete next.plan[key];
        if (ids.length === 0 && names.length === 0) continue;
        const day = listOf(next, key);
        for (const id of ids) if (!listed(day, id)) day.off.push(id);
        for (const n of names) day.x.push({ n: n, d: 0 });
    }
    next.last = today;
    prune(next, date);
    return next;
}

function finishSetup(state) {
    if (state.setup) return state;
    const next = copy(state);
    next.setup = 1;
    return next;
}
// `field` is "told" or "shut".
function note(state, field, key) {
    if (state[field] === key) return state;
    const next = copy(state);
    next[field] = key;
    return next;
}

// A new permanent habit: on the list of `date` (today) and of every day after it.
function addHabit(state, name, date) {
    const label = clean(name);
    if (label.length === 0 || hasHabit(state, label)) return state;
    // the days that were missed are made first: they do not get the new habit
    const next = copy(roll(state, date)), today = dayKey(date), id = next.next++;
    next.habits.push({ id: id, name: label });
    place(next, id, label, today);
    forget(next, label);
    if (next.last < today) next.last = today;
    return next;
}
// Deleted for good: off the list of `date` (today) and never listed again.
// The days before keep it, with their shades.
function deleteHabit(state, id, date) {
    if (!state.habits.some(h => h.id === id && !h.gone)) return state;
    const next = copy(roll(state, date)), today = dayKey(date);
    for (const key in next.days) if (key >= today) strip(next.days[key], id);
    next.habits.find(h => h.id === id).gone = 1;
    prune(next, date);
    return next;
}
function renameHabit(state, id, name) {
    const label = clean(name), k = fold(label);
    const found = state.habits.find(h => h.id === id && !h.gone);
    if (!found || label.length === 0 || found.name === label) return state;
    if (state.habits.some(h => h.id !== id && !h.gone && fold(h.name) === k)) return state;
    const next = copy(state);
    next.habits.find(h => h.id === id).name = label;
    forget(next, label);
    return next;
}
// The habits in the order of `ids` (those it leaves out keep their order after them).
function orderHabits(state, ids) {
    const rank = h => { const i = ids.indexOf(h.id); return i >= 0 ? i : ids.length; };
    const sorted = state.habits.map((h, i) => ({ h: h, i: i })).sort((a, b) => (rank(a.h) - rank(b.h)) || (a.i - b.i)).map(e => e.h);
    if (sorted.every((h, i) => h.id === state.habits[i].id)) return state;
    const next = copy(state);
    next.habits = sorted.map(h => next.habits.find(n => n.id === h.id));
    return next;
}

function setDone(state, key, ref, done) {
    const day = state.days[key], n = Number(String(ref).slice(1));
    if (!day) return state;
    if (ref[0] === "x") {
        if (!day.x[n] || (day.x[n].d === 1) === done) return state;
        const next = copy(state);
        next.days[key].x[n].d = done ? 1 : 0;
        return next;
    }
    if (!listed(day, n) || (day.on.indexOf(n) >= 0) === done) return state;
    const next = copy(state), d = next.days[key];
    strip(d, n);
    (done ? d.on : d.off).push(n);
    return next;
}
// Off the list of that one day: it does not count there, and a habit is back the next day.
function dropFromDay(state, key, ref) {
    const day = state.days[key], n = Number(String(ref).slice(1));
    if (!day || (ref[0] === "x" ? !day.x[n] : !listed(day, n))) return state;
    const next = copy(state);
    if (ref[0] === "x") next.days[key].x.splice(n, 1);
    else strip(next.days[key], n);
    return next;
}
function review(state, key) {
    if (!state.days[key] || state.days[key].r) return state;
    const next = copy(state);
    next.days[key].r = 1;
    return next;
}

// An extra becomes a permanent habit, listed from `key` on.
function promote(state, name, key) {
    const next = copy(state), id = next.next++;
    next.habits.push({ id: id, name: name });
    for (const d in next.days) if (d >= key) place(next, id, name, d);
    if (key <= next.last) place(next, id, name, key);
    forget(next, name);
    return next;
}
// A one-time extra for the day `key` (the evening review adds them for the
// day after). Its second day in a row makes it a permanent habit from `key`
// on; days that are not in a row start counting again.
function addExtra(state, name, key) {
    const label = clean(name), k = fold(label);
    if (k.length === 0 || hasHabit(state, label) || extrasOf(state, key).some(n => fold(n) === k)) return state;
    const run = state.runs[k];
    const n = run && run.last === keyShift(key, -1) ? run.n + 1 : run && run.last === key ? run.n : 1;
    if (n >= PROMOTE_AFTER) return promote(state, label, key);
    const next = copy(state);
    if (key <= next.last) listOf(next, key).x.push({ n: label, d: 0 });
    else (next.plan[key] = next.plan[key] || []).push(label);
    next.runs[k] = { last: key, n: n };
    return next;
}
// Taken back (it was only just added for `key`).
function dropExtra(state, name, key) {
    const k = fold(name);
    if (!extrasOf(state, key).some(n => fold(n) === k)) return state;
    const next = copy(state), day = next.days[key];
    if (day) day.x = day.x.filter(e => fold(e.n) !== k);
    if (next.plan[key]) {
        next.plan[key] = next.plan[key].filter(n => fold(n) !== k);
        if (next.plan[key].length === 0) delete next.plan[key];
    }
    if (next.runs[k] && next.runs[k].last === key) delete next.runs[k];
    return next;
}
// The evening's question about extra `index` of `key`: the day after as well?
// It is asked once. Yes: a permanent habit from the next day on; no: it is let go.
function answerExtra(state, key, index, again) {
    const day = state.days[key];
    if (!day || !day.x[index] || day.x[index].q) return state;
    const next = copy(state), extra = next.days[key].x[index];
    extra.q = 1;
    return again && !hasHabit(next, extra.n) ? promote(next, extra.n, keyShift(key, 1)) : next;
}
