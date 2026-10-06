/*
    SPDX-License-Identifier: GPL-2.0-or-later

    What makes a Flickable (a ListView, a GridView…) keep its scroll: put one
    inside it and tell it where it is,

        PathView { id: view; IslandScroll { area: view } }

    IslandFlickable, IslandListView and IslandGridView have it already.

    - More content than fits: a scroll that begins over it is its own to the
      last step, also at its end and past it. Nothing of it turns the
      island's pages or moves a list around it.
    - Content that fits: it takes nothing, the scroll goes on to what is
      behind (a list around it, the island's pages). This follows the content
      as it grows and shrinks.
    - A list takes the scroll of its own direction: a sideways swipe over a
      list that goes up and down turns the pages. A row that only goes
      sideways takes the wheel too, and is moved by it: a mouse has no other
      way to scroll it.

    The rules and the numbers: ScrollGesture.
*/
import QtQuick

WheelHandler {
    id: scroll

    // The Flickable it was put in (a handler inside a Flickable has no parent to ask).
    required property Flickable area
    readonly property bool overflowsX: area !== null && area.interactive && area.contentWidth > area.width + 1
    readonly property bool overflowsY: area !== null && area.interactive && area.contentHeight > area.height + 1
    // A row: it has somewhere to go sideways and nowhere up or down.
    readonly property bool sideways: overflowsX && !overflowsY

    // Sees every step before the Flickable does, and takes none from it.
    blocking: false
    target: null
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

    // While somebody else's gesture runs the Flickable does not move (the
    // wheel has no switch of its own): what reaches it then goes on unheard.
    readonly property Binding deaf: Binding {
        target: scroll.area
        property: "interactive"
        value: false
        when: ScrollGesture.owner !== null && ScrollGesture.owner !== scroll.area
        restoreMode: Binding.RestoreBindingOrValue
    }

    // (a WheelHandler hears one direction: `across` hears the steps that go sideways only)
    onWheel: event => { if (!ScrollGesture.step(event).flat) stepped(event); }
    readonly property WheelHandler across: WheelHandler {
        parent: scroll.area
        orientation: Qt.Horizontal
        blocking: false
        target: null
        acceptedDevices: scroll.acceptedDevices
        onWheel: event => { if (ScrollGesture.step(event).flat) scroll.stepped(event); }
    }

    function stepped(event): void {
        if (area === null) return;
        const step = ScrollGesture.step(event);
        const wants = !step.none && (step.horizontal ? overflowsX : overflowsY || sideways);
        if (!ScrollGesture.take(area, wants, event)) return;
        if (sideways && !step.horizontal && step.y !== 0) {
            const by = step.pixels ? step.y : step.y / ScrollGesture.tabAngle * ScrollGesture.notchPixels;
            const first = area.originX, last = area.originX + area.contentWidth - area.width;
            area.contentX = Math.max(first, Math.min(last, area.contentX - by));
        }
    }
}
