/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The Cloud tab on the small island, the counterpart of a menu bar's cloud
    icon. While a cloud is syncing (a sync client on this computer says so): a
    quiet live activity with a cloud and its progress, below every other
    activity; red when a sync has an error, orange when a cloud is nearly
    full. When the sync is done, a short "Synced". The indicator can be
    switched off.

    Alerts (storage nearly full or full, a sign-in that ran out, a cloud that
    cannot be reached, a sync error) come as events; a click opens the tab.
    Each is said once and again only after its pause (CloudBackend), and an
    alert still on the island goes away when its cause does.
*/
import QtQuick
import ".."

Item {
    id: provider

    required property ActivityManager manager
    required property Theme theme
    property var cloud: null                // CloudBackend
    property bool enabled: true
    signal opened(string id)

    readonly property bool showing: enabled && cloud !== null && cloud.indicator && cloud.syncing

    Activity {
        id: syncing
        activityId: "cloud-sync"
        category: "cloud"                   // not in the priority order: below every other activity
        active: provider.showing
        icon: "folder-cloud"
        color: provider.cloud !== null && provider.cloud.syncError ? provider.theme.red
             : provider.cloud !== null && provider.cloud.storageWarning ? provider.theme.orange : provider.theme.blue
        title: Lang.i18n("Syncing")
        progress: provider.cloud !== null && provider.cloud.syncProgress >= 0 ? provider.cloud.syncProgress : -2
        onClicked: provider.opened("")
        Component.onCompleted: provider.manager.register(this)
    }
    Component.onDestruction: manager.unregister(syncing)

    Connections {
        target: provider.cloud
        function onSynced(name) {
            if (!provider.enabled || !provider.cloud.indicator) return;
            provider.manager.flash({ key: "cloud-synced", icon: "folder-cloud", color: provider.theme.live, title: Lang.i18n("Synced"), subtitle: name, duration: 2500 });
        }
        function onAlert(id, kind, title, text) {
            if (!provider.enabled) return;
            provider.manager.flash({
                key: "cloud-" + id + ":" + kind,
                icon: "folder-cloud",
                color: kind === "storage" ? provider.theme.orange : provider.theme.red,
                title: title,
                subtitle: text,
                trailing: { type: "button", text: Lang.i18n("Open") },
                activate: () => provider.opened(id),
                duration: 6000
            });
        }
        function onAlertEnded(id, kind) {
            const key = "cloud-" + id + ":" + kind;
            if (provider.manager.currentEvent && provider.manager.currentEvent.key === key) provider.manager.dismissEvent();
            provider.manager.queue = provider.manager.queue.filter(e => e.key !== key);
        }
    }
}
