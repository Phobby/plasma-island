/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Installs and updates made through PackageKit (Discover) from the native
    core, in its own file so that an older native module only disables this.
*/
import QtQuick
import org.phobby.dynamicisland.core as Core

Core.PackageKitWatcher {}
