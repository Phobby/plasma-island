/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Do Not Disturb toggle event (like the iPhone silent switch).
*/
import QtQuick
import ".."

Item {
    id: provider

    required property ActivityManager manager
    required property var dnd
    required property Theme theme
    property bool enabled: true
    // Notifications that arrived while DND was on (from NotificationProvider).
    property int missed: 0

    Connections {
        target: provider.dnd
        enabled: provider.enabled
        function onActiveChanged() {
            const on = provider.dnd.active;
            provider.manager.flash({
                key: "dnd",
                icon: on ? "weather-clear-night-symbolic" : "notifications-symbolic",
                color: on ? provider.theme.purple : provider.theme.subText,
                title: on ? Lang.i18n("Do Not Disturb") : Lang.i18n("Do Not Disturb off"),
                subtitle: !on && provider.missed > 0 ? Lang.i18np("%1 notification while silenced", "%1 notifications while silenced", provider.missed) : "",
                trailing: { type: "text", text: on ? Lang.i18nc("@info DND state", "On") : Lang.i18nc("@info DND state", "Off"), color: on ? provider.theme.purple : provider.theme.subText }
            });
        }
    }
}
