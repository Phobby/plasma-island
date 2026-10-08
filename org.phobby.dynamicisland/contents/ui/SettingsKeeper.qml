/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The island's settings, kept beyond the widget. Plasma deletes a widget's
    settings the moment the widget is taken off the desktop: put back, the
    island came as new. So the settings are also written to a file of the
    island's own (settings.json in its data folder, readable by the owner
    only), a moment after any of them changed, and a widget that is new reads
    them from there once.

    "New" is a widget that has never been looked at here (`settingsKept` is
    still false in its own settings) while the file was written by another one
    (Plasma numbers its widgets; a widget put back gets a new number). A widget
    that was there before this existed has nothing to read: it only starts
    writing. To come as new on purpose: delete the file, or use Defaults.

    Not kept: what a settings page only previews, and what the island notes for
    itself. Passwords and keys were never in the settings (KDE Wallet).
    Needs the native module (reading and writing a file).
*/
import QtQuick

QtObject {
    id: keeper

    property var cfg: null                  // Plasmoid.configuration
    property var local: null                // LocalTools
    property int appletId: 0
    // "" = settings.json in the island's data folder
    property string file: ""
    function path(): string { return file.length > 0 ? file : local.dataHome() + "/dynamicisland/settings.json"; }
    property int writeAfter: 1500
    signal restored(int count)

    readonly property var skipped: ["settingsKept", "previewActive", "previewMode", "previewSource", "previewStyle", "previewTop", "previewOffsetX",
                                    "previewFollowStyle", "systemScheme", "calendarStatus", "updateAsked", "installedVersion"]
    // (asked for each time: when `cfg` or `local` has only just been set, nothing here may lag behind it)
    // (Plasma's map also lists every setting's default, as "<name>Default": those are not settings)
    function kept(): var {
        if (cfg === null || typeof cfg.keys !== "function") return [];
        const all = cfg.keys();
        return all.filter(k => skipped.indexOf(k) < 0 && !(k.endsWith("Default") && all.indexOf(k.slice(0, -7)) >= 0)).sort();
    }
    function values(): var {
        const out = {};
        for (const k of kept()) {
            const v = cfg[k];
            if (typeof v === "string" || typeof v === "number" || typeof v === "boolean") out[k] = v;
        }
        return out;
    }
    // Every setting is read here: this changes when any of them does.
    readonly property string snapshot: ready ? JSON.stringify(values()) : ""
    property bool ready: false
    property string written: ""

    function start(): void {
        const keys = kept();
        if (ready || cfg === null || local === null || keys.length === 0) return;
        if (cfg.settingsKept !== true) {
            let earlier = null;
            try { earlier = JSON.parse(local.readTextFile(path(), 8 * 1024 * 1024)); } catch (e) { earlier = null; }
            if (earlier && typeof earlier === "object" && earlier.values && typeof earlier.values === "object" && earlier.applet !== appletId) {
                let count = 0;
                for (const k of keys) {
                    const v = earlier.values[k];
                    // (only what this version knows, and as what it knows it)
                    if (v === undefined || typeof v !== typeof cfg[k] || cfg[k] === v) continue;
                    cfg[k] = v;
                    ++count;
                }
                if (count > 0) restored(count);
            }
            cfg.settingsKept = true;
        }
        ready = true;
    }
    function write(): void {
        if (!ready || local === null || snapshot.length === 0 || snapshot === written) return;
        if (local.writePrivateFile(path(), JSON.stringify({ applet: appletId, values: JSON.parse(snapshot) }))) written = snapshot;
    }
    onLocalChanged: start()
    onCfgChanged: start()
    Component.onCompleted: start()
    onSnapshotChanged: if (ready) saver.restart()
    readonly property Timer saver: Timer { interval: keeper.writeAfter; onTriggered: keeper.write() }
}
