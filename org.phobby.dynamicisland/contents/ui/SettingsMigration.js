// SPDX-License-Identifier: GPL-2.0-or-later
// The settings' own versions (settingsSchema), and what each step changes, once.
//
// 1: the layout. Up to 0.2.2 the island was the rounded one; builds of the notch kept a
//    switch for it (notchMode). The choice is islandLayout now: 0 = the notch, the
//    default of a new island; 1 = the oval layout. An island that ran before keeps what
//    it showed: the notch if notchMode was switched on, the oval layout otherwise, and
//    is told once that the notch is there (layoutNotice). notchMode is left as it was,
//    so the step can be taken again and comes to the same.
// 2: the full-screen mode. What the notch did over a window that fills the screen
//    (notchFullscreen: 0 = hide, 1 = show, 2 = dodge, 3 = shrink) is the full-screen mode
//    of both layouts now (fullscreenMode: 0 = hide, 1 = normal, 2 = peek at the edge,
//    3 = shrink), the value as it was: show is normal, hide is hide, dodging is peeking.
//    A new island has what one had before: hide (on the oval layout a window that fills
//    the screen lies over the island anyway). notchFullscreen is left as it was.
// 3: the first-run tour (tourShown). A new island shows it at its first opening; one that
//    ran before is not shown it: nothing of what it shows was changed for it (the settings
//    window was only arranged anew, no setting was renamed or given another meaning).
//
// Pure functions of plain values: main.qml hands in the settings, writes what comes back.
.pragma library

const CURRENT = 3;
const NOTCH = 0;
const OVAL = 1;
const HIDE = 0;
const NORMAL = 1;
const PEEK = 2;
const SHRINK = 3;

// Whether these settings were used by an island before this one ran: it noted its
// version (from 0.2.0), or kept its settings (from 0.2.2), or they were brought back
// from an earlier island (SettingsKeeper).
function usedBefore(c, restored) {
    return restored === true || String(c.installedVersion || "").length > 0 || c.settingsKept === true;
}

// The layout these settings mean, before or after the step.
function layoutOf(c, restored) {
    if (Number(c.settingsSchema) >= 1) return Number(c.islandLayout) === OVAL ? OVAL : NOTCH;
    return usedBefore(c, restored) && c.notchMode !== true ? OVAL : NOTCH;
}

// A full-screen mode as one of the four (anything else: hide, as before there was a choice).
function mode(value) {
    const v = Number(value);
    return v === NORMAL || v === PEEK || v === SHRINK ? v : HIDE;
}

// The full-screen mode these settings mean, before or after the step.
function fullscreenOf(c) {
    return mode(Number(c.settingsSchema) >= 2 ? c.fullscreenMode : c.notchFullscreen);
}

// What to write: { settingsSchema, islandLayout, layoutNotice, fullscreenMode, tourShown } or {} when there is nothing to do.
function migrate(c, restored) {
    const from = Number(c.settingsSchema) || 0;
    if (from >= CURRENT) return {};
    const out = { settingsSchema: CURRENT };
    if (from < 1 && usedBefore(c, restored)) {
        out.islandLayout = c.notchMode === true ? NOTCH : OVAL;
        // (told only who did not have the notch, and only once)
        if (out.islandLayout === OVAL && c.layoutNotice === 0) out.layoutNotice = 1;
    }
    if (from < 2) out.fullscreenMode = mode(c.notchFullscreen);
    // (an island of schema 1 or 2 ran before by definition; a new one comes from 0)
    if (from < 3 && (from >= 1 || usedBefore(c, restored)) && c.tourShown !== true) out.tourShown = true;
    return out;
}

// The steps undone: as before they were taken (what was chosen since is kept in notchMode and notchFullscreen).
function revert(c) {
    const from = Number(c.settingsSchema) || 0;
    if (from < 1) return {};
    const out = { settingsSchema: 0, notchMode: Number(c.islandLayout) !== OVAL };
    if (from >= 2) out.notchFullscreen = mode(c.fullscreenMode);
    return out;
}
