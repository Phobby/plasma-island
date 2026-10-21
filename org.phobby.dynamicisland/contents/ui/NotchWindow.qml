/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The notch's window (Wayland): a layer-shell surface in the overlay layer,
    anchored to the top edge of its screen, which the compositor centres. In
    that layer it stays over every panel, also one that is shown again after
    hiding, and over a window that fills the screen (main.qml hides it there
    unless the user wants it shown); the lock screen draws nothing of it. Why
    not the Dialog: docs/ARCHITECTURE.md, "Notch mode".

    In its own file: without LayerShellQt (org.kde.layershell) this fails to
    load and the island stays in its Dialog, which then goes to the top edge.
    Its screen is fixed when it is made: main.qml makes it anew for another.
*/
import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell

Window {
    id: notch

    // A text field in the island wants the keyboard (a quick reply): the surface may take it.
    property bool keyboard: false

    title: "Dynamic Island"
    color: "transparent"
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop
    // (-1: up to the edge itself, not pushed below what reserves room there)
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: keyboard ? LayerShell.Window.KeyboardInteractivityOnDemand
                                                      : LayerShell.Window.KeyboardInteractivityNone
    LayerShell.Window.activateOnShow: false
    LayerShell.Window.scope: "dynamicisland-notch"
    // (on the screen main.qml puts it on; without this LayerShellQt 6.6 takes the primary one, whatever
    // the window's or its own `screen` say. It logs that this is deprecated.)
    LayerShell.Window.screenConfiguration: LayerShell.Window.ScreenFromQWindow
}
