/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The companion's mind: what it is doing, given what happens around it and
    to it. Rules only: no drawing, no timers, no clock of its own (every
    function is handed the moment), nothing kept beyond the state object, so
    nothing outlives the session. CompanionController.qml runs it; the numbers
    are in CompanionTuning.js (T below).

    Three layers come out of it (view()), so that several things can be true
    at once, e.g. music plays while the AI thinks:

      body       sleep · doze (curling up) · wake (stretching) · sit · listen
                 (music) · curious · perk · cheer · tired · annoyed · pet ·
                 purr (stroked in its sleep) · angry · sulk
      accessory  "" · headphones
      bubble     "" · dots · question · note · exclaim · heart · hiss · zzz
      tilt       the head to the side, eyes up: it thinks, or waits for an answer

    What wins, from the top:
      1. what the user does to it: stroking, anger, sulking, a startled look
      2. what calls for attention for a moment: an event, a timer that ran out
      3. what is going on: music, the AI thinking, a question waiting
      4. sleep
    So an angry cat does not nod to the music (the headphones stay on, the
    nodding comes back when it has calmed down), and one that is stroked in
    its sleep purrs without waking.

    ctx, what is going on (CompanionController hands it in):
      idle       the island shows nothing but the clock
      playing, thinking, asking
      music, thoughts, events   which of those it reacts to at all (settings)
      petting, clicks, noAnger  what the user may do to it (settings)
      sleepAfter, sulkFor       (settings, ms)
      still      motion is reduced: no fidgets
      asleepOnly beside the dot: it sleeps, whatever goes on
*/
.pragma library

function between(range, rnd) { return range[0] + (range[1] - range[0]) * rnd(); }

function start(now, rnd, T) {
    const s = {
        phase: "awake",             // awake | dozing | asleep | waking
        phaseUntil: 0,
        restSince: -1,              // since when nothing has been going on
        mood: "calm",               // calm | angry | sulk
        moodUntil: 0,
        wokenAngry: false,          // it was asleep when it was made angry: back to sleep afterwards
        clicks: [],
        react: "",                  // curious | annoyed | perk | cheer | tired
        reactFrom: 0,
        reactUntil: 0,
        reactTold: true,
        petting: false,
        petLast: 0,
        makeUpSince: -1,
        flash: "",                  // a bubble for a moment: exclaim | note
        flashFrom: 0,
        flashUntil: 0,
        hover: false,
        blinkAt: 0, tailAt: 0, earAt: 0, lickAt: 0
    };
    settle(s, now, rnd, T);
    return s;
}
// The next fidgets, counted from now (it has just come to rest).
function settle(s, now, rnd, T) {
    s.blinkAt = now + between(T.blink, rnd);
    s.tailAt = now + between(T.tail, rnd);
    s.earAt = now + between(T.ear, rnd);
    s.lickAt = now + between(T.lick, rnd);
}

// What of the things going on it cares about.
function roused(ctx) {
    if (ctx.asleepOnly) return false;
    return (ctx.music && ctx.playing) || (ctx.thoughts && (ctx.thinking || ctx.asking)) || (ctx.events && !ctx.idle);
}
function restful(s, ctx, now) {
    return s.mood === "calm" && !s.petting && s.react === "" && (!s.hover || ctx.asleepOnly) && !roused(ctx);
}
function sleeping(s) { return s.phase === "asleep" || s.phase === "dozing"; }

function view(s, ctx, now) {
    const awake = s.phase === "awake";
    const listening = ctx.music && ctx.playing && !ctx.asleepOnly;
    let body;
    if (s.mood === "angry") body = "angry";
    else if (s.mood === "sulk") body = "sulk";
    else if (s.petting) body = s.phase === "asleep" ? "purr" : "pet";
    else if (s.phase === "asleep") body = "sleep";
    else if (s.phase === "dozing") body = "doze";
    else if (s.phase === "waking") body = "wake";
    else if (s.react !== "" && now >= s.reactFrom) body = s.react;
    else if (s.hover) body = "curious";
    else if (listening) body = "listen";
    else body = "sit";

    let bubble = "";
    if (s.mood === "angry") bubble = "hiss";
    else if (s.mood === "sulk") bubble = "";
    else if (s.petting) bubble = "heart";
    else if (s.flash === "exclaim" && now >= s.flashFrom) bubble = "exclaim";
    else if (awake && ctx.thoughts && ctx.asking && !ctx.asleepOnly) bubble = "question";
    else if (awake && ctx.thoughts && ctx.thinking && !ctx.asleepOnly) bubble = "dots";
    else if (s.flash === "note" && now >= s.flashFrom && awake) bubble = "note";
    else if (s.phase === "asleep") bubble = "zzz";

    return {
        body: body,
        accessory: listening && awake ? "headphones" : "",
        bubble: bubble,
        tilt: (bubble === "question" || bubble === "dots") && (body === "sit" || body === "listen")
    };
}

