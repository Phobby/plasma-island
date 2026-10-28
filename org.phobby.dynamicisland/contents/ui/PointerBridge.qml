/*
    SPDX-License-Identifier: GPL-2.0-or-later
    The pointer near a place of the screen, told by KWin without taking the
    pointer there (native/core/pointerwatch.h), in its own file so that an
    older native module (without PointerWatch) only loses the light's reach
    (it then lights at the opening place only) instead of the whole island.
*/
import QtQuick
import org.phobby.dynamicisland.core as Core

Core.PointerWatch {}
