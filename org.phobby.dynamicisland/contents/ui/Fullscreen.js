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

// The window in front on this screen: the active one if it is here, else the one that was
// active last (the compositor keeps that one on top of this screen while another screen has
// the focus). Minimised windows are behind everything. `windows`: those of this screen, of
// the desktop and the activity shown (backend/FullscreenBackend.qml), each { fullScreen,
// maximized, minimized, active, lastActivated (ms, 0 = not known), geometry }.
function front(windows) {
    let found = null;
    for (const w of windows) {
        if (w.minimized === true) continue;
        if (w.active === true) return w;
        if (found === null || Number(w.lastActivated || 0) > Number(found.lastActivated || 0)) found = w;
    }
    return found;
}

// Whether a window fills this screen: the one in front says it is full screen (the window
// manager's own flag: a browser's F11, a video, a terminal, any application), or is as large
// as the screen without saying so (a game in a borderless window). A window behind it does
// not count, nor one on another desktop. A maximised window counts only where `maximized`
// is wanted: on a screen without panels it is as large as the screen, and above a top panel
// it never meets the island.
function fills(windows, screen, maximized) {
    const w = front(windows);
    if (w === null) return false;
    if (w.fullScreen === true) return true;
    if (w.maximized === true) return maximized === true;
    return covers(w.geometry, screen);
}

// Whether a window that is not minimised reaches into `area` (the notch's place); a
// maximised one only where `maximized` is wanted (see fills).
function reaches(windows, area, maximized) {
    if (!area || !(area.width > 0)) return false;
    return windows.some(w => {
        const g = w.geometry;
        return w.minimized !== true && (w.maximized !== true || maximized === true) && !!g && g.width > 0
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
