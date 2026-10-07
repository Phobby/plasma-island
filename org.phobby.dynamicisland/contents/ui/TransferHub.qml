/*
    SPDX-License-Identifier: GPL-2.0-or-later

    TransferHub: collects TransferActivity objects from all transfer providers.
      * one Live Activity for all running transfers: icon + progress ring
        (indeterminate when no percentage is known), count when several;
      * expanded card listing each transfer (TransfersCard);
      * when a transfer ends: "Downloaded"/"Completed"/"Sent" (what, how
        large, how long, a button to open it), a red "Failed", a plain
        "Cancelled", or a plain "Finished" when nothing says how it ended;
        then it is removed.
*/
import QtQuick
import "TransferFormat.js" as Fmt

Item {
    id: hub

    required property ActivityManager manager
    required property Theme theme
    property bool enabled: true

    property var transfers: []            // running TransferActivity objects
    readonly property int count: transfers.length
    readonly property bool indeterminate: transfers.length > 0 && transfers.every(t => t.percent < 0)
    readonly property real totalProgress: {
        const known = transfers.filter(t => t.percent >= 0);
        if (known.length === 0) return 0;
        return known.reduce((a, t) => a + t.percent, 0) / known.length / 100;
    }

    function add(t: TransferActivity): void {
        if (transfers.indexOf(t) >= 0) return;
        if (t.startedAt <= 0) t.startedAt = clock();
        transfers = transfers.concat([t]);
    }

    // The time (ms) transfers are stamped with; a test hands in its own.
    property var clock: () => Date.now()
    readonly property bool comma: Lang.language === "tr"
    function size(bytes: real): string { return Fmt.bytes(bytes, comma); }

    // Called by providers when a transfer ends (state already set on `t`): "Downloaded" /
    // "Completed" / "Sent" in green with what it was, how large and how long it took; a red
    // "Failed" only where something says so; a plain "Cancelled"; and a plain "Finished"
    // where nothing tells how it ended (state "unknown"). `quiet`: taken off without a word.
    function finish(t: TransferActivity, quiet: bool): void {
        transfers = transfers.filter(x => x !== t);
        if (!enabled || quiet === true) return;
        if (t.endedAt <= 0) t.endedAt = clock();
        const sent = t.kind === "upload" || t.kind === "send";
        const fetched = t.kind === "download" || t.kind === "clone" || t.kind === "receive";
        const bytes = t.totalBytes > 0 ? t.totalBytes : t.processedBytes;
        const facts = [t.headline, bytes > 0 ? size(bytes) : "", t.elapsedSeconds >= 1 ? Fmt.duration(t.elapsedSeconds) : ""].filter(s => s).join(" · ");
        const event = { key: "transfer-" + t.transferId, subtitle: facts };
        if (t.state === "done") {
            const folder = t.openUrl.length > 0 && t.openIsFolder;
            Object.assign(event, {
                icon: sent ? "document-send-symbolic" : "dialog-ok-apply-symbolic",
                color: theme.live,
                feel: "done",
                title: t.doneTitle.length > 0 ? t.doneTitle : sent ? Lang.i18n("Sent") : fetched ? Lang.i18n("Downloaded") : Lang.i18n("Completed"),
                trailing: t.openUrl ? { type: "button", text: folder ? Lang.i18n("Open folder") : Lang.i18n("Open") } : null,
                activate: t.openUrl ? (() => Qt.openUrlExternally(t.openUrl)) : undefined
            });
        } else if (t.state === "failed") {
            Object.assign(event, {
                icon: "dialog-close-symbolic",
                color: theme.red,
                title: Lang.i18n("Failed"),
                subtitle: t.errorText ? t.headline + " · " + t.errorText : t.headline,
                trailing: t.retryFn ? { type: "button", text: Lang.i18n("Try again") } : null,
                activate: t.retryFn ? t.retryFn : undefined,
                duration: 5000
            });
        } else if (t.state === "cancelled") {
            Object.assign(event, { icon: "dialog-cancel-symbolic", color: theme.subText, title: Lang.i18n("Cancelled"), subtitle: t.headline });
        } else {
            // it ended, and nothing says how
            // (Breeze has no dialog-information-symbolic: the coloured one it falls back to is a filled square as a mask)
            Object.assign(event, { icon: "help-about-symbolic", color: theme.subText, title: Lang.i18n("Finished") });
        }
        manager.flash(event);
    }

    Activity {
        id: activity
        // Handed to TransfersCard.
        property var transfers: hub.transfers
        readonly property var first: hub.transfers.length > 0 ? hub.transfers[0] : null

        activityId: "transfers"
        category: "transfer"
        active: hub.enabled && hub.count > 0
        icon: first ? first.icon : "view-refresh-symbolic"
        color: hub.theme.blue
        title: hub.count > 1 ? Lang.i18np("%1 transfer", "%1 transfers", hub.count) : (first ? first.headline : "")
        subtitle: first ? first.detail : ""
        // several: how many; one whose size is not known: how much has arrived
        trailingText: hub.count > 1 ? String(hub.count) : first && first.percent < 0 && first.processedBytes > 0 ? hub.size(first.processedBytes) : ""
        progress: hub.indeterminate ? -2 : hub.totalProgress
        expanded: Component { TransfersCard {} }
        Component.onCompleted: hub.manager.register(this)
    }
}
