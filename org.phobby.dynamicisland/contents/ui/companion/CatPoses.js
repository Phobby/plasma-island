/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The cat's poses, as numbers. CatCharacter.qml draws the cat from one set
    of them (compose() below), so every frame of every animation is a pure
    function of: the pose it comes from, the pose it goes to and how far it
    is between them; the gesture that plays and how far that is; the motion
    that repeats and its phase; where it looks. The gallery sets those by
    hand to show any frame; nothing here knows about time.

    The drawing is the island's own: a round, front-facing sitting cat made
    of ellipses (torso, haunches, head), two ears, a tail drawn as one thick
    curve, two paws, and a face of a few strokes.

    Units: the design canvas is W × H, the cat sits at its bottom, its tail on
    the left. Angles are degrees. The cat is drawn mirrored on the island's
    other side.
*/
.pragma library

const W = 58, H = 60;

// Sitting, at ease: every other pose says only what differs.
const SIT = {
    // torso and haunches: centre and radii
    tx: 38, ty: 42.5, trx: 12.4, try_: 15, hx: 38, hy: 50, hrx: 16.3, hry: 8.4,
    // the body as a whole: lean, squash and stretch, fur on end (0..1)
    rot: 0, sx: 1, sy: 1, puff: 0, belly: 1,
    // head: centre, radii, tilt
    kx: 38, ky: 19.6, krx: 16.4, kry: 13.7, krot: 0,
    // ears: turned back/outwards from upright, and how tall
    earL: 0, earR: 0, earH: 1,
    // eyes: how open (0 = a closed arc, bent by `arc`: -1 asleep, 1 happy), pupils, frown, where they look
    eye: 1, arc: 0, pupil: 1, brow: 0, gx: 0, gy: 0,
    mouth: 0, fangs: 0, blush: 0, face: 1,
    // front paws
    plx: 32, ply: 56.2, prx: 44, pry: 56.2, paw: 1,
    // tail: a curve from its root (t0) by two handles to its tip (t3), and its thickness
    t0x: 27, t0y: 55, t1x: 10, t1y: 59.5, t2x: 4.5, t2y: 45, t3x: 12.5, t3y: 36.5, tw: 5, tfront: 0,
    // the whole cat: lifted (a hop), shaken
    dy: 0, jx: 0
};
const KEYS = Object.keys(SIT);
function pose(changes) { return Object.assign({}, SIT, changes); }

const CURLED = {
    tx: 37, ty: 47.6, trx: 19, try_: 10.4, hx: 44.5, hy: 49, hrx: 12.2, hry: 9, belly: 0,
    kx: 19.6, ky: 46.6, krx: 12.6, kry: 10.5, krot: -5, earL: 10, earR: 14, earH: 0.86,
    eye: 0, arc: -1, paw: 0, plx: 24, ply: 56.5, prx: 30, pry: 57,
    t0x: 53.5, t0y: 53, t1x: 52, t1y: 61.5, t2x: 27, t2y: 62.5, t3x: 12, t3y: 56.6, tfront: 1
};

