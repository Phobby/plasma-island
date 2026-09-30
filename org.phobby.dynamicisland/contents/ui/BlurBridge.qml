/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Thin wrapper around the optional native module (native/). Loading this file
    fails cleanly when the module is not installed.
*/
import QtQuick
import org.phobby.dynamicisland.effects as Effects

Item {
    id: bridge

    property alias window: helper.window
    property alias rect: helper.region
    property alias radius: helper.radius
    property alias rect2: helper.region2
    property alias enabled: helper.enabled
    readonly property bool available: helper.available

    Effects.WindowBlur {
        id: helper
    }
}
