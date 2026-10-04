/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Activity: one Live Activity (persistent while `active`). Providers declare
    these and register them with the ActivityManager. Every activity has three
    presentations; anything left unset falls back to a generic layout:

      minimal   the detached bubble of a split island   (minimal: Component)
      compact   inside the pill: leading · trailing     (compact: Component)
      expanded  a card on the "Activities" page         (expanded: Component)

    Custom Components are instantiated with `activity` and `theme` set.
*/
import QtQuick

QtObject {
    id: activity

    property string activityId
    // privacy | call | recording | timer | transfer | media (ordering: ActivityManager.order);
    // one that is not in that order ranks below all of them (habits)
    property string category: "transfer"
    // Tie-break inside a category, higher wins.
    property int priority: 0
    property bool active: false
    // Shown only as a privacy dot / in the list, never in the pill.
    property bool indicatorOnly: false
    // Hidden from the "Activities" page (e.g. media has its own page).
    property bool listed: true

    property string icon
    property color color: "white"
    property string title
    property string subtitle
    property string trailingText
    property real progress: -1        // 0..1; -1 = none; -2 = indeterminate (unknown total)
    property bool pulse: false        // blinking leading icon (recording)
    property real compactWidth: 0     // 0 → Theme.liveWidth

    property Component compact
    property Component minimal
    property Component expanded

    // [{ icon, text, trigger: function }]
    property var actions: []

    property date startedAt: new Date()
    onActiveChanged: if (active) startedAt = new Date()

    signal clicked()
}
