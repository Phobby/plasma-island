/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Wrapper around the native core module (native/core). Loaded through a
    Loader in main.qml: when the module is not installed this file fails to
    load and every feature depending on it hides itself.
*/
import QtQuick
import org.phobby.dynamicisland.core as Core

Item {
    id: bridge

    readonly property bool available: true
    property bool pipewireEnabled: true

    readonly property var microphoneApps: pipewire.microphoneApps
    readonly property var cameraApps: pipewire.cameraApps
    readonly property var screenCastApps: pipewire.screenCastApps

    signal screenUnlocked()
    // KDE Connect telephony: event = ringing | talking | missedCall | disconnected …
    signal callEvent(string event, string number, string contactName, string devicePath)

    function startDetached(program: string, args: var): bool {
        return launcher.startDetached(program, args || []);
    }
    function call(systemBus: bool, service: string, path: string, iface: string, method: string, args: var, callback: var): void {
        launcher.call(systemBus, service, path, iface, method, args || [], callback);
    }

    Core.PipeWireWatcher {
        id: pipewire
        enabled: bridge.pipewireEnabled
    }
    Core.Launcher {
        id: launcher
    }
    Core.DBusSignalWatcher {
        service: "org.freedesktop.ScreenSaver"
        path: "/ScreenSaver"
        iface: "org.freedesktop.ScreenSaver"
        member: "ActiveChanged"
        onTriggered: (args) => { if (args.length > 0 && args[0] === false) bridge.screenUnlocked(); }
    }
    Core.DBusSignalWatcher {
        iface: "org.kde.kdeconnect.device.telephony"
        member: "callReceived"
        onTriggered: (args, path) => bridge.callEvent(args[0] ?? "", args[1] ?? "", args[2] ?? "", path)
    }
}
