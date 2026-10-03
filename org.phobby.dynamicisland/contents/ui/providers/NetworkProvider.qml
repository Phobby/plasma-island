/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Wi-Fi connect/disconnect, VPN on/off events and the hotspot live activity.
*/
import QtQuick
import ".."

Item {
    id: provider

    required property ActivityManager manager
    required property var network
    required property Theme theme
    property bool enabled: true

    Connections {
        target: provider.network
        enabled: provider.enabled
        function onWifiConnected(ssid, strength) {
            provider.manager.flash({
                key: "wifi",
                icon: provider.network.signalIcon(strength),
                color: provider.theme.blue,
                title: ssid,
                subtitle: Lang.i18n("Wi-Fi connected"),
                trailing: { type: "text", text: Lang.percent(strength), color: provider.theme.subText }
            });
        }
        function onWifiDisconnected(ssid) {
            provider.manager.flash({
                key: "wifi",
                icon: "network-wireless-disconnected",
                color: provider.theme.subText,
                title: ssid,
                subtitle: Lang.i18n("Wi-Fi disconnected")
            });
        }
        function onVpnChanged(name, connected) {
            provider.manager.flash({
                key: "vpn",
                icon: "network-vpn-symbolic",
                color: connected ? provider.theme.live : provider.theme.subText,
                title: name,
                subtitle: connected ? Lang.i18n("VPN connected") : Lang.i18n("VPN disconnected")
            });
        }
    }

    Activity {
        activityId: "hotspot"
        category: "transfer"
        priority: -10
        active: provider.enabled && provider.network.hotspotActive
        icon: "network-wireless-hotspot-symbolic"
        color: provider.theme.live
        title: Lang.i18n("Hotspot on")
        subtitle: Lang.i18n("Sharing this computer's connection")
        Component.onCompleted: provider.manager.register(this)
    }
}
