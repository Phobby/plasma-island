/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Charging / unplugged / low battery / fully charged / power profile events.
    Hidden automatically on machines without an internal battery (except the
    power profile event, which also exists on desktops).
*/
import QtQuick
import ".."

Item {
    id: provider

    required property ActivityManager manager
    required property PlasmaBackend backend
    required property var power
    required property Theme theme
    property bool enabled: true
    property int lowThreshold: 20
    property int criticalThreshold: 10

    readonly property bool hasBattery: backend.hasBattery
    readonly property int percent: backend.batteryPercent
    property int lastWarned: 101

    function batteryEvent(title: string, color: color, charging: bool, extra: var): void {
        manager.flash(Object.assign({
            key: "power",
            icon: charging ? "battery-100-charging-symbolic" : "battery-060-symbolic",
            color: color,
            title: title,
            trailing: { type: "battery", value: percent / 100, charging: charging, color: color, text: percent + "%" }
        }, extra || {}));
    }

    Connections {
        target: provider.backend
        enabled: provider.enabled && provider.hasBattery
        function onBatteryPluggedInChanged() {
            if (provider.backend.batteryPluggedIn) {
                provider.batteryEvent(i18n("Charging"), provider.theme.live, true);
                provider.lastWarned = 101;
            } else {
                provider.batteryEvent(i18n("Charger disconnected"), provider.percent <= provider.lowThreshold ? provider.theme.red : provider.theme.text, false);
            }
        }
        function onBatteryFullChanged() {
            if (provider.backend.batteryFull) provider.batteryEvent(i18n("Fully charged"), provider.theme.live, false);
        }
        function onBatteryPercentChanged() {
            const p = provider.percent;
            if (provider.backend.batteryPluggedIn) return;
            for (const t of [provider.criticalThreshold, provider.lowThreshold]) {
                if (p <= t && provider.lastWarned > t) {
                    provider.lastWarned = t;
                    provider.batteryEvent(i18n("Low battery"), provider.theme.red, false,
                                          { icon: "battery-010-symbolic", pulse: true, subtitle: i18n("%1% remaining", p), duration: 5000 });
                    return;
                }
            }
        }
    }

    Connections {
        target: provider.power
        enabled: provider.enabled
        function onProfileChanged() {
            const p = provider.power.profile;
            if (!p) return;
            provider.manager.flash({
                key: "power-profile",
                icon: provider.power.iconFor(p),
                color: p === "performance" ? provider.theme.red : p === "power-saver" ? provider.theme.live : provider.theme.blue,
                title: provider.power.nameFor(p),
                subtitle: i18n("Power profile")
            });
        }
    }
}
