/*
    SPDX-License-Identifier: GPL-2.0-or-later
    System updates (PackageKit, via the native core). A transient event when
    new updates appear; clicking it opens Discover's update page.
*/
import QtQuick
import ".."

Item {
    id: provider

    required property ActivityManager manager
    required property Theme theme
    property var core: null
    property bool enabled: true

    readonly property int count: core ? core.updateCount : 0
    property int lastAnnounced: 0

    function openDiscover(): void {
        if (core) core.startDetached("plasma-discover", ["--mode", "update"]);
    }

    onCountChanged: {
        if (enabled && count > lastAnnounced) {
            manager.flash({
                key: "updates",
                icon: "system-software-update",
                color: core.securityUpdateCount > 0 ? theme.red : theme.blue,
                title: i18np("%1 update available", "%1 updates available", count),
                subtitle: core.securityUpdateCount > 0 ? i18np("%1 security update", "%1 security updates", core.securityUpdateCount) : i18n("Click to open Discover"),
                trailing: { type: "button", text: i18n("Update") },
                activate: () => provider.openDiscover(),
                duration: 6000
            });
        }
        lastAnnounced = count;
    }
}
