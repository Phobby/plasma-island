/*
    SPDX-License-Identifier: GPL-2.0-or-later

    TransferHub: collects TransferActivity objects from all transfer providers.
      * one Live Activity for all running transfers: icon + progress ring
        (indeterminate when no percentage is known), count when several;
      * expanded card listing each transfer (TransfersCard);
      * when a transfer ends: "Completed"/"Sent" (with file name, open button)
        or a red "Failed" event, then it is removed.
*/
import QtQuick

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
        transfers = transfers.concat([t]);
    }

    // Called by providers when a transfer ends (state already set on `t`).
    function finish(t: TransferActivity): void {
        transfers = transfers.filter(x => x !== t);
        if (!enabled) return;
        const sent = t.kind === "upload" || t.kind === "send";
        if (t.state === "done") {
            manager.flash({
                key: "transfer-" + t.transferId,
                icon: sent ? "document-send-symbolic" : "dialog-ok-apply-symbolic",
                color: theme.live,
                title: sent ? Lang.i18n("Sent") : Lang.i18n("Completed"),
                subtitle: t.headline,
                trailing: t.openUrl ? { type: "button", text: Lang.i18n("Open") } : null,
                activate: t.openUrl ? (() => Qt.openUrlExternally(t.openUrl)) : undefined
            });
        } else {
            manager.flash({
                key: "transfer-" + t.transferId,
                icon: "dialog-error-symbolic",
                color: theme.red,
                title: Lang.i18n("Failed"),
                subtitle: t.state === "cancelled" ? Lang.i18n("Cancelled · %1", t.headline)
                        : t.errorText ? t.headline + " · " + t.errorText : t.headline,
                duration: 5000
            });
        }
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
        trailingText: hub.count > 1 ? String(hub.count) : ""
        progress: hub.indeterminate ? -2 : hub.totalProgress
        expanded: Component { TransfersCard {} }
        Component.onCompleted: hub.manager.register(this)
    }
}
