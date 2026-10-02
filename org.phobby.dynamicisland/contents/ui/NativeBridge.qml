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
    property bool updatesEnabled: true

    readonly property bool updatesAvailable: updates.available
    readonly property int updateCount: updates.count
    readonly property int securityUpdateCount: updates.securityCount

    readonly property var microphoneApps: pipewire.microphoneApps
    readonly property var cameraApps: pipewire.cameraApps
    readonly property var screenCastApps: pipewire.screenCastApps

    // D-Bus API (org.phobby.DynamicIsland), see native/core/islandservice.h
    readonly property bool serviceRegistered: service.registered
    signal activityPushed(string id, var properties)
    signal activityFinished(string id, string status)
    signal eventFlashed(var properties)
    function activityClicked(id: string): void { service.emitClicked(id); }

    // Browser downloads seen in the download folder (partial files)
    property bool downloadsEnabled: true
    property var downloadDirectories: []
    onDownloadDirectoriesChanged: if (downloads.item) downloads.item.directories = downloadDirectories
    signal downloadStarted(string id, string fileName, string application)
    signal downloadProgress(string id, real bytes, real speed)
    signal downloadFinished(string id, string finalPath, bool success)

    signal screenUnlocked()
    // KDE Connect telephony: event = ringing | talking | missedCall | disconnected …
    signal callEvent(string event, string number, string contactName, string devicePath)

    function startDetached(program: string, args: var): bool {
        return launcher.startDetached(program, args || []);
    }
    // The given paths that exist ("~/" = home); [] with an older native module.
    function existingPaths(paths: var): var {
        return typeof launcher.existingPaths === "function" ? launcher.existingPaths(paths) : [];
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
    Core.IslandService {
        id: service
        onPushed: (id, props) => bridge.activityPushed(id, props)
        onFinished: (id, status) => bridge.activityFinished(id, status)
        onFlashed: props => bridge.eventFlashed(props)
    }
    Loader {
        id: downloads
        source: "DownloadBridge.qml"
        onLoaded: {
            item.enabled = Qt.binding(() => bridge.downloadsEnabled);
            if (bridge.downloadDirectories.length > 0) item.directories = bridge.downloadDirectories;
        }
        onStatusChanged: if (status === Loader.Error) console.info("org.phobby.dynamicisland: native module too old for download watching; run install.sh again")
    }
    // Passwords in KWallet; callbacks get (ok, value). See native/core/secretstore.h
    readonly property bool secretsAvailable: secrets.item !== null
    function readSecret(key: string, callback: var): void {
        if (secrets.item) secrets.item.read(key, callback); else callback(false, "");
    }
    function writeSecret(key: string, value: string, callback: var): void {
        if (secrets.item) secrets.item.write(key, value, callback); else callback(false, "");
    }
    function removeSecret(key: string): void {
        if (secrets.item) secrets.item.remove(key);
    }
    // OAuth sign-in in the browser: local redirect target, see native/core/loopbackserver.h
    readonly property var loopback: loopbackLoader.item
    Loader {
        id: loopbackLoader
        source: "LoopbackBridge.qml"
        onStatusChanged: if (status === Loader.Error) console.info("org.phobby.dynamicisland: native module too old for account sign-in; run install.sh again")
    }
    // Local notes apps: run their command, read their files. See native/core/localtools.h
    readonly property var local: localLoader.item
    Loader {
        id: localLoader
        source: "LocalBridge.qml"
        onStatusChanged: if (status === Loader.Error) console.info("org.phobby.dynamicisland: native module too old for local notes apps; run install.sh again")
    }
    Loader {
        id: secrets
        source: "SecretBridge.qml"
        onStatusChanged: if (status === Loader.Error) console.info("org.phobby.dynamicisland: native module too old for the password store; run install.sh again")
    }
    Connections {
        target: downloads.item
        ignoreUnknownSignals: true
        function onStarted(id, fileName, app) { bridge.downloadStarted(id, fileName, app); }
        function onProgress(id, bytes, speed) { bridge.downloadProgress(id, bytes, speed); }
        function onFinished(id, finalPath, ok) { bridge.downloadFinished(id, finalPath, ok); }
    }
    Core.UpdatesChecker {
        id: updates
        enabled: bridge.updatesEnabled
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
