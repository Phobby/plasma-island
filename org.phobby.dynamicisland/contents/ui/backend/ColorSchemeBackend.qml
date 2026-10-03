/*
    SPDX-License-Identifier: GPL-2.0-or-later
    "Dark mode" in Controls: switches the system colour scheme between a dark
    and a light one with plasma-apply-colorscheme. The scheme it switches away
    from is remembered (darkScheme / lightScheme, kept in the settings), so a
    custom scheme comes back on the next switch. Without one remembered it
    takes the counterpart by name (KlassyDark ↔ KlassyLight, BreezeDark ↔
    BreezeLight…), else Breeze.
*/
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: schemes

    property var core: null                 // NativeBridge
    property string darkScheme: ""
    property string lightScheme: ""
    // A scheme to remember: dark = it is the dark one.
    signal remember(bool dark, string name)

    Kirigami.Theme.colorSet: Kirigami.Theme.Window
    Kirigami.Theme.inherit: false
    // Dark = the window background of the applied scheme (kdeglobals) is dark;
    // Kirigami's colours as a fallback (without the native module).
    readonly property bool dark: windowLightness >= 0 ? windowLightness < 0.5 : Kirigami.Theme.backgroundColor.hslLightness < 0.5
    property real windowLightness: -1
    function refresh(): void {
        if (!core || !core.local) return;
        const text = core.local.readTextFile("~/.config/kdeglobals", 262144);
        const section = /^\[Colors:Window\]\s*$([\s\S]*?)(?=^\[|(?![\s\S]))/m.exec(text);
        const rgb = section ? /^BackgroundNormal=(\d+),(\d+),(\d+)/m.exec(section[1]) : null;
        windowLightness = rgb ? Qt.rgba(rgb[1] / 255, rgb[2] / 255, rgb[3] / 255, 1).hslLightness : -1;
    }
    onCoreChanged: refresh()
    Component.onCompleted: refresh()
    Connections {
        target: schemes.core
        ignoreUnknownSignals: true
        function onLocalChanged() { schemes.refresh(); }
    }
    // The new scheme is written a moment after the command starts.
    Timer { id: settle; interval: 1500; onTriggered: schemes.refresh() }
    property bool busy: false

    function counterpart(current: string, names: var, wantDark: bool): string {
        const tries = wantDark
            ? [current.replace(/Light$/, "Dark"), current.replace(/Light$/, "") + "Dark", current + "Dark"]
            : [current.replace(/Dark$/, "Light"), current.replace(/Dark$/, ""), current.replace(/Black$/, "Light")];
        return tries.find(n => n !== current && names.indexOf(n) >= 0) ?? "";
    }
    function toggle(): void {
        if (busy || !core) return;
        const wantDark = !dark;
        const apply = (current, names) => {
            if (current.length > 0) remember(!wantDark, current);
            let target = wantDark ? darkScheme : lightScheme;
            if (target.length === 0 || (names.length > 0 && names.indexOf(target) < 0) || target === current)
                target = counterpart(current, names, wantDark) || (wantDark ? "BreezeDark" : "BreezeLight");
            core.startDetached("plasma-apply-colorscheme", [target]);
            settle.restart();
        };
        if (!core.local) { apply("", []); return; }
        busy = true;
        core.local.run("plasma-apply-colorscheme", ["--list-schemes"], (code, out) => {
            busy = false;
            const names = [];
            let current = "";
            for (const line of String(out).split("\n")) {
                const m = /^\s*\*\s+(\S+)(\s+\(current color scheme\))?/.exec(line);
                if (!m) continue;
                names.push(m[1]);
                if (m[2]) current = m[1];
            }
            apply(current, names);
        });
    }
}
