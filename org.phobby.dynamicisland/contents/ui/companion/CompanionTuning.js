/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The companion's numbers, all of them: how a stroke is told from a pointer
    passing by, how many clicks are too many, how long each mood and reaction
    lasts, how often it fidgets. Times are in milliseconds. Change them here;
    Companion.js has the rules they are used in, the settings page a few of
    them as the user's own (sleepAfter, sulkFor).
*/
.pragma library

const TUNING = {
    // ---- stroking ---------------------------------------------------------------------
    // The pointer goes back and forth over the cat. A turn: it has come back this
    // far (a part of the cat's width) from where it last turned …
    petDistance: 0.25,
    // … and this many turns, none older than petWindow, are a stroke.
    petTurns: 3,
    petWindow: 1200,
    // Stroking is over this long after the last turn.
    petLinger: 1500,
    // A sulking cat is won back by stroking it this long without a break.
    makeUpAfter: 2500,

    // ---- clicks ---------------------------------------------------------------------
    // Clicks no further apart than this are counted together; this many of them
    // (awake) are too many. One click on a sleeping cat is.
    clickWindow: 3000,
    angryClicks: 3,
    // Bristling and hissing, then it turns its back for sulkFor (a setting).
    angryFor: 2600,
    sulkFor: 10000,
    // A click that is not too many: startled, then (the one before too many) annoyed.
    startleFor: 900,
    annoyedFor: 1400,

    // ---- sleep ----------------------------------------------------------------------
    // Nothing happens for this long (a setting): it yawns, curls up, sleeps.
    sleepAfter: 20000,
    dozeFor: 1100,
    wakeFor: 1000,

    // ---- what it does for a moment ----------------------------------------------------
    perkFor: 1600,          // something appeared on the island: ears up, a look
    cheerFor: 1400,         // a timer ran out, a download is done
    tiredFor: 1800,         // the battery is low
    exclaimFor: 1800,       // "!": an answer is ready
    noteFor: 2200,          // "♪": music begins

    // ---- fidgets, awake and at ease: the next one comes after [from, to] --------------
    blink: [2800, 7000],
    tail: [6000, 15000],
    ear: [9000, 22000],
    lick: [45000, 120000]
};
