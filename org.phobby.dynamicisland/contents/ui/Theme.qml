/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Theme: colors, metrics and motion for the island. Sizes derive from
    Kirigami.Units.gridUnit so they follow the font DPI / scale factor.
*/
import QtQuick
import org.kde.kirigami as Kirigami

QtObject {
    id: theme

    // 0 = follow color scheme, 1 = dark, 2 = light
    property int mode: 1
    property real surfaceOpacity: 0.82
    // With real KWin blur behind we can afford more transparency.
    property bool blurActive: false

    readonly property bool dark: mode === 1 || (mode === 0 && Kirigami.Theme.backgroundColor.hslLightness < 0.5)

    // ---- metrics --------------------------------------------------------------
    readonly property real gu: Kirigami.Units.gridUnit          // ~18px @ 1x
    readonly property real pillWidth: Math.round(gu * 10)       // ~180
    readonly property real pillHeight: Math.round(gu * 2)       // ~36
    readonly property real liveWidth: Math.round(gu * 13)
    readonly property real notificationWidth: Math.round(gu * 22)
    readonly property real notificationHeight: Math.round(gu * 4)
    readonly property real expandedWidth: Math.round(gu * 24)
    readonly property real expandedHeight: Math.round(gu * 11.5)
    readonly property real expandedRadius: 28
    readonly property real notificationRadius: 26
    readonly property real spacing: Kirigami.Units.smallSpacing * 2
    readonly property real padding: Math.round(gu * 0.9)

    // Transparent margin around the island inside its window (room for the
    // drop shadow and for OutBack overshoot).
    readonly property real shadowSize: 18
    readonly property real windowSidePad: 26
    readonly property real windowTopPad: 6
    readonly property real windowBottomPad: 28

    // ---- motion ---------------------------------------------------------------
    readonly property int morphDuration: 380
    readonly property int collapseDuration: 300
    readonly property int fadeDuration: 180
    readonly property real overshoot: 0.9

    // ---- colors -------------------------------------------------------------
    readonly property real alpha: blurActive ? surfaceOpacity : Math.max(surfaceOpacity, 0.9)

    // Oxygen-like brushed metal: graphite top → near-black bottom (dark),
    // or brushed aluminium (light).
    readonly property color bodyTop: dark ? Qt.rgba(0.20, 0.21, 0.23, alpha) : Qt.rgba(0.93, 0.94, 0.95, alpha)
    readonly property color bodyMid: dark ? Qt.rgba(0.10, 0.105, 0.115, alpha) : Qt.rgba(0.84, 0.85, 0.87, alpha)
    readonly property color bodyBottom: dark ? Qt.rgba(0.045, 0.047, 0.052, alpha) : Qt.rgba(0.76, 0.77, 0.79, alpha)

    // 1px silver rim gradient
    readonly property color rimTop: dark ? Qt.rgba(0.80, 0.82, 0.86, 0.55) : Qt.rgba(1, 1, 1, 0.95)
    readonly property color rimBottom: dark ? Qt.rgba(0.35, 0.36, 0.39, 0.35) : Qt.rgba(0.55, 0.56, 0.60, 0.55)

    readonly property color highlight: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.55)
    readonly property color innerShadow: dark ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(0, 0, 0, 0.10)
    readonly property color dropShadow: dark ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(0, 0, 0, 0.22)

    readonly property color text: dark ? "#f4f5f7" : "#16171a"
    readonly property color subText: dark ? Qt.rgba(0.92, 0.93, 0.96, 0.62) : Qt.rgba(0.08, 0.09, 0.10, 0.62)
    readonly property color faint: dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.10)
    readonly property color track: dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.14)
    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color live: "#32d74b"      // iOS green
    readonly property color network: "#0a84ff"   // iOS blue
    readonly property color warning: "#ff9f0a"
    readonly property color danger: "#ff453a"

    // ---- typography ---------------------------------------------------------
    readonly property real fontNormal: Kirigami.Theme.defaultFont.pointSize > 0 ? Kirigami.Theme.defaultFont.pointSize : 10
    readonly property real fontSmall: Kirigami.Theme.smallFont.pointSize > 0 ? Math.min(Kirigami.Theme.smallFont.pointSize, fontNormal) : fontNormal * 0.86
    readonly property real fontTitle: fontNormal * 1.08
}
