#!/usr/bin/env node
// The companion's mind (contents/ui/companion/Companion.js, CompanionTuning.js): the moment is
// handed in and so is chance, so nothing here reads the clock or waits.
// Run by tools/run-tests; tests/tst_companion.qml runs the controller and the cat on the island.
"use strict";
const fs = require("fs");
const path = require("path");

const DIR = path.join(__dirname, "..", "org.phobby.dynamicisland", "contents", "ui", "companion");
function load(file) {
    const source = fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*$/m, "");
    const names = Array.from(source.matchAll(/^(?:function|const) (\w+)[ (=]/gm), m => m[1]);
    return new Function(source + "\nreturn { " + names.join(", ") + " };")();
}
const C = load(path.join(DIR, "Companion.js"));
const T = load(path.join(DIR, "CompanionTuning.js")).TUNING;

let failed = 0, checked = 0;
function check(what, got, want) {
    ++checked;
    const g = JSON.stringify(got), w = JSON.stringify(want);
    if (g === w) return;
    ++failed;
    console.log(`FAILED ${what}\n   got  ${g}\n   want ${w}`);
}

// A cat with its own clock: at(ms) lets time pass, doing what falls due on the way.
function cat(settings) {
    const k = {
        now: 1000000, seed: 7, gestures: [], steps: 0,
        ctx: Object.assign({ idle: true, playing: false, thinking: false, asking: false, asleepOnly: false,
                             music: true, thoughts: true, events: true, petting: true, clicks: true, noAnger: false,
                             still: false, sleepAfter: 20000, sulkFor: 10000 }, settings || {}),
        rnd() { k.seed = (k.seed * 1103515245 + 12345) % 2147483648; return k.seed / 2147483648; }
    };
    k.s = C.start(k.now, k.rnd, T);
    k.run = () => { ++k.steps; k.gestures.push(...C.step(k.s, k.ctx, k.now, k.rnd, T)); };
    k.pass = ms => {
        const end = k.now + ms;
        for (let guard = 0; guard < 100000; ++guard) {
            const due = C.due(k.s, k.ctx, k.now, T);
            if (due < 0 || due > end) break;
            k.now = Math.max(due, k.now);
            k.run();
            if (C.due(k.s, k.ctx, k.now, T) === k.now) k.now += 1;      // never the same moment twice
        }
        k.now = end;
        k.run();
        return k;
    };
    k.set = changes => { Object.assign(k.ctx, changes); k.run(); return k; };
    k.view = () => C.view(k.s, k.ctx, k.now);
    k.body = () => k.view().body;
    k.all = () => { const v = k.view(); return [v.body, v.accessory, v.bubble, v.tilt]; };
    k.notice = kind => { C.notice(k.s, k.ctx, k.now, T, kind); k.run(); return k; };
    k.click = () => { k.gestures.push(...C.click(k.s, k.ctx, k.now, T)); k.run(); return k; };
    k.stroke = () => { C.stroke(k.s, k.ctx, k.now, T); k.run(); return k; };
    k.hover = inside => { k.gestures.push(...C.hover(k.s, k.ctx, k.now, inside)); k.run(); return k; };
    // stroked for a while: a turn of the hand every 300 ms
    k.strokeFor = ms => { for (let t = 0; t < ms; t += 300) { k.stroke(); k.pass(300); } return k; };
    k.took = name => { const n = k.gestures.filter(g => g === name).length; return n; };
    k.forget = () => { k.gestures = []; return k; };
    k.asleep = () => { k.pass(k.ctx.sleepAfter + T.dozeFor + 10); return k; };
    k.run();
    return k;
}

// ---- nothing goes on: it falls asleep, and then nothing runs --------------------------------
{
    const k = cat();
    check("at first it sits", k.all(), ["sit", "", "", false]);
    k.pass(19900);
    check("not yet asleep", k.body(), "sit");
    k.pass(200);
    check("it yawns and curls up", [k.body(), k.took("yawn")], ["doze", 1]);
    k.pass(T.dozeFor);
    check("asleep, with its zzz", k.all(), ["sleep", "", "zzz", false]);
    check("a sleeping cat has nothing due", C.due(k.s, k.ctx, k.now, T), -1);
    const steps = k.steps;
    k.pass(3600000);
    check("an hour later: still asleep, and nothing was run for it", [k.body(), k.steps - steps], ["sleep", 1]);
}
// the setting
{
    const k = cat({ sleepAfter: 5000 });
    k.pass(5000 + T.dozeFor + 1);
    check("sleepAfter is the setting's", k.body(), "sleep");
}

