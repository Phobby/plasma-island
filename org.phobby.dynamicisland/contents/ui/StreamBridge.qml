/*
    SPDX-License-Identifier: GPL-2.0-or-later
    A command read while it runs (the AI tab's Claude Code) from the native
    core, in its own file so that an older native module (without
    StreamProcess) only disables this feature instead of the whole
    NativeBridge.
*/
import QtQuick
import org.phobby.dynamicisland.core as Core

Core.StreamProcess {}
