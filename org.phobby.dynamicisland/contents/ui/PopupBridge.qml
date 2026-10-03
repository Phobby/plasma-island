/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Whether a popup menu of plasmashell is open (native/core/popupwatcher.h),
    in its own file so that without the native module (or with an older one)
    only this feature is lost.
*/
import QtQuick
import org.phobby.dynamicisland.core as Core

Core.PopupWatcher {}