// ---- awake and at ease: it fidgets, rarely, and never in a loop ------------------------------
{
    const k = cat({ idle: false });                 // something is on the island for an hour: it stays awake
    k.pass(3600000);
    check("it stays awake while the island is busy", k.body(), "sit");
    const blinks = k.took("blink"), tails = k.took("tail"), ears = k.took("ear"), licks = k.took("lick");
    check("it blinks every few seconds", blinks > 3600000 / T.blink[1] - 2 && blinks < 3600000 / T.blink[0] + 2, true);
    check("its tail moves now and then", tails > 3600000 / T.tail[1] - 2 && tails < 3600000 / T.tail[0] + 2, true);
    check("an ear twitches now and then", ears > 3600000 / T.ear[1] - 2 && ears < 3600000 / T.ear[0] + 2, true);
    check("it licks a paw, rarely", licks >= 3600000 / T.lick[1] - 2 && licks <= 3600000 / T.lick[0] + 2, true);
    check("one step per fidget, no more", k.steps < blinks + tails + ears + licks + 10, true);
}
{
    const k = cat({ idle: false, still: true });
    k.pass(600000);
    check("motion reduced: no fidgets", k.gestures, []);
    check("and nothing due", C.due(k.s, k.ctx, k.now, T), -1);
}

// ---- something happens: it wakes ---------------------------------------------------------------
{
    const k = cat().asleep().forget();
    k.set({ idle: false });                         // a timer was started
    check("it wakes with a stretch", [k.body(), k.took("stretch")], ["wake", 1]);
    k.pass(T.wakeFor);
    check("and sits", k.body(), "sit");
    k.set({ idle: true }).pass(19000);
    check("the island is empty again: awake for a while yet", k.body(), "sit");
    k.pass(1000 + T.dozeFor + 10);
    check("then back to sleep", k.body(), "sleep");
}
{
    const k = cat().asleep().forget();
    k.notice("perk");                               // a notification
    check("an event wakes it", k.body(), "wake");
    k.pass(T.wakeFor);
    check("then it pricks its ears", [k.body(), k.took("perk")], ["perk", 1]);
    k.pass(T.perkFor);
    check("and sits again", k.body(), "sit");
}
{
    const k = cat({ idle: false }).forget();
    k.notice("cheer");
    check("a timer ran out: a happy hop", [k.body(), k.took("hop")], ["cheer", 1]);
    k.pass(T.cheerFor);
    check("then as before", k.body(), "sit");
    k.notice("tired");
    check("low battery: a yawn", [k.body(), k.took("yawn")], ["tired", 1]);
    k.pass(T.tiredFor);
    check("then as before", k.body(), "sit");
}
{
    const k = cat().asleep().forget();
    k.notice("tired");
    check("a low battery does not wake it", k.body(), "sleep");
    k.set({ events: false, idle: false });
    check("events switched off: it sleeps through them", k.body(), "sleep");
    k.notice("perk"); k.notice("cheer");
    check("all of them", [k.body(), k.gestures], ["sleep", []]);
}

// ---- music: headphones on, nodding; off when it stops ---------------------------------------------
{
    const k = cat({ idle: false, playing: true });
    check("music: it listens, headphones on", k.all().slice(0, 2), ["listen", "headphones"]);
    k.set({ playing: false });
    check("the music stops: headphones off", k.all(), ["sit", "", "", false]);
}
{
    const k = cat().asleep().forget();
    k.set({ playing: true, idle: false });
    check("music wakes it; the headphones come once it is up", k.all(), ["wake", "", "", false]);
    k.pass(T.wakeFor);
    check("then it listens", k.all().slice(0, 2), ["listen", "headphones"]);
    k.pass(3600000);
    check("as long as the music plays", k.body(), "listen");
    k.set({ playing: false, idle: true });
    k.asleep();
    check("and sleeps once it is quiet", k.all(), ["sleep", "", "zzz", false]);
}
{
    const k = cat({ idle: false });
    k.set({ playing: true }); k.notice("note");
    check("music begins: a note for a moment", k.all(), ["listen", "headphones", "note", false]);
    k.pass(T.noteFor);
    check("then only the nodding", k.all(), ["listen", "headphones", "", false]);
}
{
    const k = cat({ idle: false, playing: true, music: false });
    check("music switched off in the settings: nothing of it", k.all(), ["sit", "", "", false]);
    k.notice("note");
    check("no note either", k.view().bubble, "");
}

