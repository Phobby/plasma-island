/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Turns the KDE jobs (JobsBackend) that belong to one provider into
    TransferActivity objects on the TransferHub. Each provider sets `kind`
    (see TransferFormat.classify) and a `describe(info, transfer)` function
    that fills in source / target / file name / icon.
*/
import QtQuick
import "TransferFormat.js" as Fmt

Item {
    id: source

    required property var jobs            // JobsBackend
    required property TransferHub hub
    required property string kind         // kio | kdeconnect | removable | browser
    property var describe: function (info, t) {}
    property bool enabled: true

    property var map: ({})                // job id → TransferActivity

    Component { id: transferComponent; TransferActivity {} }

    function sync(): void {
        if (!enabled) return;
        const seen = {};
        for (const info of jobs.jobs) {
            if (Fmt.classify(info) !== kind) continue;
            seen[info.id] = true;
            let t = map[info.id];
            if (!t) {
                t = transferComponent.createObject(source, { transferId: kind + "-" + info.id });
                const job = info.job;
                if (job && job.suspendable) {
                    t.suspendFn = () => job.suspend();
                    t.resumeFn = () => job.resume();
                }
                if (job && job.killable) t.cancelFn = () => job.kill();
                map[info.id] = t;
                hub.add(t);
            }
            describe(info, t);
            t.percent = info.total > 0 || info.percentage > 0 ? info.percentage : -1;
            t.speed = info.speed;
            t.processedBytes = info.processed;
            t.totalBytes = info.total;
            t.suspended = info.suspended;
        }
        // A job that disappears without a "finished" transition was killed
        // (cancelled in Dolphin, in the island, or the app quit): report it.
        for (const id in map) {
            if (!seen[id] && map[id].state === "running") {
                const t = map[id];
                delete map[id];
                t.state = "cancelled";
                hub.finish(t);
                t.destroy(1000);
            }
        }
    }

    function finish(info: var): void {
        const t = map[info.id];
        if (!t) return;
        delete map[info.id];
        describe(info, t);
        t.state = info.cancelled ? "cancelled" : info.error ? "failed" : "done";
        t.errorText = info.errorText;
        if (!t.openUrl && info.destUrl) t.openUrl = info.destUrl;
        hub.finish(t);
        t.destroy(1000);
    }

    Connections {
        target: source.jobs
        function onJobsChanged() { source.sync(); }
        function onJobFinished(info) { source.finish(info); }
    }
    Component.onCompleted: sync()
}