const POSES = {
    sit: pose({}),
    // music: eyes half shut, pleased
    listen: pose({ eye: 0, arc: 0.55, blush: 0.4, earL: 4, earR: 4 }),
    // the pointer is on it, or it was clicked: a look, eyes wide
    curious: pose({ eye: 1.22, pupil: 1.25, earL: -7, earR: -7, earH: 1.05, ky: 18.6 }),
    // something appeared on the island: ears up, towards it
    perk: pose({ eye: 1.14, pupil: 1.1, earL: -11, earR: -11, earH: 1.1, ky: 18.2, gx: 0.6 }),
    cheer: pose({ eye: 0, arc: 1, blush: 0.5, ky: 18.8, t2x: 3.5, t2y: 39, t3x: 10.5, t3y: 26 }),
    tired: pose({ eye: 0.34, earL: 22, earR: 22, ky: 21.2, krot: 5, gy: 0.5 }),
    annoyed: pose({ eye: 0.74, brow: 0.7, pupil: 0.8, earL: 40, earR: 40, earH: 0.95, ky: 20.2 }),
    // fur on end, ears flat, tail like a brush, hissing
    angry: pose({ puff: 1, sx: 1.06, sy: 1.04, eye: 0.82, brow: 1, pupil: 0.58, earL: 64, earR: 64, earH: 0.9,
                  mouth: 0.78, fangs: 1, ky: 18.4, tw: 9.2, t1x: 15, t1y: 57, t2x: 7.5, t2y: 41, t3x: 9.5, t3y: 21.5 }),
    // its back to the world
    sulk: pose({ face: 0, belly: 0, paw: 0, rot: -2.5, kx: 36.6, ky: 20.9, krot: -7, earL: 12, earR: 20,
                 t1x: 11, t1y: 60, t2x: 3.5, t2y: 53, t3x: 8.5, t3y: 44.5 }),
    // stroked: eyes shut, head pressed into the hand, tail up
    pet: pose({ eye: 0, arc: 1, blush: 0.9, earL: 17, earR: 17, ky: 20.5, t2x: 3.5, t2y: 41, t3x: 9.5, t3y: 28 }),
    // falling asleep: drowsy, still upright (the yawn is a gesture)
    doze: pose({ eye: 0.3, earL: 18, earR: 18, ky: 21, krot: 4, gy: 0.5 }),
    sleep: pose(CURLED),
    // stroked in its sleep: it does not wake, but it shows
    purr: pose(Object.assign({}, CURLED, { arc: 1, blush: 0.85, ky: 45.4, krot: -1, earL: 16, earR: 18 })),
    // waking: a long stretch, rear up, front paws out, a yawn
    wake: pose({ tx: 34, ty: 48.2, trx: 17.5, try_: 8.6, hx: 46.2, hy: 42, hrx: 10.4, hry: 12.6, belly: 0,
                 kx: 19.5, ky: 45.6, krx: 13.2, kry: 11, krot: -11, earL: 16, earR: 16, eye: 0, arc: -1, mouth: 0.2,
                 plx: 8.6, ply: 56.8, prx: 15.2, pry: 57.4,
                 t0x: 52.5, t0y: 37, t1x: 57, t1y: 33, t2x: 56.5, t2y: 22, t3x: 50, t3y: 17.5, tfront: 0 })
};

// How long the change into a pose takes (ms).
const INTO = { sleep: 520, purr: 260, wake: 380, sit: 320, sulk: 360, angry: 170, curious: 200, perk: 200, annoyed: 200, pet: 240 };
function into(name, from) { return from === "sleep" || from === "purr" || from === "wake" ? Math.max(360, INTO[name] || 280) : INTO[name] || 280; }

// ---- what happens once: a gesture, g from 0 to 1 --------------------------------------------
// [how long (ms), what it adds to the pose at g]
const bump = g => Math.sin(Math.PI * g);
const GESTURES = {
    tail: [900, g => ({ sway: Math.sin(g * Math.PI * 3) * (1 - g) })],
    // "go away": two sharp flicks
    shoo: [620, g => ({ sway: 1.7 * Math.sin(g * Math.PI * 4) * (1 - 0.5 * g) })],
    ear: [420, g => ({ earR: 24 * Math.abs(Math.sin(g * Math.PI * 2)) * (1 - 0.4 * g) })],
    perk: [320, g => ({ ky: -1.6 * bump(g), earH: 0.1 * bump(g) })],
    hop: [400, g => ({ dy: -4.6 * bump(g), sy: g > 0.86 ? -0.07 * bump((g - 0.86) / 0.14) : 0.05 * bump(Math.min(1, g / 0.86)),
                       sx: g > 0.86 ? 0.07 * bump((g - 0.86) / 0.14) : 0 })],
    flinch: [340, g => ({ jx: 1.5 * Math.sin(g * Math.PI * 5) * (1 - g), ky: 1.2 * bump(g), krot: -4 * bump(g) })],
    turn: [300, g => ({ sx: -0.1 * bump(g) })],
    yawn: [950, g => { const o = Math.pow(bump(g), 0.6); return { mouth: 0.95 * o, eyeTimes: 1 - o, krot: -5 * o, ky: -1 * o, earL: 10 * o, earR: 10 * o }; }],
    stretch: [820, g => { const o = Math.pow(bump(g), 0.7); return { mouth: 0.6 * o, sx: 0.05 * o, plx: -2 * o, prx: -2 * o, hy: -1.2 * o }; }],
    // a paw to the mouth, three licks
    lick: [1900, g => {
        const up = Math.min(1, g / 0.16, (1 - g) / 0.14);
        const e = up * up * (3 - 2 * up), licks = Math.sin(g * Math.PI * 6);
        return { plx: (34.2 - SIT.plx) * e, ply: (35.6 + 1.1 * licks - SIT.ply) * e, ky: 2.4 * e, krot: -7 * e, eyeTimes: 1 - e, mouth: 0.24 * e * (licks > 0 ? 1 : 0.3) };
    }]
};
// The eyes shut and open again.
const BLINK = 230;
function blink(g) { return 1 - 0.96 * Math.pow(bump(g), 0.5); }
// A nod on a beat of the music.
const NOD = 270;
function nod(g, strength) { const d = bump(Math.pow(g, 0.6)) * (0.6 + 0.4 * strength); return { ky: 1.5 * d, krot: 3.2 * d, try_: -0.3 * d }; }