// Time passes. Returns the gestures that begin now (blink, tail, ear, lick, yawn, hop, perk, turn).
function step(s, ctx, now, rnd, T) {
    const out = [];
    while (s.clicks.length > 0 && now - s.clicks[0] >= T.clickWindow) s.clicks.shift();
    if (now - s.petLast >= T.petLinger) { s.petting = false; s.makeUpSince = -1; }

    if (s.mood === "angry" && now >= s.moodUntil) {
        s.mood = "sulk";
        s.moodUntil = s.moodUntil + ctx.sulkFor;
        out.push("turn");
    }
    if (s.mood === "sulk" && now >= s.moodUntil) {
        s.mood = "calm";
        s.clicks = [];
        settle(s, now, rnd, T);
        if (s.wokenAngry && restful(s, ctx, now)) {
            s.phase = "dozing";
            s.phaseUntil = now + T.dozeFor;
            out.push("yawn");
        }
        s.wokenAngry = false;
    }

    if (s.react !== "" && !s.reactTold && now >= s.reactFrom) {
        s.reactTold = true;
        if (s.react === "cheer" || s.react === "curious") out.push("hop");
        else if (s.react === "perk") out.push("perk");
        else if (s.react === "tired") out.push("yawn");
    }
    if (s.react !== "" && now >= s.reactUntil) s.react = "";
    if (s.flash !== "" && now >= s.flashUntil) s.flash = "";

    const rest = restful(s, ctx, now);
    if (s.phase === "awake") {
        if (!rest) s.restSince = -1;
        else if (s.restSince < 0) s.restSince = now;
        if (rest && now - s.restSince >= ctx.sleepAfter) {
            s.phase = "dozing";
            s.phaseUntil = now + T.dozeFor;
            out.push("yawn");
        }
    } else if (s.phase === "dozing") {
        if (!rest) { s.phase = "awake"; s.restSince = -1; settle(s, now, rnd, T); }
        else if (now >= s.phaseUntil) s.phase = "asleep";
    } else if (s.phase === "asleep") {
        if (s.mood === "calm" && roused(ctx)) { s.phase = "waking"; s.phaseUntil = now + T.wakeFor; out.push("stretch"); }
    } else if (now >= s.phaseUntil) {
        s.phase = "awake";
        s.restSince = -1;
        settle(s, now, rnd, T);
    }

    if (fidgets(s, ctx)) {
        const body = view(s, ctx, now).body;
        if (now >= s.blinkAt) { out.push("blink"); s.blinkAt = now + between(T.blink, rnd); }
        if (now >= s.tailAt) { if (body !== "perk") out.push("tail"); s.tailAt = now + between(T.tail, rnd); }
        if (now >= s.earAt) { if (body === "sit" || body === "listen") out.push("ear"); s.earAt = now + between(T.ear, rnd); }
        if (now >= s.lickAt) { if (body === "sit") out.push("lick"); s.lickAt = now + between(T.lick, rnd); }
    }
    return out;
}
// Awake and at ease, and motion is not reduced.
function fidgets(s, ctx) {
    return s.phase === "awake" && s.mood === "calm" && !s.petting && !ctx.still
        && (s.react === "" || s.react === "perk");
}

// The next moment at which step() has something to do; -1: none (asleep, say: nothing runs).
function due(s, ctx, now, T) {
    let at = Infinity;
    const want = t => { if (t < at) at = t; };
    if (s.petting || s.makeUpSince >= 0) want(s.petLast + T.petLinger);
    if (s.mood !== "calm") want(s.moodUntil);
    if (s.react !== "") { if (!s.reactTold) want(s.reactFrom); want(s.reactUntil); }
    if (s.flash !== "") { if (now < s.flashFrom) want(s.flashFrom); want(s.flashUntil); }
    if (s.phase === "dozing" || s.phase === "waking") want(s.phaseUntil);
    if (s.phase === "awake" && restful(s, ctx, now)) want(s.restSince < 0 ? now : s.restSince + ctx.sleepAfter);
    if (s.phase === "asleep" && s.mood === "calm" && roused(ctx)) want(now);
    if (fidgets(s, ctx)) { want(s.blinkAt); want(s.tailAt); want(s.earAt); want(s.lickAt); }
    return at === Infinity ? -1 : Math.max(at, now);
}

