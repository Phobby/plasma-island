/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Downloads made by commands (apt, git clone, wget…) from the native core, in
    its own file so that an older native module (without CommandWatcher) only
    disables this feature instead of the whole NativeBridge.
*/
import QtQuick
import org.phobby.dynamicisland.core as Core

Core.CommandWatcher {}
