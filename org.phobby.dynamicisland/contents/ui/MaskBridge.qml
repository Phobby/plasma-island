/*
    SPDX-License-Identifier: GPL-2.0-or-later
    The island's window takes the pointer only where the island is drawn
    (native/windowmask.h). In its own file: without the native module, or with
    an older one, the window takes it everywhere, as before.
*/
import QtQuick
import org.phobby.dynamicisland.effects as Effects

Effects.WindowMask {}