// Something calls for it: "perk" (an event, an activity began), "cheer" (a timer ran out, a
// download is done), "tired" (the battery is low), "answer" (the AI's is ready), "note" (music begins).
function notice(s, ctx, now, T, kind) {
    if (ctx.asleepOnly) return;
    if (kind === "answer" ? !ctx.thoughts : kind === "note" ? !ctx.music : !ctx.events) return;
    if (s.mood !== "calm") return;
    if (kind === "tired" && sleeping(s)) return;
    let from = now;
    if (sleeping(s) && kind !== "note") {
        s.phase = "waking";
        s.phaseUntil = now + T.wakeFor;
    }
    if (s.phase === "waking") from = s.phaseUntil;
    if (kind === "note") { s.flash = "note"; s.flashFrom = from; s.flashUntil = from + T.noteFor; return; }
    if (kind === "answer") { s.flash = "exclaim"; s.flashFrom = from; s.flashUntil = from + T.exclaimFor; }
    // (a stroke is not interrupted)
    if (s.petting) return;
    s.react = kind === "answer" ? "perk" : kind;
    s.reactFrom = from;
    s.reactUntil = from + (kind === "cheer" ? T.cheerFor : kind === "tired" ? T.tiredFor : T.perkFor);
    s.reactTold = false;
}

function anger(s, now, T, asleep) {
    s.mood = "angry";
    s.moodUntil = now + T.angryFor;
    s.wokenAngry = asleep;
    s.phase = "awake";
    s.restSince = -1;
    s.react = "";
    s.flash = "";
    s.petting = false;
}

// A click on it. Returns the gestures that begin now.
function click(s, ctx, now, T) {
    if (!ctx.clicks) return [];
    // (sulking: it does not even look)
    if (s.mood === "sulk") return ["shoo"];
    while (s.clicks.length > 0 && now - s.clicks[0] >= T.clickWindow) s.clicks.shift();
    s.clicks.push(now);
    const asleep = sleeping(s) && !s.petting;
    if (ctx.noAnger) {
        if (asleep) { s.phase = "waking"; s.phaseUntil = now + T.wakeFor; }
        s.react = "curious";
        s.reactFrom = s.phase === "waking" ? s.phaseUntil : now;
        s.reactUntil = s.reactFrom + T.startleFor;
        s.reactTold = false;
        return asleep ? ["stretch"] : [];
    }
    if (s.mood === "angry") {
        s.mood = "sulk";
        s.moodUntil = now + ctx.sulkFor;
        return ["turn"];
    }
    if (asleep || s.clicks.length >= T.angryClicks) {
        anger(s, now, T, asleep);
        return ["hop"];
    }
    s.petting = false;
    if (s.phase === "waking") { s.phase = "awake"; s.restSince = -1; }
    s.react = s.clicks.length === T.angryClicks - 1 ? "annoyed" : "curious";
    s.reactFrom = now;
    s.reactUntil = now + (s.react === "annoyed" ? T.annoyedFor : T.startleFor);
    s.reactTold = s.react === "annoyed";
    return s.react === "annoyed" ? ["flinch"] : [];
}

// It is being stroked (strokeFeed() says so).
function stroke(s, ctx, now, T) {
    if (!ctx.petting || s.mood === "angry") return;
    if (s.mood === "sulk") {
        // not at once: only a long, unbroken stroke makes up
        if (s.makeUpSince < 0 || now - s.petLast >= T.petLinger) s.makeUpSince = now;
        s.petLast = now;
        if (now - s.makeUpSince < T.makeUpAfter) return;
        s.mood = "calm";
        s.wokenAngry = false;
        s.makeUpSince = -1;
    }
    s.petting = true;
    s.petLast = now;
    s.clicks = [];
    s.react = "";
    if (s.phase === "dozing" || s.phase === "waking") { s.phase = "awake"; s.restSince = -1; }
}

// The pointer came onto it, or left. Returns the gestures that begin now.
function hover(s, ctx, now, inside) {
    const came = inside && !s.hover;
    s.hover = inside;
    return came && s.mood === "sulk" ? ["shoo"] : [];
}

// ---- telling a stroke from a pointer passing by ----------------------------------------
// The pointer's x over the cat, as it moves. A stroke goes back and forth: a turn is counted
// when the pointer has come back T.petDistance (of the cat's width) from where it last turned.
// T.petTurns turns within T.petWindow are a stroke; once it is one, every further turn is.
// So resting on the cat, crossing it once, trembling on the spot, or wandering slowly are not.
function strokeStart() { return { dir: 0, edge: 0, seen: false, turns: [] }; }
function strokeFeed(d, x, now, width, T, stroking) {
    const far = Math.max(1, width * T.petDistance);
    while (d.turns.length > 0 && now - d.turns[0] >= T.petWindow) d.turns.shift();
    if (!d.seen) { d.seen = true; d.edge = x; return false; }
    if (d.dir === 0) {
        if (Math.abs(x - d.edge) >= far) { d.dir = x > d.edge ? 1 : -1; d.edge = x; }
        return false;
    }
    // further the same way: the edge moves with it
    if ((x - d.edge) * d.dir > 0) { d.edge = x; return false; }
    if (Math.abs(x - d.edge) < far) return false;
    d.dir = -d.dir;
    d.edge = x;
    d.turns.push(now);
    return stroking || d.turns.length >= T.petTurns;
}
