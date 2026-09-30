/*
    SPDX-License-Identifier: GPL-2.0-or-later
    File operations and other KDE jobs: compact = icon + progress ring,
    expanded = per-job details with pause / cancel. Completion and failure
    become transient events ("Open folder" on click).
*/
import QtQuick
import ".."

Item {
    id: provider

    required property ActivityManager manager
    required property var jobs
    required property Theme theme
    property bool enabled: true

    function iconFor(summary: string): string {
        const s = summary.toLowerCase();
        if (/cop|kopya/.test(s)) return "edit-copy-symbolic";
        if (/mov|taşı/.test(s)) return "transform-move";
        if (/delet|sil|trash|çöp/.test(s)) return "edit-delete-symbolic";
        if (/download|indir|receiv|alın/.test(s)) return "download";
        if (/extract|unpack|aç|çıkar/.test(s)) return "archive-extract";
        if (/upload|send|gönder|yükle/.test(s)) return "document-send";
        return "view-refresh-symbolic";
    }
    function parentFolder(url: string): string {
        return url.replace(/\/[^\/]*$/, "") || url;
    }

    Activity {
        id: activity
        // Handed to JobsCard.
        property var jobs: provider.jobs.jobs
        function formatBytes(b) { return provider.jobs.formatBytes(b); }
        function formatEta(s) { return provider.jobs.formatEta(s); }

        activityId: "jobs"
        category: "transfer"
        active: provider.enabled && provider.jobs.count > 0
        readonly property var first: provider.jobs.count > 0 ? provider.jobs.jobs[0] : null
        icon: !first ? "view-refresh-symbolic" : first.app === "KDE Connect" ? "smartphone-symbolic" : provider.iconFor(first.summary)
        color: provider.theme.blue
        title: provider.jobs.count > 1 ? i18np("%1 operation", "%1 operations", provider.jobs.count) : (first ? first.summary : "")
        subtitle: first ? first.detail : ""
        trailingText: provider.jobs.count > 1 ? String(provider.jobs.count) : ""
        progress: provider.jobs.totalProgress
        expanded: Component { JobsCard {} }
        Component.onCompleted: provider.manager.register(this)
    }

    Connections {
        target: provider.jobs
        enabled: provider.enabled
        function onJobFinished(info) {
            if (info.error) {
                provider.manager.flash({
                    key: "job-done",
                    icon: "dialog-error-symbolic",
                    color: provider.theme.red,
                    title: i18n("Operation failed"),
                    subtitle: info.errorText || info.summary,
                    duration: 5000
                });
                return;
            }
            const folder = info.destUrl ? info.destUrl : "";
            provider.manager.flash({
                key: "job-done",
                icon: "dialog-ok-apply-symbolic",
                color: provider.theme.live,
                title: i18n("Completed"),
                subtitle: info.summary,
                trailing: folder ? { type: "button", text: i18n("Open folder") } : null,
                activate: folder ? () => Qt.openUrlExternally(folder) : undefined
            });
        }
    }
}