// ---- the layers together: music and the AI at once ---------------------------------------------
{
    const k = cat({ idle: false, playing: true });
    k.set({ thinking: true });
    check("music and thinking: nodding, headphones, dots, head to the side", k.all(), ["listen", "headphones", "dots", true]);
    k.set({ thinking: false }); k.notice("answer");
    check("the answer is ready: !", [k.view().accessory, k.view().bubble], ["headphones", "exclaim"]);
    k.pass(T.exclaimFor + T.perkFor);
    check("then the music again", k.all(), ["listen", "headphones", "", false]);
}
{
    const k = cat({ idle: false });
    k.set({ thinking: true });
    check("thinking: dots and a tilted head", k.all(), ["sit", "", "dots", true]);
    k.set({ asking: true });
    check("a question waits: it comes before the dots", k.all(), ["sit", "", "question", true]);
    k.set({ asking: false, thinking: false });
    check("answered: the bubble is gone", k.all(), ["sit", "", "", false]);
}
{
    const k = cat().asleep();
    k.set({ asking: true });
    check("a question wakes it", k.all(), ["wake", "", "", false]);
    k.pass(T.wakeFor);
    check("and then it asks", k.all(), ["sit", "", "question", true]);
    k.pass(600000);
    check("for as long as the question waits", k.all(), ["sit", "", "question", true]);
    k.set({ asking: false }).asleep();
    check("its time ran out: gone, and asleep again", k.all(), ["sleep", "", "zzz", false]);
}
{
    const k = cat({ idle: false, thoughts: false, thinking: true, asking: true });
    check("thoughts switched off: no bubble", k.all(), ["sit", "", "", false]);
    k.notice("answer");
    check("no ! either", k.view().bubble, "");
}

// ---- clicks ------------------------------------------------------------------------------
{
    const k = cat().asleep().forget();
    k.click();
    check("clicked awake: angry at once, with a start", [k.all(), k.took("hop")], [["angry", "", "hiss", false], 1]);
    k.pass(T.angryFor - 10);
    check("still angry", k.body(), "angry");
    k.pass(20);
    check("then it turns its back", [k.body(), k.view().bubble, k.took("turn")], ["sulk", "", 1]);
    k.pass(k.ctx.sulkFor - 20);
    check("for the time of the setting", k.body(), "sulk");
    k.pass(30);
    check("and curls up again without waiting", k.body(), "doze");
    k.pass(T.dozeFor);
    check("asleep", k.body(), "sleep");
}
{
    const k = cat({ idle: false }).forget();
    k.click();
    check("one click, awake: startled, not angry", [k.body(), k.took("hop")], ["curious", 1]);
    k.pass(T.startleFor);
    check("and over", k.body(), "sit");
    k.pass(5000).forget();
    k.click(); k.pass(600); k.click();
    check("the second in a row: annoyed", [k.body(), k.took("flinch")], ["annoyed", 1]);
    k.pass(600); k.click();
    check("the third: angry", k.all(), ["angry", "", "hiss", false]);
    k.pass(T.angryFor);
    check("then it sulks", k.body(), "sulk");
    k.forget();
    k.click(); k.click(); k.click(); k.click();
    check("a sulking cat takes no click", [k.body(), k.took("hop")], ["sulk", 0]);
    k.pass(k.ctx.sulkFor);
    check("after its time it is itself again", k.body(), "sit");
    k.click();
    check("and a click only startles it", k.body(), "curious");
}
{
    const k = cat({ idle: false });
    k.click(); k.pass(3100); k.click(); k.pass(3100); k.click();
    check("three clicks with time between them are three single clicks", k.body(), "curious");
}
{
    const k = cat({ idle: false });
    k.click(); k.click(); k.click();
    k.click();
    check("a click on the angry cat: it turns away at once", k.body(), "sulk");
}
{
    const k = cat({ idle: false, sulkFor: 4000 });
    k.click(); k.click(); k.click(); k.pass(T.angryFor); k.pass(3900);
    check("sulkFor is the setting's", k.body(), "sulk");
    k.pass(200);
    check("…and over then", k.body(), "sit");
}
{
    const k = cat({ noAnger: true }).asleep().forget();
    k.click();
    check("never angry: a click wakes it gently", [k.body(), k.took("stretch")], ["wake", 1]);
    k.pass(T.wakeFor);
    check("and it looks", k.body(), "curious");
    for (let i = 0; i < 10; ++i) { k.click(); k.pass(200); }
    check("however often", k.body(), "curious");
    k.pass(T.startleFor);
    check("then it sits", k.body(), "sit");
}
{
    const k = cat({ clicks: false }).asleep().forget();
    k.click(); k.click(); k.click();
    check("clicks switched off: it sleeps on", [k.body(), k.gestures], ["sleep", []]);
}

