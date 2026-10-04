/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Suggestions: what the island has learned about when a suggestion is
    welcome. Rules and statistics only, local: no network, no model. The
    learning is one small JSON text (SuggestionStore.qml keeps it in a file):

      { v: 2, last, rules: { id: { mode, why, last, row, offered, auto, undos, closed } },
        events: [{ r, c, s, t }], folded: { id: { ctx: { pos, neg, n, imp, days, day, t } } },
        log: [{ t, r, c, undone }], legacy }

    The unit that learns is (rule, context). A context is a few coarse
    buckets joined into a text ("wd|pm|cal:Work|video"): the kind of day, the
    part of the day, the calendar's name, how long the event is, whether it
    has a video link, mains or battery, whether media plays, the kind of
    audio output. Never a window title, an application, an event's title, a
    text or a key press.

    events    the last TUNING.maxEvents signals: rule, context, kind of
              signal, moment. Older ones are folded into decayed sums.
    signal    "yes", "always", "implicit" (the user did it by hand at the
              rule's moment), "no", "later", "timeout", "undo"; and, without a
              weight, "shown" and "auto" (for the counts of the last week)
    mode      "learn" (the model decides), "ask" (always ask), "auto"
              (always do it), "off"; why it is off: "never", "settings",
              "ignored" (from the old data), "experimental"
    offered   contexts in which "shall I do this by myself?" was asked
    auto      contexts in which it is done by itself (since when)
    undos     how often an automatic action was undone, per context
    closed    contexts in which the rule is closed (two undos)
    row       answers that were not a yes, in a row (the wait grows with it)

    How sure it is that the suggestion is welcome (like a Beta estimate):
    a = 1 + the positive weights, b = 1 + the negative ones, each halved
    every `halfLife`; confidence = a / (a + b). With little known about a
    context it is mixed with the rule's estimate over all contexts, so a new
    context does not start from nothing and one "no" does not silence a rule.

    Every function takes the moment it is asked about (ms), so nothing here
    reads the clock; none changes the state it is given.
*/
.pragma library

// The rules the island knows, in the order the settings list them. `timed`: its value is over
// within minutes (it may come as a card); `ends`: what it did is taken back when its cause ends.
const RULES = ["meeting", "meeting-media", "recording", "call", "pomodoro", "battery", "disconnect", "headphones"];
const INFO = {
    "meeting": { action: "dnd", timed: true, ends: true, trigger: "meeting" },
    "meeting-media": { action: "pause", timed: true, ends: false, trigger: "meeting" },
    "recording": { action: "dnd", timed: true, ends: true, trigger: "recording" },
    "call": { action: "pause", timed: true, ends: true, trigger: "call" },
    "pomodoro": { action: "dnd", timed: true, ends: true, trigger: "pomodoro" },
    "battery": { action: "saver", timed: false, ends: true, trigger: "battery" },
    "disconnect": { action: "pause", timed: true, ends: false, trigger: "disconnect" },
    // Its trigger is a guess from a device's name: off until it is switched on.
    "headphones": { action: "play", timed: true, ends: false, trigger: "headphones", experimental: true }
};
// Every number of the model, in one place. See README "Suggestions" for why each is what it is.
const TUNING = {
    weights: { yes: 1, always: 3, implicit: 0.7, no: -1.5, later: -0.4, timeout: -0.15, undo: -3, shown: 0, auto: 0 },
    halfLifeDays: 30,
    silentBelow: 0.25,          // less sure than this: not suggested
    autoFrom: 0.8,              // this sure…
    autoEvents: 4,              // …with this many welcome ones…
    autoDays: 2,                // …on this many different days: "shall I do it by myself?"
    poolBelow: 3,               // less than this known about a context: mixed with the rule's estimate
    implicitOffer: 4,           // done by hand this often at the rule's moment: the same question
    cooldownMinutes: 20,        // a rule's wait after a card; doubles with every answer in a row that is not a yes
    cooldownDoublings: 5,
    dailyCards: 6,
    window: 120000,             // "at the rule's moment": within two minutes of it
    maxEvents: 200,
    maxLog: 50,
    maxPending: 3
};
// The intervention level of the settings changes how soon it stays silent, how many cards a day
// and how long it waits.
const LEVELS = {
    quiet: { silentBelow: 0.35, dailyCards: 2, cooldown: 2 },
    balanced: { silentBelow: 0.25, dailyCards: 6, cooldown: 1 },
    active: { silentBelow: 0.15, dailyCards: 12, cooldown: 0.5 }
};
// The numbers in force: the level's, with what the settings name themselves (0 = the level's).
function tuning(level, dailyCards, cooldownMinutes, halfLifeDays) {
    const l = LEVELS[level] || LEVELS.balanced;
    return {
        silentBelow: l.silentBelow,
        dailyCards: dailyCards > 0 ? dailyCards : l.dailyCards,
        cooldown: (cooldownMinutes > 0 ? cooldownMinutes : TUNING.cooldownMinutes * l.cooldown) * 60000,
        halfLife: (halfLifeDays > 0 ? halfLifeDays : TUNING.halfLifeDays) * 86400000
    };
}
const BALANCED = tuning("balanced", 0, 0, 0);

// ---- contexts --------------------------------------------------------------------------
function dayKey(now) { const d = new Date(now); return d.getFullYear() * 10000 + (d.getMonth() + 1) * 100 + d.getDate(); }
// The coarse buckets of a moment: the kind of day and the part of the day.
function timeFeatures(now) {
    const d = new Date(now), h = d.getHours(), day = d.getDay();
    return { day: day === 0 || day === 6 ? "we" : "wd", part: h >= 5 && h < 11 ? "am" : h < 17 ? "noon" : h < 22 ? "eve" : "night" };
}
function durationBucket(minutes) { return minutes <= 30 ? "short" : minutes <= 90 ? "mid" : "long"; }
// A context as text. Only what is given goes in; a calendar's name is cut and has no "|".
function context(f) {
    const parts = [];
    if (f.day) parts.push(f.day);
    if (f.part) parts.push(f.part);
    if (f.calendar) parts.push("cal:" + String(f.calendar).replace(/[|\n]/g, " ").slice(0, 40));
    if (f.duration) parts.push("dur:" + f.duration);
    if (f.video === true) parts.push("video");
    if (f.power) parts.push(f.power);
    if (f.media === true) parts.push("media");
    if (f.output) parts.push("out:" + f.output);
    return parts.join("|");
}
// …and back, for showing it: { day, part, calendar, duration, video, power, media, output }.
function features(ctx) {
    const f = {};
    for (const p of String(ctx || "").split("|")) {
        if (p === "wd" || p === "we") f.day = p;
        else if (p === "am" || p === "noon" || p === "eve" || p === "night") f.part = p;
        else if (p.indexOf("cal:") === 0) f.calendar = p.slice(4);
        else if (p.indexOf("dur:") === 0) f.duration = p.slice(4);
        else if (p === "video") f.video = true;
        else if (p === "ac" || p === "bat") f.power = p;
        else if (p === "media") f.media = true;
        else if (p.indexOf("out:") === 0) f.output = p.slice(4);
    }
    return f;
}

// ---- the state ---------------------------------------------------------------------------
function empty() { return { v: 2, last: 0, rules: {}, events: [], folded: {}, log: [] }; }
function fresh(id) {
    const experimental = INFO[id] !== undefined && INFO[id].experimental === true;
    return { mode: experimental ? "off" : "learn", why: experimental ? "experimental" : "", last: 0, row: 0, offered: {}, auto: {}, undos: {}, closed: {} };
}
const count = v => Math.max(0, Math.floor(Number(v)) || 0);
function flags(given) {
    const out = {};
    if (given && typeof given === "object") for (const key of Object.keys(given).slice(0, 60)) out[String(key).slice(0, 120)] = count(given[key]);
    return out;
}
// What the first version kept (counters per rule): its answers become what is known about the
// rule in general (the context "*"), its mode is kept, nothing is dropped. The old text stays
// under `legacy`.
function migrate(given) {
    const out = empty();
    out.last = count(given.last);
    for (const id of RULES) {
        const g = given.rules && given.rules[id];
        if (!g || typeof g !== "object") continue;
        const r = fresh(id);
        // (a rule that is experimental now stays off unless it was made automatic by the user)
        r.mode = g.mode === "auto" ? "auto" : g.mode === "off" ? "off" : INFO[id].experimental ? "off" : "learn";
        r.why = r.mode !== "off" ? "" : g.mode !== "off" ? "experimental" : g.why === "never" || g.why === "ignored" ? g.why : "settings";
        r.last = count(g.last);
        if (g.asked) r.offered["*"] = 1;
        out.rules[id] = r;
        const yes = count(g.yes), later = count(g.later);
        if (yes + later > 0) {
            out.folded[id] = { "*": { pos: yes * TUNING.weights.yes, neg: later * -TUNING.weights.later, n: yes, imp: 0, days: Math.min(yes, 2), day: 0,
                                      t: r.last > 0 ? r.last : out.last } };
        }
    }
    out.legacy = JSON.stringify(given).slice(0, 4000);
    return out;
}
function parse(json) {
    let given = null;
    try { given = JSON.parse(json || "{}"); } catch (e) {}
    if (!given || typeof given !== "object") return empty();
    if (given.v !== 2) return given.rules ? migrate(given) : empty();
    const out = empty();
    out.last = count(given.last);
    if (typeof given.legacy === "string") out.legacy = given.legacy.slice(0, 4000);
    for (const id of RULES) {
        const g = given.rules && given.rules[id];
        if (!g || typeof g !== "object") continue;
        const r = fresh(id);
        r.mode = ["learn", "ask", "auto", "off"].indexOf(g.mode) >= 0 ? g.mode : "learn";
        r.why = r.mode === "off" ? (["never", "ignored", "experimental"].indexOf(g.why) >= 0 ? g.why : "settings") : "";
        r.last = count(g.last); r.row = count(g.row);
        r.offered = flags(g.offered); r.auto = flags(g.auto); r.undos = flags(g.undos); r.closed = flags(g.closed);
        out.rules[id] = r;
        const f = given.folded && given.folded[id];
        if (f && typeof f === "object") {
            out.folded[id] = {};
            for (const ctx of Object.keys(f).slice(0, 60)) {
                const x = f[ctx] || {};
                out.folded[id][ctx] = { pos: Math.max(0, Number(x.pos) || 0), neg: Math.max(0, Number(x.neg) || 0), n: count(x.n), imp: count(x.imp),
                                        days: count(x.days), day: count(x.day), t: count(x.t) };
            }
        }
    }
    if (Array.isArray(given.events)) {
        for (const e of given.events.slice(-TUNING.maxEvents)) {
            if (e && INFO[e.r] !== undefined && TUNING.weights[e.s] !== undefined) out.events.push({ r: e.r, c: String(e.c || "").slice(0, 120), s: e.s, t: count(e.t) });
        }
    }
    if (Array.isArray(given.log)) {
        for (const l of given.log.slice(-TUNING.maxLog)) {
            if (l && INFO[l.r] !== undefined) out.log.push({ t: count(l.t), r: l.r, c: String(l.c || "").slice(0, 120), undone: l.undone ? 1 : 0 });
        }
    }
    return out;
}
function text(state) { return JSON.stringify(state); }
function copy(state) { return parse(JSON.stringify(state)); }
function rule(state, id) { return state.rules[id] !== undefined ? state.rules[id] : fresh(id); }
function touched(state, id) {
    const next = copy(state);
    if (next.rules[id] === undefined) next.rules[id] = fresh(id);
    return next;
}

// ---- what is known ------------------------------------------------------------------------
function decay(age, halfLife) { return age <= 0 ? 1 : Math.pow(0.5, age / halfLife); }
// The sums of a rule's signals, in one context (ctx) or in all (ctx === null), as they count at `now`.
function sums(state, id, ctx, now, halfLife) {
    let pos = 0, neg = 0, raw = 0, n = 0, imp = 0, last5 = [];
    const days = {};
    for (const e of state.events) {
        if (e.r !== id || (ctx !== null && e.c !== ctx)) continue;
        const w = TUNING.weights[e.s];
        if (w === 0) continue;
        const d = decay(now - e.t, halfLife);
        raw += Math.abs(w);
        if (w > 0) { pos += w * d; n += 1; days[dayKey(e.t)] = true; if (e.s === "implicit") imp += 1; }
        else neg += -w * d;
        if (e.s === "yes" || e.s === "always" || e.s === "no" || e.s === "later") last5.push(e.s === "yes" || e.s === "always");
    }
    let dayCount = Object.keys(days).length;
    const folded = state.folded[id] || {};
    for (const key in folded) {
        if (ctx !== null && key !== ctx) continue;
        const f = folded[key], d = decay(now - f.t, halfLife);
        pos += f.pos * d; neg += f.neg * d; raw += f.pos + f.neg; n += f.n; imp += f.imp; dayCount += f.days;
    }
    // `known`: how much was ever said here; it does not fade (how much is known is not how much it still counts)
    return { pos: pos, neg: neg, weight: pos + neg, known: raw, n: n, implicit: imp, days: dayCount, answers: last5.slice(-5) };
}
// How sure it is that the rule's suggestion is welcome in this context.
function estimate(state, id, ctx, now, t) {
    t = t || BALANCED;
    const own = sums(state, id, ctx, now, t.halfLife), all = sums(state, id, null, now, t.halfLife);
    const ownC = (1 + own.pos) / (2 + own.pos + own.neg), allC = (1 + all.pos) / (2 + all.pos + all.neg);
    const share = Math.min(1, own.known / TUNING.poolBelow);
    return { confidence: share * ownC + (1 - share) * allC, own: ownC, general: allC, weight: own.weight, positives: own.n, implicit: own.implicit,
             days: own.days, answers: own.answers, pooled: share < 1 };
}
// What the rule does in this context now: "off", "silent" (not suggested), "ask", "offer" (ask
// whether to do it by itself from now on) or "auto".
function status(state, id, ctx, now, t) {
    t = t || BALANCED;
    const r = rule(state, id);
    if (r.mode === "off" || r.closed[ctx]) return "off";
    if (r.mode === "auto" || r.auto[ctx]) return "auto";
    if (r.mode === "ask") return "ask";
    const e = estimate(state, id, ctx, now, t);
    if (!r.offered[ctx]) {
        if (e.implicit >= TUNING.implicitOffer) return "offer";
        if (e.confidence >= TUNING.autoFrom && e.positives >= TUNING.autoEvents && e.days >= TUNING.autoDays) return "offer";
    }
    return e.confidence < t.silentBelow ? "silent" : "ask";
}
// Why it is suggested, for the "Why?" line: { kind: "hand", n } done by hand n times here;
// { kind: "answers", yes, of } the last answers here; { kind: "similar" } little is known here,
// it goes by the rule in general; { kind: "new" } nothing is known yet.
function why(state, id, ctx, now, t) {
    const e = estimate(state, id, ctx, now, t || BALANCED);
    if (e.implicit >= 2 && e.implicit >= e.answers.length) return { kind: "hand", n: e.implicit };
    if (e.answers.length >= 2) return { kind: "answers", yes: e.answers.filter(a => a).length, of: e.answers.length };
    const all = sums(state, id, null, now, (t || BALANCED).halfLife);
    return all.weight >= 1 ? { kind: "similar", welcome: e.general >= 0.5 } : { kind: "new" };
}

// ---- what happens --------------------------------------------------------------------------
// Older signals than the last maxEvents become sums: what they weigh is kept, when they were not.
function fold(state, halfLife) {
    while (state.events.length > TUNING.maxEvents) {
        const e = state.events.shift(), w = TUNING.weights[e.s];
        if (w === 0) continue;
        if (state.folded[e.r] === undefined) state.folded[e.r] = {};
        const f = state.folded[e.r][e.c] || { pos: 0, neg: 0, n: 0, imp: 0, days: 0, day: 0, t: e.t };
        const at = Math.max(f.t, e.t), fd = decay(at - f.t, halfLife), ed = decay(at - e.t, halfLife);
        f.pos = f.pos * fd + (w > 0 ? w * ed : 0);
        f.neg = f.neg * fd + (w < 0 ? -w * ed : 0);
        if (w > 0) { f.n += 1; if (e.s === "implicit") f.imp += 1; if (dayKey(e.t) !== f.day) { f.days += 1; f.day = dayKey(e.t); } }
        f.t = at;
        state.folded[e.r][e.c] = f;
    }
}
// A signal about (rule, context) at `now`: an answer, "implicit", "shown", "auto", "undo".
// { state, closed (the context was closed by a second undo) }
function record(state, id, ctx, signal, now, t) {
    t = t || BALANCED;
    if (INFO[id] === undefined || TUNING.weights[signal] === undefined) return { state: state, closed: false };
    const next = touched(state, id), r = next.rules[id];
    let closed = false;
    next.events.push({ r: id, c: ctx, s: signal, t: now });
    if (signal === "shown") { r.last = now; next.last = now; }
    else if (signal === "yes" || signal === "always" || signal === "implicit") r.row = 0;
    else if (signal === "no" || signal === "later" || signal === "timeout") r.row += 1;
    if (signal === "always") { r.auto[ctx] = now; r.offered[ctx] = 1; }
    if (signal === "undo") {
        // taken back: it asks again here; the second time the rule is closed here
        delete r.auto[ctx];
        delete r.offered[ctx];
        if (r.mode === "auto") r.mode = "learn";
        r.undos[ctx] = (r.undos[ctx] || 0) + 1;
        if (r.undos[ctx] >= 2) { r.closed[ctx] = 1; closed = true; }
        for (let i = next.log.length - 1; i >= 0; --i) if (next.log[i].r === id && next.log[i].c === ctx && !next.log[i].undone) { next.log[i].undone = 1; break; }
    }
    if (signal === "auto") {
        next.log.push({ t: now, r: id, c: ctx, undone: 0 });
        if (next.log.length > TUNING.maxLog) next.log = next.log.slice(-TUNING.maxLog);
    }
    fold(next, t.halfLife);
    return { state: next, closed: closed };
}
// The answer to "shall I do this by myself from now on?" in a context: it is asked there once.
function automatic(state, id, ctx, accept, now) {
    const next = touched(state, id), r = next.rules[id];
    r.offered[ctx] = 1;
    if (accept && r.mode !== "off") r.auto[ctx] = now;
    return next;
}
// How long the rule still waits before another card (ms): its wait after the last one, doubled
// with every answer in a row that was not a yes; and `gap` after the last card of any rule.
function waits(state, id, now, t, gap) {
    t = t || BALANCED;
    const r = rule(state, id);
    const own = r.last > 0 ? r.last + t.cooldown * Math.pow(2, Math.min(r.row, TUNING.cooldownDoublings)) - now : 0;
    const any = state.last > 0 ? state.last + (gap || 0) - now : 0;
    return Math.max(0, own, any);
}
// Cards shown on the day of `now`.
function cardsToday(state, now) {
    const day = dayKey(now);
    return state.events.filter(e => e.s === "shown" && dayKey(e.t) === day).length;
}
// The last seven days: shown, accepted (yes, always), done automatically.
function week(state, now) {
    const out = { shown: 0, accepted: 0, automatic: 0 };
    for (const e of state.events) {
        if (now - e.t > 7 * 86400000) continue;
        if (e.s === "shown") out.shown += 1; else if (e.s === "yes" || e.s === "always") out.accepted += 1; else if (e.s === "auto") out.automatic += 1;
    }
    return out;
}
// The contexts something is known about, for the settings: [{ ctx, status, confidence }].
function contexts(state, id, now, t) {
    const seen = {};
    for (const e of state.events) if (e.r === id && TUNING.weights[e.s] !== 0) seen[e.c] = true;
    for (const key in (state.folded[id] || {})) if (key !== "*") seen[key] = true;
    const r = rule(state, id);
    for (const key in r.auto) seen[key] = true;
    for (const key in r.closed) seen[key] = true;
    return Object.keys(seen).sort().map(ctx => ({ ctx: ctx, status: status(state, id, ctx, now, t), confidence: estimate(state, id, ctx, now, t).confidence }));
}

// ---- the settings ---------------------------------------------------------------------------
// "learn", "ask", "auto" or "off". Switching a rule on again opens what was closed.
function setMode(state, id, mode) {
    const r = rule(state, id);
    if (r.mode === mode || ["learn", "ask", "auto", "off"].indexOf(mode) < 0) return state;
    const next = touched(state, id), n = next.rules[id];
    n.mode = mode;
    n.why = mode === "off" ? "settings" : "";
    if (mode !== "off") { n.row = 0; n.closed = {}; }
    return next;
}
// The answer "turn this rule off".
function never(state, id) {
    const next = touched(state, id);
    next.rules[id].mode = "off";
    next.rules[id].why = "never";
    return next;
}
// What was learned in one context is forgotten.
function forget(state, id, ctx) {
    const next = touched(state, id), r = next.rules[id];
    next.events = next.events.filter(e => !(e.r === id && e.c === ctx));
    if (next.folded[id]) delete next.folded[id][ctx];
    delete r.offered[ctx]; delete r.auto[ctx]; delete r.undos[ctx]; delete r.closed[ctx];
    return next;
}
// What was learned about one rule is forgotten (its place in the log stays).
function reset(state, id) {
    const next = copy(state);
    delete next.rules[id];
    delete next.folded[id];
    next.events = next.events.filter(e => e.r !== id);
    return next;
}
