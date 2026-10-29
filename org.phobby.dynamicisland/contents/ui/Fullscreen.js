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

// The notch's place, where a window that reaches into it counts (see reaches): the notch as it is
// at rest, never as it is drawn now. `width`: the width set for it (0: the clock's, `baseWidth`),
// within `room` (the screen's, at that size); `height` the notch's own at rest; `scale` the size
// set; all at 100 % and then scaled. (What the island does over such a window, shrinking it,
// drawing it up, opening it larger, would otherwise change what it looks at, and a window at the
// edge of the notch made it go back and forth every frame.)
function restArea(screen, width, baseWidth, height, scale, offsetX, room) {
    if (!screen || !(screen.width > 0) || !(scale > 0)) return { x: 0, y: 0, width: 0, height: 0 };
    const set = Number(width) > 0 ? Math.max(2 * height, Math.min(Number(width), room > 0 ? room : Infinity)) : baseWidth;
    const w = Math.round(set * scale), h = Math.round(height * scale);
    return { x: screen.x + (screen.width - w) / 2 + (Number(offsetX) || 0), y: screen.y, width: w, height: h };
}

// A rectangle grown by `by` px on every side (above the screen's edge too, which changes nothing).
function grown(area, by) {
    if (!area || !(area.width > 0)) return area;
    return { x: area.x - by, y: area.y - by, width: area.width + 2 * by, height: area.height + 2 * by };
}

// Whether a window reaches into the notch's place, with a margin to leave: one that reached into it
// has to be `margin` px clear of it before it stops counting, so a window held at its edge does not
// count, stop and count again.
function reachesHeld(windows, area, maximized, was, margin) {
    return reaches(windows, was ? grown(area, margin) : area, maximized);
}

// How often the full-screen state may change: the times (ms) of the last changes, and whether one
// more at `now` is too many (more than `most` within `span` ms: something goes back and forth).
function tooOften(times, now, most, span) {
    return times.filter(t => t > now - span).length >= most;
}

// What the strip at the edge says, the most important first: "call" (one is ringing or
// going on), "recording" (the screen), "critical" (a warning waits), "" nothing. The
// microphone or the camera in use says nothing there: it lasts as long as a call or a
// meeting does, and a light lit all that time over the full-screen window is in the way.
function signalOf(s) {
    if (s.ringing === true || s.calling === true) return "call";
    if (s.recording === true) return "recording";
    if (s.critical === true) return "critical";
    return "";
}

// Whether that opens the island over the full-screen window: only a call ringing, and only if wanted.
function opens(s, wanted) {
    return wanted === true && s.ringing === true;
}