// ---- what wins: the user's doing, then the moment's, then what goes on ------------------------------
{
    const k = cat({ idle: false, playing: true });
    k.click(); k.click(); k.click();
    check("angry with music playing: no nodding, the headphones stay", k.all(), ["angry", "headphones", "hiss", false]);
    k.set({ thinking: true });
    check("nor dots", k.view().bubble, "hiss");
    k.pass(T.angryFor);
    check("sulking: nothing in the bubble", k.all(), ["sulk", "headphones", "", false]);
    k.notice("cheer"); k.notice("perk");
    check("no event moves it", k.body(), "sulk");
    k.pass(k.ctx.sulkFor);
    check("calm again: the music and the dots are back", k.all(), ["listen", "headphones", "dots", true]);
}
{
    const k = cat({ idle: false, playing: true });
    k.hover(true);
    check("the pointer on it: it looks, the nodding waits", k.all().slice(0, 2), ["curious", "headphones"]);
    k.hover(false);
    check("gone: nodding again", k.body(), "listen");
    k.notice("cheer");
    check("an event comes before the music", k.body(), "cheer");
    k.stroke();
    check("and a stroke before the event", k.body(), "pet");
}

// ---- stroking ---------------------------------------------------------------------------------
{
    const k = cat({ idle: false });
    k.stroke();
    check("stroked: eyes closed, a heart", k.all(), ["pet", "", "heart", false]);
    k.pass(T.petLinger - 100);
    check("a moment after the hand stopped: still", k.body(), "pet");
    k.pass(200);
    check("then as before", k.all(), ["sit", "", "", false]);
}
{
    const k = cat().asleep().forget();
    k.strokeFor(3000);
    check("stroked in its sleep: it purrs and does not wake", [k.all(), k.s.phase], [["purr", "", "heart", false], "asleep"]);
    k.pass(T.petLinger + 10);
    check("the hand is gone: asleep as it was", [k.all(), k.gestures], [["sleep", "", "zzz", false], []]);
}
{
    const k = cat({ idle: false });
    k.click(); k.click();
    k.stroke();
    k.pass(T.petLinger + 10);
    k.click();
    check("a stroke takes the annoyance away: the next click is a first one", k.body(), "curious");
}
{
    const k = cat({ idle: false });
    k.click(); k.click(); k.click(); k.pass(T.angryFor + 100);
    k.stroke();
    check("sulking: a stroke is not taken at once", k.all(), ["sulk", "", "", false]);
    k.strokeFor(T.makeUpAfter - 600);
    check("nor a short one", k.body(), "sulk");
    k.pass(T.petLinger + 100);
    k.strokeFor(1200);
    check("broken off and begun again: counted from the start", k.body(), "sulk");
    k.strokeFor(T.makeUpAfter);
    check("a long one makes up", k.all(), ["pet", "", "heart", false]);
    k.pass(T.petLinger + 10);
    check("and it is itself again, well before its time", [k.body(), k.now - 1000000 < T.angryFor + 100 + k.ctx.sulkFor], ["sit", true]);
}
{
    const k = cat({ idle: false });
    k.click(); k.click(); k.click();
    k.strokeFor(4000);
    check("an angry cat is not to be stroked: it sulks", k.body(), "sulk");
}
{
    const k = cat({ idle: false, petting: false });
    k.stroke();
    check("stroking switched off", k.body(), "sit");
}
{
    const k = cat({ idle: false });
    k.hover(true);
    check("the pointer resting on it: a look, no more", k.all(), ["curious", "", "", false]);
    k.pass(60000);
    check("however long", k.body(), "curious");
    k.hover(false);
    check("gone", k.body(), "sit");
}
{
    const k = cat().asleep().forget();
    k.hover(true); k.pass(30000);
    check("the pointer on a sleeping cat: it sleeps", [k.body(), k.gestures], ["sleep", []]);
}
{
    const k = cat({ idle: false });
    k.click(); k.click(); k.click(); k.pass(T.angryFor + 10); k.forget();
    k.hover(true);
    check("the pointer on the sulking cat: go away, says the tail", [k.body(), k.took("shoo")], ["sulk", 1]);
}

