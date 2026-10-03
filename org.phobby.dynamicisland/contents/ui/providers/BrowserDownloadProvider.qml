/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Browser downloads, from two sources:
      1. Plasma Browser Integration: with its browser extension installed,
         downloads are reported as KDE jobs (percentage, speed, remaining time).
      2. Download-folder watcher (native): partial files (*.part, *.crdownload,
         …) growing in the download folder. Works for every browser — also
         Flatpak/Snap browsers that cannot reach Browser Integration — but the
         final size is unknown: bytes + speed only, no percentage/ETA.
    Uploads from a browser are not visible to the system at all (see README).
*/
import QtQuick
import ".."
import "../TransferFormat.js" as Fmt

Item {
    id: provider

    required property var jobs            // JobsBackend (may be null)
    required property TransferHub hub
    property var core: null               // NativeBridge (download watcher)
    property bool enabled: true

    // 1. Browser Integration jobs
    Loader {
        active: provider.jobs !== null
        sourceComponent: JobTransferSource {
            jobs: provider.jobs
            hub: provider.hub
            kind: "browser"
            enabled: provider.enabled
            describe: function (info, t) {
                const dst = Fmt.field(info, "destination") || info.destUrl;
                t.kind = "download";
                t.icon = "download";
                t.source = info.app;
                t.fileName = Fmt.baseName(dst) || Fmt.baseName(Fmt.field(info, "source"));
                t.detail = Lang.i18n("Downloading");
                t.openUrl = dst ? String(dst).replace(/\/[^\/]*$/, "") : "";
            }
        }
    }

    // 2. Download folder watcher
    property var watched: ({})            // partial path → TransferActivity
    Component { id: transferComponent; TransferActivity {} }

    Binding { target: provider.core; property: "downloadsEnabled"; value: provider.enabled; when: provider.core !== null }

    Connections {
        target: provider.core
        ignoreUnknownSignals: true
        function onDownloadStarted(id, fileName, application) {
            if (!provider.enabled || provider.watched[id]) return;
            // Browser Integration already reports this one as a job?
            if (provider.hub.transfers.some(t => t.kind === "download" && t.fileName === fileName)) return;
            const name = application ? application.charAt(0).toUpperCase() + application.slice(1) : Lang.i18n("Browser");
            const t = transferComponent.createObject(provider, {
                transferId: "dl-" + id,
                kind: "download",
                icon: "download",
                source: name,
                fileName: fileName,
                detail: Lang.i18n("Downloading")
            });
            provider.watched[id] = t;
            provider.hub.add(t);
        }
        function onDownloadProgress(id, bytes, speed) {
            const t = provider.watched[id];
            if (!t) return;
            t.processedBytes = bytes;
            t.speed = speed;
        }
        function onDownloadFinished(id, finalPath, success) {
            const t = provider.watched[id];
            if (!t) return;
            delete provider.watched[id];
            t.state = success ? "done" : "cancelled";
            t.openUrl = success ? "file://" + finalPath.replace(/\/[^\/]*$/, "") : "";
            provider.hub.finish(t);
            t.destroy(1000);
        }
    }
}