// ---- what goes on and on: a motion, its phase p from 0 to 1 ---------------------------------
// [one round (ms), how many steps of it a second, what it adds at p]
const wave = p => Math.sin(p * Math.PI * 2);
const LOOPS = {
    // asleep: the slowest breath, in a few steps
    breath: [3400, 2.4, p => ({ try_: 0.5 * wave(p), trx: 0.35 * wave(p), ky: -0.3 * wave(p), hry: 0.25 * wave(p) })],
    // no beat to follow: a calm nod, 80 to the minute
    bob: [750, 22, p => { const d = Math.pow(Math.max(0, wave(p)), 1.4); return { ky: 1.5 * d, krot: 3.2 * d + 2.2 * Math.sin(p * Math.PI), sway: 0.25 * wave(p) }; }],
    // sulking: the tail sweeps
    swish: [1700, 12, p => ({ sway: 0.9 * wave(p) })],
    // annoyed, angry: it lashes
    lash: [520, 18, p => ({ sway: 0.8 * wave(p) })],
    bristle: [520, 18, p => ({ sway: 0.35 * wave(p), jx: 0.32 * (Math.floor(p * 10) % 2 ? 1 : -1) })],
    // stroked: a purr one can see, and the tail waves
    purr: [1300, 24, p => ({ jx: 0.3 * (Math.floor(p * 30) % 2 ? 1 : -1), sway: 0.55 * wave(p), ky: 0.25 * wave(p * 2) })],
    snore: [1300, 24, p => ({ jx: 0.24 * (Math.floor(p * 30) % 2 ? 1 : -1), try_: 0.3 * wave(p) })],
    wag: [640, 20, p => ({ sway: 0.9 * wave(p) })]
};
// Which motion a body has (beats: the music's own beat is followed instead of the calm nod).
function loopOf(body, beats) {
    return body === "sleep" ? "breath" : body === "listen" ? (beats ? "" : "bob") : body === "sulk" ? "swish"
         : body === "annoyed" ? "lash" : body === "angry" ? "bristle" : body === "pet" ? "purr" : body === "purr" ? "snore"
         : body === "cheer" ? "wag" : "";
}