// ---- telling a stroke from a pointer passing by --------------------------------------------------
{
    const W = 50;
    // the pointer at x every `gap` ms: does it become a stroke?
    const feed = (xs, gap) => { const d = C.strokeStart(); let t = 0, yes = false; for (const x of xs) { yes = C.strokeFeed(d, x, t, W, T, yes) || yes; t += gap; } return yes; };
    const sweep = (from, to, n) => Array.from({ length: n }, (_, i) => from + (to - from) * i / (n - 1));
    const rub = (turns, far, n) => { let xs = []; for (let i = 0; i <= turns; ++i) xs = xs.concat(i % 2 ? sweep(25 + far, 25 - far, n) : sweep(25 - far, 25 + far, n)); return xs; };
    check("back and forth: a stroke", feed(rub(4, 12, 8), 25), true);
    check("resting on it: none", feed(Array(200).fill(25), 25), false);
    check("passing over it once: none", feed(sweep(0, 50, 40), 10), false);
    check("there and back once: none", feed(rub(1, 20, 10), 20), false);
    check("back and forth, but slowly: none", feed(rub(6, 12, 8), 120), false);
    check("trembling on the spot: none", feed(rub(40, 2, 3), 15), false);
    check("just under the distance: none", feed(rub(8, W * T.petDistance / 2 - 1, 8), 20), false);
    check("just over it: a stroke", feed(rub(8, W * T.petDistance / 2 + 1.5, 8), 20), true);
    // one turn fewer than asked for
    check("one turn too few: none", feed(rub(T.petTurns - 1, 12, 8), 25), false);
    // once it is one, a single turn keeps it one
    const d = C.strokeStart();
    let t = 0, now = false;
    for (const x of rub(4, 12, 8)) { now = C.strokeFeed(d, x, t, W, T, false) || now; t += 25; }
    t += 1000;
    let again = false;
    for (const x of sweep(13, 37, 8).concat(sweep(37, 13, 8))) { again = C.strokeFeed(d, x, t, W, T, true) || again; t += 25; }
    check("stroking already: one more turn of the hand goes on with it", [now, again], [true, true]);
}

// ---- beside the dot: it sleeps, whatever goes on ----------------------------------------------------
{
    const k = cat({ asleepOnly: true, sleepAfter: 0, idle: false, playing: true, thinking: true, asking: true });
    k.pass(T.dozeFor + 10);
    check("asleep whatever goes on, no headphones, no thoughts", k.all(), ["sleep", "", "zzz", false]);
    k.notice("perk"); k.notice("cheer"); k.notice("answer");
    check("no event wakes it", k.body(), "sleep");
    check("and nothing is due", C.due(k.s, k.ctx, k.now, T), -1);
    k.click();
    check("a click does", k.body(), "angry");
    k.pass(T.angryFor + k.ctx.sulkFor + T.dozeFor + 20);
    check("then it sleeps again", k.body(), "sleep");
}

// ---- a thousand changes: nothing piles up ---------------------------------------------------------
{
    const k = cat({ idle: false });
    for (let i = 0; i < 1000; ++i) {
        k.set({ playing: i % 2 === 0, thinking: i % 3 === 0, asking: i % 5 === 0, idle: i % 7 === 0 });
        if (i % 4 === 0) k.click();
        if (i % 6 === 0) k.stroke();
        if (i % 9 === 0) k.notice(["perk", "cheer", "tired", "answer", "note"][i % 5]);
        k.hover(i % 2 === 1);
        k.pass(137);
    }
    check("the state stays small", [k.s.clicks.length <= T.angryClicks + 1, Object.keys(k.s).length, JSON.stringify(k.s).length < 600], [true, 22, true]);
    check("and every body it showed is one it knows", ["sleep", "doze", "wake", "sit", "listen", "curious", "perk", "cheer", "tired", "annoyed", "pet", "purr", "angry", "sulk"].indexOf(k.body()) >= 0, true);
}

console.log(failed === 0 ? `${checked} checks passed` : `${failed} of ${checked} checks FAILED`);
process.exit(failed === 0 ? 0 : 1);
