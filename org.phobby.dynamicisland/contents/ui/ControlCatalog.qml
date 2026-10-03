/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Every button the Controls page can show, like a phone's quick settings:
    at most `maximum` of them are on the page (the `controlTiles` setting,
    comma-separated keys, in order); the rest are offered to add, in the
    island (hold a button) and in Settings → Controls. What each one does
    is in QuickSettingsPage.qml. Icons are drawn as a single-colour mask:
    they must be monochrome ones (-symbolic, status, actions), not colourful
    app icons, which would show as an empty shape.
*/
import QtQuick

QtObject {
    readonly property int maximum: 6
    readonly property var defaultTiles: ["dnd", "nightlight", "power", "bluetooth", "wifi", "updates"]

    readonly property var tiles: [
        { key: "dnd", icon: "weather-clear-night-symbolic", title: Lang.i18nc("@action:button short for Do Not Disturb", "Focus"),
          hint: Lang.i18n("Do Not Disturb") },
        { key: "nightlight", icon: "redshift-status-on", title: Lang.i18n("Night Light"), hint: Lang.i18n("Warmer colours at night") },
        { key: "power", icon: "speedometer", title: Lang.i18n("Power profile"), hint: Lang.i18n("Power Save, Balanced, Performance in turn") },
        { key: "bluetooth", icon: "network-bluetooth", title: Lang.i18n("Bluetooth"), hint: "" },
        { key: "wifi", icon: "network-wireless", title: Lang.i18n("Wi-Fi"), hint: "" },
        { key: "updates", icon: "system-software-update", title: Lang.i18nc("@action:button short", "Updates"),
          hint: Lang.i18n("Number of updates; opens Discover") },
        { key: "airplane", icon: "network-flightmode-on", title: Lang.i18n("Airplane mode"), hint: Lang.i18n("Wi-Fi, mobile data and Bluetooth off") },
        { key: "vpn", icon: "network-vpn", title: Lang.i18n("VPN"), hint: Lang.i18n("Connects the VPN used last") },
        { key: "hotspot", icon: "network-wireless-hotspot", title: Lang.i18n("Hotspot"), hint: Lang.i18n("Share this computer's connection over Wi-Fi") },
        { key: "record", icon: "media-record", title: Lang.i18n("Record screen"), hint: Lang.i18n("Spectacle: record a region") },
        { key: "screenshot", icon: "camera-photo-symbolic", title: Lang.i18n("Screenshot"), hint: Lang.i18n("Spectacle: capture a region") },
        { key: "camera", icon: "camera-web", title: Lang.i18n("Camera"), hint: Lang.i18n("Opens a camera app; lit while the camera is in use") },
        { key: "mic", icon: "microphone-sensitivity-high", title: Lang.i18n("Microphone"), hint: Lang.i18n("Mute or unmute the microphone") },
        { key: "mute", icon: "audio-volume-high", title: Lang.i18n("Sound"), hint: Lang.i18n("Mute or unmute the speakers") },
        { key: "kdeconnect", icon: "kdeconnect-symbolic", title: Lang.i18n("KDE Connect"), hint: Lang.i18n("Opens KDE Connect; lit while a phone is connected") },
        { key: "findphone", icon: "smartphone", title: Lang.i18n("Find phone"), hint: Lang.i18n("Rings the phone connected with KDE Connect") },
        { key: "darkmode", icon: "contrast", title: Lang.i18n("Dark mode"), hint: Lang.i18n("Switches the colour scheme between dark and light") },
        { key: "awake", icon: "system-suspend-inhibited", title: Lang.i18n("Keep awake"), hint: Lang.i18n("No sleep or screen lock until turned off") },
        { key: "lock", icon: "system-lock-screen", title: Lang.i18n("Lock"), hint: Lang.i18n("Lock the screen") },
        { key: "calculator", icon: Qt.resolvedUrl("../icons/calculator-symbolic.svg"), title: Lang.i18n("Calculator"), hint: "" },
        { key: "settings", icon: "preferences-system-symbolic", title: Lang.i18n("System Settings"), hint: "" }
    ]
    readonly property var keys: tiles.map(t => t.key)
    function info(key: string): var { return tiles.find(t => t.key === key) ?? null; }

    // The saved list made valid: known keys, no repeats, at most `maximum`.
    function normalize(saved: string): var {
        const list = String(saved ?? "").split(",").map(s => s.trim());
        return list.filter((k, i) => keys.indexOf(k) >= 0 && list.indexOf(k) === i).slice(0, maximum);
    }
}
