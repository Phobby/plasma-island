/*
    SPDX-License-Identifier: GPL-2.0-or-later
    A file dragged out of the island (the Cloud tab) from the native core, in
    its own file so that an older native module (without FileDrag) only
    disables this feature instead of the whole NativeBridge.
*/
import QtQuick
import org.phobby.dynamicisland.core as Core

Core.FileDrag {}
