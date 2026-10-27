/*
    SPDX-License-Identifier: GPL-2.0-or-later

    What the settings window remembers of itself, not of the island: which
    folding parts (SettingsFold) were left open. Kept in a file of its own
    (~/.config/dynamicisland-settings-ui.conf), not in the widget's settings:
    opening a part changes nothing to apply.
*/
pragma Singleton
import QtQuick
import QtCore

QtObject {
    id: memory

    readonly property Settings store: Settings {
        location: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/dynamicisland-settings-ui.conf"
        category: "Folds"
        property string open: "{}"
    }
    readonly property var opened: { try { const v = JSON.parse(store.open || "{}"); return v && typeof v === "object" ? v : {}; } catch (e) { return {}; } }
    function isOpen(id: string): bool { return id.length > 0 && opened[id] === true; }
    function setOpen(id: string, open: bool): void {
        if (id.length === 0 || isOpen(id) === open) return;
        const next = Object.assign({}, opened);
        if (open) next[id] = true; else delete next[id];
        store.open = JSON.stringify(next);
    }
}
