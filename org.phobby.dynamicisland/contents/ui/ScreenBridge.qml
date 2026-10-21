/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Puts a window that is not shown yet on a screen by its name, a layer-shell
    surface too (native/windowscreen.h). In its own file: without the native
    module, or with an older one, the notch is on the primary screen.
*/
import QtQuick
import org.phobby.dynamicisland.effects as Effects

QtObject {
    function place(window: var, screenName: string): bool { return Effects.WindowScreen.place(window, screenName); }
}
