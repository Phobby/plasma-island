/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Where the shell's panels are, for the notch: which screens there are (in
    plasmashell's order, the primary first) and, for every panel at the top of
    a screen, how high it is and whether it hides. Asked of plasmashell's own
    scripting interface (evaluateScript: the script below only reads), when the
    notch is switched on and again whenever plasmashellrc, where the shell
    keeps its panels, changes; nothing is polled.

    Where a panel's widgets are cannot be learnt this way (their geometry
    reads as 0×0), nor at all from a widget on the desktop.
*/
import QtQuick

Item {
    id: watch

    property var core: null                 // NativeBridge, or null
    property bool enabled: false
    // [{ x, y, width, height }], plasmashell's screens; [0] is the primary one
    property var screens: []
    // [{ screen: { x, y, width, height }, height, autohide, floating }]: panels at the top of a screen
    property var topPanels: []
    // Asked and answered at least once.
    property bool ready: false

    // The top panel on the screen whose top left corner is (x, y); null if none.
    function topPanelAt(x: real, y: real): var {
        for (const p of topPanels) if (p.screen.x === x && p.screen.y === y) return p;
        return null;
    }

    readonly property string script: "var o = { screens: [], panels: [] };"
        + "for (var i = 0; i < screenCount; ++i) { var g = screenGeometry(i); o.screens.push({ x: g.x, y: g.y, width: g.width, height: g.height }); }"
        + "panels().forEach(function (p) { if (p.location != 'top' || p.screen < 0) return; var g = screenGeometry(p.screen);"
        + " o.panels.push({ screen: { x: g.x, y: g.y, width: g.width, height: g.height }, height: p.height, autohide: p.hiding == 'autohide' || p.hiding == 'dodgewindows' || p.hiding == 'windowsgobelow', floating: !!p.floating }); });"
        + "print(JSON.stringify(o));"

    function refresh(): void {
        if (!enabled || core === null || typeof core.call !== "function") return;
        core.call(false, "org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell", "evaluateScript", [script], (error, values) => {
            if (error || !values || values.length === 0) {
                console.info("org.phobby.dynamicisland: the panels could not be read:", error);
                return;
            }
            try {
                const o = JSON.parse(String(values[0]).trim());
                watch.screens = Array.isArray(o.screens) ? o.screens : [];
                watch.topPanels = Array.isArray(o.panels) ? o.panels : [];
                watch.ready = true;
            } catch (e) {
                console.info("org.phobby.dynamicisland: the panels could not be read:", e);
            }
        });
    }
    onEnabledChanged: refresh()
    onCoreChanged: refresh()
    Component.onCompleted: refresh()

    // The shell writes its panels to plasmashellrc (a new file each time: the watch is set again after every change).
    Loader {
        id: files
        active: watch.enabled && watch.core !== null
        source: "LocalBridge.qml"
        onLoaded: item.watchedPaths = ["~/.config/plasmashellrc"]
        onStatusChanged: if (status === Loader.Error) console.info("org.phobby.dynamicisland: native module too old to follow the panels; run install.sh again")
    }
    Connections {
        target: files.item
        function onPathChanged() {
            files.item.watchedPaths = [];
            rearm.restart();
        }
    }
    // (a moment later: the new file is written by then, and a panel being dragged writes many times)
    Timer {
        id: rearm
        interval: 400
        onTriggered: {
            if (files.item) files.item.watchedPaths = ["~/.config/plasmashellrc"];
            watch.refresh();
        }
    }
}
