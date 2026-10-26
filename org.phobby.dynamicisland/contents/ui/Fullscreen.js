// SPDX-License-Identifier: GPL-2.0-or-later
// Over a window that fills the screen: what counts as one, and what the island says
// there while it is drawn up to the edge (the full-screen mode, Appearance › Layout).
//
// Pure functions of plain values: backend/FullscreenBackend.qml hands in the windows of
// one screen as the task manager tells them, main.qml what is going on.
.pragma library

// Whether a rectangle covers the whole of another ({x, y, width, height}).
function covers(g, screen) {
    return !!g && !!screen && screen.width > 0 && g.x <= screen.x && g.y <= screen.y
           && g.x + g.width >= screen.x + screen.width && g.y + g.height >= screen.y + screen.height;
}

// Whether a window fills this screen. `windows`: those of this screen (desktop, activity),
// each { fullScreen, maximized, minimized, active, geometry }. One that says it is full
// screen counts while it is the active one, or while the active window is on another
// screen (the compositor keeps it on top then, too); the active one counts also when it is
// as large as the screen without saying so (a game in a borderless window, a page or a
// video made to fill it by some browsers), unless it is only maximised (on a screen
// without panels a maximised window is as large as the screen, and the island is over it).
function fills(windows, screen) {
    const activeHere = windows.some(w => w.active === true);
    return windows.some(w => w.minimized !== true
                             && (w.active === true ? w.fullScreen === true || w.maximized !== true && covers(w.geometry, screen)
                                                   : !activeHere && w.fullScreen === true));
}

// Whether a window that is not minimised reaches into `area` (the notch's place).
function reaches(windows, area) {
    if (!area || !(area.width > 0)) return false;
    return windows.some(w => {
        const g = w.geometry;
        return w.minimized !== true && !!g && g.width > 0
               && g.x < area.x + area.width && g.x + g.width > area.x && g.y < area.y + area.height && g.y + g.height > area.y;
    });
}

// What the strip at the edge says, the most important first: "call" (one is ringing or
// going on), "recording" (the screen), "critical" (a warning waits), "privacy" (the
// microphone or the camera in use), "" nothing.
function signalOf(s) {
    if (s.ringing === true || s.calling === true) return "call";
    if (s.recording === true) return "recording";
    if (s.critical === true) return "critical";
    if (s.privacy === true) return "privacy";
    return "";
}

// Whether that opens the island over the full-screen window: only a call ringing, and only if wanted.
function opens(s, wanted) {
    return wanted === true && s.ringing === true;
}
