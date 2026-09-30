/*
    SPDX-License-Identifier: GPL-2.0-or-later
    "Unlocked" animation after the session is unlocked (the Face ID moment).
*/
import QtQuick
import ".."

Item {
    id: provider

    required property ActivityManager manager
    required property Theme theme
    property var core: null
    property bool enabled: true

    Connections {
        target: provider.core
        enabled: provider.enabled
        ignoreUnknownSignals: true
        function onScreenUnlocked() {
            provider.manager.flash({
                key: "unlock",
                icon: "object-unlocked-symbolic",
                color: provider.theme.live,
                title: i18n("Unlocked"),
                duration: 1600
            });
        }
    }
}