function between(a, b, t) {
    const m = {};
    for (let i = 0; i < KEYS.length; ++i) { const k = KEYS[i]; m[k] = a[k] + (b[k] - a[k]) * t; }
    return m;
}
function add(m, d) {
    for (const k in d) {
        if (k === "eyeTimes") m.eye *= d[k];
        else if (k === "sway") m.sway = (m.sway || 0) + d[k];
        else m[k] += d[k];
    }
}
function ear(m, side, turned) {
    // where it stands on the head, and which way it points (from upright, outwards)
    const at = 37 * Math.PI / 180, lean = (23 + turned) * Math.PI / 180, lean0 = 23 * Math.PI / 180;
    const bx = side * m.krx * Math.sin(at) * 0.9, by = -m.kry * Math.cos(at) * 0.9;
    const half = 5.9, tall = 10.2 * m.earH * (1 - 0.3 * Math.min(1, Math.abs(turned) / 70));
    const ux = side * Math.cos(lean0), uy = Math.sin(lean0);              // along its base
    const ax = side * Math.sin(lean), ay = -Math.cos(lean);               // towards its tip
    const b1x = bx - ux * half, b1y = by - uy * half, b2x = bx + ux * half, b2y = by + uy * half;
    const tx = bx + ax * tall, ty = by + ay * tall;
    const r = 0.26;
    return { b1x: b1x, b1y: b1y, b2x: b2x, b2y: b2y, tx: tx, ty: ty,
             ax: tx + (b1x - tx) * r, ay: ty + (b1y - ty) * r, cx: tx + (b2x - tx) * r, cy: ty + (b2y - ty) * r,
             // the inside of it
             i1x: bx - ux * half * 0.52 + ax * 1.5, i1y: by - uy * half * 0.52 + ay * 1.5,
             i2x: bx + ux * half * 0.52 + ax * 1.5, i2y: by + uy * half * 0.52 + ay * 1.5,
             itx: bx + ax * tall * 0.72, ity: by + ay * tall * 0.72 };
}
// The fur on end: tufts standing out from its sides and shoulders (none where it sits).
function spikes(m) {
    const points = [], n = 9, cx = m.hx, cy = (m.ty + m.hy) / 2 + 1.5, rx = m.hrx + 0.6, ry = (m.hy + m.hry - (m.ty - m.try_)) / 2 + 0.4;
    const from = 0.86 * Math.PI, round = 1.28 * Math.PI;      // from low on one side, over the back, to low on the other
    for (let i = 0; i <= n * 2; ++i) {
        const a = from + round * i / (n * 2), r = 1 + (i % 2 ? (0.17 + 0.05 * ((i * 7) % 3)) * m.puff : -0.04);
        points.push(Qt.point(cx + Math.cos(a) * rx * r, Math.min(H - 1.5, cy + Math.sin(a) * ry * r)));
    }
    return points;
}

/*
    The cat as it is drawn now. o:
      tilt     0..1: the head to the side, eyes up (it thinks)
      look     -1..1: where the pointer is, across the cat
      act, g   the gesture that plays and how far it is ("" = none)
      blink    0..1 through a blink, -1 = none
      nod      0..1 through a nod, -1 = none; strength 0..1
      loop, p  the motion that repeats and its phase ("" = none)
*/
function compose(a, b, t, o) {
    const m = between(a, b, t);
    m.sway = 0;
    if (o.tilt > 0) { m.krot += 8.5 * o.tilt; m.gx -= 0.55 * o.tilt; m.gy -= 0.8 * o.tilt; m.ky += 0.4 * o.tilt; }
    if (o.look !== 0 && m.face > 0.5) { m.gx += 0.9 * o.look; m.krot += 3.5 * o.look * (m.kry > 12 ? 1 : 0.3); m.kx += 1.1 * o.look * (m.kry > 12 ? 1 : 0.3); }
    if (o.act !== "" && GESTURES[o.act] !== undefined) add(m, GESTURES[o.act][1](o.g));
    if (o.nod >= 0) add(m, nod(o.nod, o.strength));
    if (o.loop !== "" && LOOPS[o.loop] !== undefined) add(m, LOOPS[o.loop][2](o.p));
    if (o.blink >= 0) m.eye *= blink(o.blink);
    m.gx = Math.max(-1, Math.min(1, m.gx));
    m.gy = Math.max(-1, Math.min(1, m.gy));
    m.mouth = Math.max(0, Math.min(1, m.mouth));
    // the tail's tip follows the sway, its far handle half as much
    m.t3x += 5.4 * m.sway; m.t3y += 1.2 * Math.abs(m.sway);
    m.t2x += 2.6 * m.sway;
    m.left = ear(m, -1, m.earL);
    m.right = ear(m, 1, m.earR);
    m.spikes = m.puff > 0.02 ? spikes(m) : [];
    return m;
}

// ---- where it can be touched, where its bubble goes ------------------------------------------
// Ellipses (as their bounding boxes) that cover the body, not the tail, not the air around it.
function touch(body) {
    if (body === "sleep" || body === "purr") return [{ x: 6, y: 34.5, w: 51, h: 24.5 }];
    if (body === "wake") return [{ x: 5, y: 31, w: 52, h: 28 }];
    const big = body === "angry" ? 1.5 : 0;
    return [{ x: 20.5 - big, y: 1.5 - big, w: 35 + 2 * big, h: 33 + big }, { x: 21 - big, y: 28, w: 34 + 2 * big, h: 31 }];
}
// The spot beside the head a bubble points at.
function beside(body) {
    return body === "sleep" || body === "purr" || body === "wake" ? { x: 12, y: 33 } : { x: 24, y: 8.5 };
}
