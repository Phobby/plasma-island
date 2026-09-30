/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Bluetooth through BluezQt (BlueZ). Battery comes from BlueZ's Battery1
    interface: one value per device (earbuds' left/right/case levels are not
    exposed by BlueZ).
*/
import QtQuick
import org.kde.bluezqt as BluezQt

Item {
    id: bt

    readonly property bool available: BluezQt.Manager.adapters.length > 0
    readonly property bool enabled: BluezQt.Manager.bluetoothOperational
    readonly property var connectedDevices: BluezQt.Manager.connectedDevices

    function setEnabled(on: bool): void {
        BluezQt.Manager.bluetoothBlocked = !on;
        BluezQt.Manager.adapters.forEach(adapter => { adapter.powered = on; });
    }

    // -1 when the device reports no battery
    function batteryOf(device: var): int {
        return device && device.battery ? device.battery.percentage : -1;
    }

    function iconFor(device: var): string {
        switch (device ? device.type : -1) {
        case BluezQt.Device.Headset: return "audio-headset-symbolic";
        case BluezQt.Device.Headphones: return "audio-headphones-symbolic";
        case BluezQt.Device.OtherAudio: return "audio-speakers-symbolic";
        case BluezQt.Device.Keyboard: return "input-keyboard-symbolic";
        case BluezQt.Device.Mouse: return "input-mouse-symbolic";
        case BluezQt.Device.Joypad: return "input-gaming-symbolic";
        case BluezQt.Device.Phone: return "smartphone-symbolic";
        case BluezQt.Device.Tablet: return "input-tablet-symbolic";
        default: return device && device.icon ? device.icon + "-symbolic" : "network-bluetooth-activated-symbolic";
        }
    }
}
