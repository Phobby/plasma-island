/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Browser downloads, from two sources:
      1. Plasma Browser Integration: with its browser extension installed,
         downloads are reported as KDE jobs (percentage, speed, remaining time).
      2. Download-folder watcher (native): partial files (*.part, *.crdownload,
         …) growing in the download folder. Works for every browser — also
         Flatpak/Snap browsers that cannot reach Browser Integration — but the
         final size is unknown: bytes + speed only, no percentage/ETA. It ends
         as "Downloaded" (the file is there under its final name) or
         "Cancelled" (it is not); never as "Failed", which a folder cannot tell.
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
    // Whether the end is said ("Downloaded"…); off: it only leaves the list.
    property bool announce: true

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
    // A download is shown as a live activity once it has lasted `minSeconds` (a file that is
    // there at once only gets its "Downloaded"); a partial file that comes and goes within
    // that time without a file to show for it is not mentioned at all.
    property real minSeconds: 1
    property var watched: ({})            // watcher's id → TransferActivity
    property var waiting: []              // ids not shown yet
    Component { id: transferComponent; TransferActivity {} }

    Binding { target: provider.core; property: "downloadsEnabled"; value: provider.enabled; when: provider.core !== null }

    function appName(application: string): string {
        const name = String(application || "").replace(/-bin$/, "");
        return name.length > 0 ? name.charAt(0).toUpperCase() + name.slice(1) : Lang.i18n("Browser");
    }
    function show(id: string): void {
        const t = watched[id];
        waiting = waiting.filter(x => x !== id);
        if (!t) return;
        // Browser Integration already reports this one as a job?
        if (t.fileName.length > 0 && hub.transfers.some(x => x !== t && x.kind === "download" && x.fileName === t.fileName)) { t.hidden = true; return; }
        t.shown = true;
        hub.add(t);
    }
    Connections {
        target: provider.core
        ignoreUnknownSignals: true
        function onDownloadStarted(id, fileName, application) {
            if (!provider.enabled || provider.watched[id]) return;
            const t = transferComponent.createObject(provider, {
                transferId: "dl-" + id,
                kind: "download",
                icon: "download",
                source: provider.appName(application),
                fileName: fileName,
                detail: Lang.i18n("Downloading"),
                startedAt: provider.hub.clock()
            });
            t.shown = false; t.hidden = false;
            provider.watched[id] = t;
            provider.waiting = provider.waiting.concat([id]);
        }
        // (browsers rename the partial file while they write it: the name becomes known)
        function onDownloadRenamed(id, fileName) {
            const t = provider.watched[id];
            if (t) t.fileName = fileName;
        }
        function onDownloadProgress(id, bytes, speed, stalled) {
            const t = provider.watched[id];
            if (!t) return;
            t.processedBytes = bytes;
            t.speed = speed;
            t.stalled = stalled;
            // Shown from here, not by a clock: sizes are only told while the file is there, so one
            // that has vanished meanwhile (and is being waited for) does not turn up as a download.
            if (provider.waiting.indexOf(id) >= 0 && provider.hub.clock() - t.startedAt >= provider.minSeconds * 1000) provider.show(id);
        }
        function onDownloadFinished(id, finalPath, outcome, bytes, host) {
            const t = provider.watched[id];
            if (!t) return;
            delete provider.watched[id];
            const wasWaiting = provider.waiting.indexOf(id) >= 0;
            provider.waiting = provider.waiting.filter(x => x !== id);
            const done = outcome === "done";
            t.state = done ? "done" : "cancelled";
            if (done) {
                t.fileName = Fmt.baseName(finalPath);
                t.processedBytes = bytes;
                t.totalBytes = bytes;
                if (host.length > 0) t.source = t.source + " · " + host;
                t.openUrl = "file://" + finalPath.replace(/\/[^\/]*$/, "");
                t.openIsFolder = true;
            }
            // not a word about: one the job list reports, and one that was gone again before it was shown
            provider.hub.finish(t, !provider.announce || t.hidden === true || (!done && wasWaiting));
            t.destroy(1000);
        }
    }
}
