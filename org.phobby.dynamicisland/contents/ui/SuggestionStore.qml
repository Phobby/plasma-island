/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Where the suggestions' learning (Suggestions.js) is kept: one small file,
    ~/.local/share/dynamicisland/suggestions.json, written through the native
    core's LocalTools. Without the native core it is kept in the widget's
    settings instead (suggestionsData), so nothing is lost either way.

    The island and the settings page each have one of these; both read the
    file anew whenever they need it, so what one writes the other sees.
*/
import QtQuick
import "Suggestions.js" as Suggestions

QtObject {
    id: store

    property var local: null                // LocalTools (LocalBridge.qml), or null
    property var cfg: null                  // the widget's settings (suggestionsData)
    readonly property bool inFile: local !== null && typeof local.writeTextFile === "function"
    // Tests point this somewhere else.
    property string path: local !== null ? local.dataHome() + "/dynamicisland/suggestions.json" : ""
    // Counts the writes made here (bindings that show the learning follow it).
    property int revision: 0

    function read(): var {
        return Suggestions.parse(inFile ? local.readTextFile(path, 65536) : cfg !== null ? String(cfg.suggestionsData || "") : "");
    }
    function write(state: var): void {
        const text = Suggestions.text(state);
        if (inFile) local.writeTextFile(path, text);
        else if (cfg !== null && cfg.suggestionsData !== text) cfg.suggestionsData = text;
        ++revision;
    }
}
