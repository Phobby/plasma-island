/*
    SPDX-License-Identifier: GPL-2.0-or-later
    KDE job tracking (KIO copy/move/delete/extract, downloads, KDE Connect
    transfers…) through the notification server's job model.
*/
import QtQuick
import org.kde.notificationmanager as NotificationManager

Item {
    id: jobsBackend

    // { summary, app, icon, destUrl, error (bool), errorText }
    signal jobFinished(var info)

    // Running jobs: [{ id, summary, app, icon, percentage, suspended, speed, eta, detail, job }]
    property var jobs: []
    readonly property int count: jobs.length
    readonly property real totalProgress: {
        if (jobs.length === 0) return 0;
        let sum = 0;
        for (const j of jobs) sum += Math.max(0, j.percentage);
        return sum / jobs.length / 100;
    }

    function formatBytes(b: real): string {
        const units = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (b >= 1024 && i < units.length - 1) { b /= 1024; ++i; }
        return (i === 0 ? Math.round(b) : b.toFixed(b >= 10 ? 0 : 1)) + " " + units[i];
    }
    function formatEta(seconds: real): string {
        if (!(seconds > 0) || !isFinite(seconds)) return "";
        if (seconds < 60) return i18nc("@info remaining time", "%1 s left", Math.round(seconds));
        if (seconds < 3600) return i18nc("@info remaining time", "%1 min left", Math.round(seconds / 60));
        return i18nc("@info remaining time", "%1 h left", (seconds / 3600).toFixed(1));
    }

    NotificationManager.Notifications {
        id: jobsModel
        showNotifications: false
        showJobs: true
        showExpired: true
        showDismissed: true
        groupMode: NotificationManager.Notifications.GroupDisabled
        sortMode: NotificationManager.Notifications.SortByDate
    }

    property var rows: []
    function rebuild(): void {
        jobs = rows.filter(r => r && r.running).map(r => r.info);
    }

    Instantiator {
        model: jobsModel
        delegate: QtObject {
            id: row
            required property var model
            readonly property var job: model.jobDetails ?? null
            readonly property int state: model.jobState ?? 0
            readonly property bool running: state === NotificationManager.Notifications.JobStateRunning
                                             || state === NotificationManager.Notifications.JobStateSuspended
            readonly property var info: ({
                id: model.notificationId,
                summary: model.summary || "",
                app: model.applicationName || "",
                icon: model.applicationIconName || "",
                percentage: model.percentage ?? 0,
                suspended: state === NotificationManager.Notifications.JobStateSuspended,
                speed: job ? job.speed : 0,
                eta: job && job.speed > 0 && job.totalBytes > job.processedBytes ? (job.totalBytes - job.processedBytes) / job.speed : 0,
                detail: job ? (job.descriptionValue2 || job.descriptionValue1 || "") : "",
                processed: job ? job.processedBytes : 0,
                total: job ? job.totalBytes : 0,
                job: job
            })
            property int lastState: state
            onStateChanged: {
                const was = lastState;
                lastState = state;
                if (state === NotificationManager.Notifications.JobStateStopped && was !== state) {
                    jobsBackend.jobFinished({
                        summary: model.summary || "",
                        app: model.applicationName || "",
                        icon: model.applicationIconName || "",
                        destUrl: job ? String(job.destUrl || job.effectiveDestUrl || "") : "",
                        error: (model.jobError || "").length > 0,
                        errorText: model.jobError || ""
                    });
                }
                Qt.callLater(jobsBackend.rebuild);
            }
            onInfoChanged: Qt.callLater(jobsBackend.rebuild)
            Component.onCompleted: { jobsBackend.rows.push(row); Qt.callLater(jobsBackend.rebuild); }
            Component.onDestruction: {
                const i = jobsBackend.rows.indexOf(row);
                if (i >= 0) jobsBackend.rows.splice(i, 1);
                Qt.callLater(jobsBackend.rebuild);
            }
        }
    }
}
