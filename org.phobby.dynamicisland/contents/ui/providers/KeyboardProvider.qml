/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Caps Lock / Num Lock toggles and keyboard layout switches (TR ↔ EN).
*/
import QtQuick
import ".."

Item {
    id: provider

    required property ActivityManager manager
    required property var keyboard
    required property Theme theme
    property bool enabled: true

    function lockEvent(name: string, on: bool, icon: string): void {
        manager.flash({
            key: "lock-" + name,
            live: true,
            icon: icon,
            color: on ? theme.blue : theme.subText,
            title: name,
            trailing: { type: "text", text: on ? Lang.i18nc("@info key lock state", "On") : Lang.i18nc("@info key lock state", "Off"), color: on ? theme.blue : theme.subText },
            duration: 1500
        });
    }

    Connections {
        target: provider.keyboard
        enabled: provider.enabled
        function onCapsLockChanged() { provider.lockEvent(Lang.i18n("Caps Lock"), provider.keyboard.capsLock, "input-caps-on"); }
        function onNumLockChanged() { provider.lockEvent(Lang.i18n("Num Lock"), provider.keyboard.numLock, "input-num-on"); }
        function onLayoutShortNameChanged() {
            if (!provider.keyboard.layoutShortName) return;
            provider.manager.flash({
                key: "layout",
                icon: "input-keyboard-symbolic",
                color: provider.theme.blue,
                title: provider.keyboard.layoutName,
                subtitle: Lang.i18n("Keyboard layout"),
                trailing: { type: "text", text: provider.keyboard.layoutShortName.toUpperCase(), color: provider.theme.text },
                duration: 1800
            });
        }
    }
}
