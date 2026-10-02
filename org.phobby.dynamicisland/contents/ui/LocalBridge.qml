/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Local helpers from the native core (run a command, read a file or an
    SQLite database, watch paths), in its own file so that an older native
    module (without LocalTools) only disables this feature instead of the
    whole NativeBridge.
*/
import QtQuick
import org.phobby.dynamicisland.core as Core

Core.LocalTools {}
