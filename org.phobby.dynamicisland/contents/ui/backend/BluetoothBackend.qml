/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Bluetooth through BluezQt (BlueZ). Battery comes from BlueZ's Battery1
    interface: one value per device (earbuds' left/right/case levels are not
    exposed by BlueZ).
    Also what the Controls page's Bluetooth panel lists and does: every known
    device, the search for new ones, connecting and pairing (the PIN, where
    one is asked, comes from Plasma's own Bluetooth agent).
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

    // Paired devices and, while searching, the ones found nearby.
    readonly property var devices: BluezQt.Manager.devices
    readonly property bool discovering: BluezQt.Manager.adapters.some(adapter => adapter.discovering)
    // BlueZ counts the search per program: another one's (Plasma's settings)
    // goes on after ours is stopped, and ours after theirs.
    function setDiscovering(on: bool): void {
        BluezQt.Manager.adapters.forEach(adapter => {
            if (!adapter.powered) return;
            if (on) adapter.startDiscovery(); else adapter.stopDiscovery();
        });
    }

    // address → true while a device is being connected, paired or let go
    property var busy: ({})
    // The device that could not be reached last, and why.
    property string failedAddress: ""
    property string failure: ""
    function mark(address: string, on: bool): void {
        const next = Object.assign({}, busy);
        if (on) next[address] = true; else delete next[address];
        busy = next;
    }
    function follow(device: var, call: var, then: var): void {
        const address = device.address;
        mark(address, true);
        call.finished.connect(done => {
            if (done.error) {
                mark(address, false);
                failedAddress = address; failure = done.errorText;
            } else if (then) {
                then();
            } else {
                mark(address, false);
            }
        });
    }
    // Connected: lets go. Paired: connects. New: pairs, trusts, then connects.
    function toggleDevice(device: var): void {
        if (!device || busy[device.address] === true) return;
        failedAddress = ""; failure = "";
        if (device.connected) follow(device, device.disconnectFromDevice(), null);
        else if (device.paired) follow(device, device.connectToDevice(), null);
        else follow(device, device.pair(), () => { device.trusted = true; follow(device, device.connectToDevice(), null); });
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
        case BluezQt.Device.Joypad: return "input-gamepad-symbolic";
        case BluezQt.Device.Phone: return "smartphone-symbolic";
        case BluezQt.Device.Tablet: return "input-tablet-symbolic";
        default: return device && device.icon ? device.icon + "-symbolic" : "network-bluetooth-activated-symbolic";
        }
    }
}
