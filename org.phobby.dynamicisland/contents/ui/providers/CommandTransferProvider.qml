/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Downloads that no window shows: commands (apt, git clone, wget, curl, pip…,
    native CommandWatcher) and PackageKit (Discover, native PackageKitWatcher).
    What each can tell is in native/core/commandwatcher.h: bytes and speed
    where they can be seen, the stage for apt, an exact percentage only from
    PackageKit; never a made-up total. How a command ended is said only
    where its own records say it; else the event is a plain "Finished".

    Nothing is watched while every kind is switched off: the native objects
    are only made when one is on.

    A command is shown once it has lasted `minSeconds`; a plain downloader
    (wget, curl…) also has to have fetched `minBytes`, so the many small
    requests of scripts stay out. One that ends before it was shown only gets
    its end event, and a small plain download none.
*/
import QtQuick
import ".."
import "../TransferFormat.js" as Fmt

Item {
    id: provider

    required property TransferHub hub
    property var core: null               // NativeBridge
    property bool enabled: true
    // Whether the end is said ("Downloaded"…); off: it only leaves the list.
    property bool announce: true
    property bool packages: true          // apt, PackageKit
    property bool clones: true            // git clone
    property bool tools: true             // wget, curl, pip…
    property bool background: false       // also what no terminal started (unattended-upgrades…)
    property real minSeconds: 1
    property real minBytes: 1048576
    property string addedCommands: ""     // names, one per line
    property string removedCommands: ""

    readonly property var table: Fmt.commandTable(packages, clones, tools, addedCommands, removedCommands)
    readonly property bool wantsCommands: enabled && core !== null && table.length > 0
    readonly property bool wantsPackageKit: enabled && core !== null && packages
    property var commands: null
    property var packageKit: null
    onWantsCommandsChanged: Qt.callLater(apply)
    onWantsPackageKitChanged: Qt.callLater(apply)
    onTableChanged: Qt.callLater(apply)
    onBackgroundChanged: Qt.callLater(apply)
    Component.onCompleted: apply()
    function apply(): void {
        if (wantsCommands && commands === null && typeof core.commandWatcher === "function") commands = core.commandWatcher();
        if (commands !== null) {
            commands.showBackground = background;
            commands.commands = table;
            commands.enabled = wantsCommands;
        }
        if (wantsPackageKit && packageKit === null && typeof core.packageKitWatcher === "function") packageKit = core.packageKitWatcher();
        if (packageKit !== null) {
            packageKit.showBackground = background;
            packageKit.enabled = wantsPackageKit;
        }
        if (!wantsCommands) drop("c");
        if (!wantsPackageKit) drop("p");
    }
    Component.onDestruction: {
        if (commands !== null) commands.enabled = false;
        if (packageKit !== null) packageKit.enabled = false;
    }

    property var tracked: ({})            // "c<id>" / "p<id>" → TransferActivity
    property var waiting: []
    Component { id: transferComponent; TransferActivity {} }
    function drop(prefix: string): void {
        for (const key in tracked) {
            if (key.charAt(0) !== prefix) continue;
            const t = tracked[key];
            delete tracked[key];
            hub.finish(t, true);
            t.destroy();
        }
        waiting = waiting.filter(k => k.charAt(0) !== prefix);
    }

    function stageText(kind: string, stage: string): string {
        if (kind !== "packages") return Lang.i18n("Downloading");
        return stage === "lists" ? Lang.i18n("Updating package lists") : stage === "download" ? Lang.i18n("Downloading packages")
             : stage === "install" ? Lang.i18n("Installing packages") : Lang.i18n("Updating");
    }
    function begin(key: string, properties: var): void {
        if (tracked[key]) return;
        const t = transferComponent.createObject(provider, Object.assign({ transferId: "cmd-" + key, startedAt: hub.clock() }, properties));
        tracked[key] = t;
        waiting = waiting.concat([key]);
    }
    function mayShow(t: var): bool {
        return hub.clock() - t.startedAt >= minSeconds * 1000 && (t.kind !== "download" || t.processedBytes >= minBytes);
    }
    Timer {
        interval: 250
        repeat: true
        running: provider.waiting.length > 0
        onTriggered: {
            for (const key of provider.waiting.slice()) {
                const t = provider.tracked[key];
                if (!t || !provider.mayShow(t)) continue;
                provider.waiting = provider.waiting.filter(k => k !== key);
                t.shown = true;
                provider.hub.add(t);
            }
        }
    }
    function end(key: string, outcome: string, bytes: real, path: string): void {
        const t = tracked[key];
        if (!t) return;
        delete tracked[key];
        waiting = waiting.filter(k => k !== key);
        t.state = outcome;
        t.endedAt = hub.clock();
        if (bytes > 0) t.processedBytes = bytes;
        if (path.length > 0) { t.openUrl = "file://" + path; t.openIsFolder = true; }
        // Never shown and nothing to say: a small plain download, or a command that was over at
        // once and left no word on how it went ("apt install" of what is there already).
        const brief = t.endedAt - t.startedAt < minSeconds * 1000;
        const quiet = !t.shown && (t.kind === "download" ? t.processedBytes < minBytes : outcome === "unknown" && brief);
        hub.finish(t, quiet || !announce);
        t.destroy(1000);
    }

    Connections {
        target: provider.commands
        function onStarted(id, info) {
            if (!provider.wantsCommands) return;
            const packages = info.kind === "packages", clone = info.kind === "clone";
            provider.begin("c" + id, {
                kind: info.kind,
                icon: packages ? "system-software-install-symbolic" : clone ? "folder-download-symbolic" : "download",
                // only the command's name, its sub-command, the host and the repository's name are ever known here
                source: clone ? (info.host || info.name) : info.name,
                fileName: packages ? info.action : clone ? info.repo : info.host,
                detail: provider.stageText(info.kind, ""),
                doneTitle: !packages ? "" : info.action === "update" ? Lang.i18n("Updated") : /install/.test(info.action) ? Lang.i18n("Installed") : ""
            });
        }
        function onProgress(id, bytes, speed, stage) {
            const t = provider.tracked["c" + id];
            if (!t) return;
            t.processedBytes = bytes;
            t.speed = speed;
            t.detail = provider.stageText(t.kind, stage);
        }
        function onFinished(id, outcome, bytes, path) { provider.end("c" + id, outcome, bytes, path); }
    }
    Connections {
        target: provider.packageKit
        function onStarted(id, info) {
            if (!provider.wantsPackageKit) return;
            provider.begin("p" + id, {
                kind: "packages",
                icon: "system-software-install-symbolic",
                source: "PackageKit",
                fileName: info.action,
                detail: provider.stageText("packages", ""),
                doneTitle: info.action === "update" || info.action === "upgrade" ? Lang.i18n("Updated") : info.action === "install" ? Lang.i18n("Installed") : ""
            });
        }
        function onProgress(id, percent, speed, remaining, stage) {
            const t = provider.tracked["p" + id];
            if (!t) return;
            t.percent = percent;
            t.speed = speed;
            t.etaSeconds = remaining > 0 ? remaining : -1;
            t.detail = provider.stageText("packages", stage);
        }
        function onFinished(id, outcome) { provider.end("p" + id, outcome, 0, ""); }
    }
}
