/*
    SPDX-License-Identifier: GPL-2.0-or-later
    "Dark mode" in Controls: switches the system colour scheme between a dark
    and a light one with plasma-apply-colorscheme. The scheme it switches away
    from is remembered (darkScheme / lightScheme, kept in the settings), so a
    custom scheme comes back on the next switch. Without one remembered it
    takes the counterpart by name (KlassyDark ↔ KlassyLight, BreezeDark ↔
    BreezeLight…), else Breeze.

    Also the colours of the applied scheme for "Follow the system" (Theme.qml):
    window background and text, and the selection colour, which is the accent
    colour. They are what System Settings wrote to kdeglobals, read again when
    KDE announces a change of the palette (NativeBridge.colorSchemeChanged):
    nothing is polled. Inside plasmashell neither Kirigami.Theme (the Plasma
    style's colours) nor the Qt palette (the widget style's) is the scheme.
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
    // { background, text, accent } of the applied scheme; null = not known
    // (no native module, or kdeglobals carries no colours).
    property var colors: null
    function refresh(): void {
        if (!core || !core.local) return;
        const text = core.local.readTextFile("~/.config/kdeglobals", 262144);
        const entry = (group, key) => {
            const section = new RegExp("^\\[" + group + "\\]\\s*$([\\s\\S]*?)(?=^\\[|(?![\\s\\S]))", "m").exec(text);
            const rgb = section ? new RegExp("^" + key + "=(\\d+),(\\d+),(\\d+)", "m").exec(section[1]) : null;
            return rgb ? Qt.rgba(rgb[1] / 255, rgb[2] / 255, rgb[3] / 255, 1) : null;
        };
        const background = entry("Colors:Window", "BackgroundNormal"), foreground = entry("Colors:Window", "ForegroundNormal");
        // The selection colour is the accent colour as applications show it: System
        // Settings and plasma-apply-colorscheme both write it there ([General]
        // AccentColor is only what the settings page last chose).
        const accent = entry("Colors:Selection", "BackgroundNormal") ?? entry("General", "AccentColor");
        windowLightness = background ? background.hslLightness : -1;
        const next = background && foreground && accent ? { background: background, text: foreground, accent: accent } : null;
        const key = c => c ? String(c.background) + String(c.text) + String(c.accent) : "";
        if (key(next) !== key(colors)) colors = next;
    }
    onCoreChanged: refresh()
    Component.onCompleted: refresh()
    Connections {
        target: schemes.core
        ignoreUnknownSignals: true
        function onLocalChanged() { schemes.refresh(); }
        // The file is written around the announcement: read now and once it has settled.
        function onColorSchemeChanged() { schemes.refresh(); settle.restart(); }
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
