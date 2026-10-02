/*
    SPDX-License-Identifier: GPL-2.0-or-later
    KWallet password store from the native core, in its own file so that an
    older native module (without SecretStore) only disables this feature
    instead of the whole NativeBridge.
*/
import QtQuick
import org.phobby.dynamicisland.core as Core

Core.SecretStore {}
