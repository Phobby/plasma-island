// SPDX-License-Identifier: GPL-2.0-or-later
// The settings' own versions (settingsSchema), and what each step changes, once.
//
// 1: the layout. Up to 0.2.2 the island was the rounded one; builds of the notch kept a
//    switch for it (notchMode). The choice is islandLayout now: 0 = the notch, the
//    default of a new island; 1 = the oval layout. An island that ran before keeps what
//    it showed: the notch if notchMode was switched on, the oval layout otherwise, and
//    is told once that the notch is there (layoutNotice). notchMode is left as it was,
//    so the step can be taken again and comes to the same.
//
// Pure functions of plain values: main.qml hands in the settings, writes what comes back.
.pragma library

const CURRENT = 1;
const NOTCH = 0;
const OVAL = 1;

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

// What to write: { settingsSchema, islandLayout, layoutNotice } or {} when there is nothing to do.
function migrate(c, restored) {
    if (Number(c.settingsSchema) >= CURRENT) return {};
    const out = { settingsSchema: CURRENT };
    if (usedBefore(c, restored)) {
        out.islandLayout = c.notchMode === true ? NOTCH : OVAL;
        // (told only who did not have the notch, and only once)
        if (out.islandLayout === OVAL && c.layoutNotice === 0) out.layoutNotice = 1;
    }
    return out;
}

// The step undone: as before it was taken (the layout chosen since is kept in notchMode).
function revert(c) {
    if (Number(c.settingsSchema) < 1) return {};
    return { settingsSchema: 0, notchMode: Number(c.islandLayout) !== OVAL };
}
