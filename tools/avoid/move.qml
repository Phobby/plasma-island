// SPDX-License-Identifier: GPL-2.0-or-later
// A KWin script for tools/avoid-check: moves the test window by its geometry, 20 ms a step, along a
// path ([[x, y], …], the window's top left; the tool writes it in place of PATH), then logs "AVOID end".
import QtQuick
import org.kde.kwin

Item {
    property var win: null
    property var path: PATH
    property int step: 0
    Component.onCompleted: {
        for (const w of Workspace.stackingOrder) if (w.resourceClass === "org.kde.kcalc") win = w;
        console.info("AVOID start", win ? "window" : "no window", path.length);
    }
    Timer {
        interval: 20; repeat: true; running: win !== null && path.length > 0
        onTriggered: {
            if (step >= path.length) { running = false; console.info("AVOID end"); return; }
            const g = win.frameGeometry;
            win.frameGeometry = Qt.rect(path[step][0], path[step][1], g.width, g.height);
            ++step;
        }
    }
}
