/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Bluetooth connect / disconnect (the AirPods moment) and low device battery.
*/
import QtQuick
import ".."
import "../backend"

Item {
    id: provider

    required property ActivityManager manager
    required property BluetoothBackend bluetooth
    required property Theme theme
    property bool enabled: true
    property int lowBattery: 15

    property var known: ({})      // address → name of connected devices

    function batteryTrailing(pct: int): var {
        if (pct < 0) return null;
        return { type: "ring", value: pct / 100, color: pct <= lowBattery ? theme.red : theme.live, text: String(pct) };
    }

    Connections {
        target: provider.bluetooth
        function onConnectedDevicesChanged() { Qt.callLater(provider.diff); }
    }
    Component.onCompleted: diff()

    function diff(): void {
        const now = {};
        for (const d of bluetooth.connectedDevices) {
            now[d.address] = d.name;
            if (!(d.address in known) && enabled) {
                manager.flash({
                    key: "bt-" + d.address,
                    icon: bluetooth.iconFor(d),
                    color: theme.blue,
                    title: d.name,
                    subtitle: i18n("Connected"),
                    trailing: batteryTrailing(bluetooth.batteryOf(d))
                });
            }
        }
        for (const addr in known) {
            if (!(addr in now) && enabled) {
                manager.flash({
                    key: "bt-" + addr,
                    icon: "network-bluetooth-symbolic",
                    color: theme.subText,
                    title: known[addr],
                    subtitle: i18n("Disconnected")
                });
            }
        }
        known = now;
    }

    // Low battery warning per connected device (once until it recovers).
    Instantiator {
        model: provider.bluetooth.connectedDevices
        delegate: QtObject {
            required property var modelData
            property bool warned: false
            readonly property int pct: provider.bluetooth.batteryOf(modelData)
            onPctChanged: {
                if (pct >= 0 && pct < provider.lowBattery && !warned && provider.enabled) {
                    warned = true;
                    provider.manager.flash({
                        key: "bt-low-" + modelData.address,
                        icon: provider.bluetooth.iconFor(modelData),
                        color: provider.theme.red,
                        title: modelData.name,
                        subtitle: i18n("Battery low"),
                        trailing: provider.batteryTrailing(pct),
                        duration: 5000
                    });
                } else if (pct >= provider.lowBattery + 5) {
                    warned = false;
                }
            }
        }
    }
}
