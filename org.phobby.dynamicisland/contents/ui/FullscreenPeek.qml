/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The full-screen mode (Appearance › Layout), as states: what the island
    is while a window fills its screen. main.qml hands in what is going on
    and moves the island as this says; nothing here draws.

      * hide (0): `hidden` while such a window is there.
      * normal (1): nothing changes.
      * peek (2): `away`, drawn up to the top edge with only a small part
        showing. The pointer resting on the strip at the edge for `delay` ms
        (`edgeHovered`) brings it down and opens it (`openRequested`), as a
        hover would; once it is left and has closed again it goes back up
        after `settle` ms. Not while it is being typed in or used (`busy`).
      * shrink (3): `shrunk`, the notch drawn in to a nub; the pointer on it
        opens it in the same way.

    On the desktop too, where wanted (`idleDelay` > 0): once nothing has
    gone on in it (`idle`) for that long it is drawn up or shrunk as for
    such a window, peek or shrink only (`idleAway`); anything that comes
    (a notification, a live activity, the island opened) brings it back.

    No flicker: after it went back up the strip opens it again only once
    the pointer has left it (or was not on it), so a pointer kept at the
    edge does not open and close it over and over. A call ringing opens it
    at once if `callOpens`; everything else only colours the strip (main.qml).
*/
import QtQuick

Item {
    id: peek

    property int mode: 0
    // A window fills the screen (or reaches under the notch, where that is wanted).
    property bool over: false
    // The pointer on the strip at the edge (or on the nub).
    property bool edgeHovered: false
    // The island under the pointer, open, or being typed in or used.
    property bool hovered: false
    property bool open: false
    property bool busy: false
    property int delay: 150
    property int settle: 300
    // A call ringing, and whether that opens it.
    property bool ringing: false
    property bool callOpens: true
    // Nothing going on in the island (main.qml), and how long that lasts before it goes (ms; 0 = never).
    property bool idle: false
    property int idleDelay: 0
    // Drawn up or shrunk for that, on the desktop.
    property bool idleAway: false

    readonly property bool hidden: mode === 0 && over
    // Drawn up or shrunk for such a window, now or after a while.
    readonly property bool active: (mode === 2 || mode === 3) && (over || idleAway)
    property bool shown: false
    readonly property bool away: mode === 2 && active && !shown
    readonly property bool shrunk: mode === 3 && active && !shown
    // (whether the strip may open it: see above)
    property bool armed: true
    signal openRequested()

    function show(): void {
        if (!active || shown) return;
        opening.stop();
        shown = true;
        openRequested();
    }
    onActiveChanged: { shown = false; armed = true; opening.stop(); }
    onEdgeHoveredChanged: {
        if (edgeHovered) { if (armed && (away || shrunk)) opening.restart(); }
        else { opening.stop(); armed = true; }
    }
    onRingingChanged: if (ringing && callOpens) show()
    onIdleChanged: if (!idle) idleAway = false
    onIdleDelayChanged: if (idleDelay <= 0) idleAway = false
    onModeChanged: idleAway = false
    Timer {
        id: idling
        interval: Math.max(0, peek.idleDelay)
        running: peek.idleDelay > 0 && (peek.mode === 2 || peek.mode === 3) && peek.idle && !peek.idleAway
        onTriggered: peek.idleAway = true
    }
    Timer {
        id: opening
        interval: Math.max(0, peek.delay)
        onTriggered: if (peek.edgeHovered && peek.armed) peek.show()
    }
    Timer {
        id: goingBack
        interval: peek.settle
        running: peek.active && peek.shown && !peek.hovered && !peek.open && !peek.busy && !peek.edgeHovered
        onTriggered: {
            peek.shown = false;
            peek.armed = false;
            rearm.restart();
        }
    }
    // (the strip back under a pointer that was not on it: no pointer there, so it may open it again)
    Timer {
        id: rearm
        interval: 400
        onTriggered: if (!peek.edgeHovered) peek.armed = true
    }
}
