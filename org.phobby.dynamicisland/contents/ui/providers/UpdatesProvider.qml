/*
    SPDX-License-Identifier: GPL-2.0-or-later
    System updates (PackageKit, via the native core). A transient event when
    new updates appear; clicking it opens Discover's update page. The same
    updates are announced only once: `announced` (stored in the configuration)
    survives a restart of the shell and a check that briefly reports nothing.
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
    // How many updates the user has already been told about.
    property int announced: 0
    signal announcedEdited(int value)

    function openDiscover(): void {
        if (core) core.startDetached("plasma-discover", ["--mode", "update"]);
    }

    onCountChanged: {
        // Fewer than announced: believed only once it has stayed that way
        // (the count is 0 right after a start and while a check fails).
        settle.restart();
        if (count <= announced) return;
        announcedEdited(count);
        if (enabled) {
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
    }
    Timer {
        id: settle
        interval: 30 * 60000
        onTriggered: if (provider.count < provider.announced) provider.announcedEdited(provider.count)
    }
}
