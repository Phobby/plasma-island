/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Theme: colors, metrics and motion for the island, all in one place. Either
    the system's colours (Plasma) or a custom style (Styles.qml); everything
    below is a binding, so a change of either shows at once. Sizes derive from
    Kirigami.Units.gridUnit so they follow the font DPI / scale factor.
*/
import QtQuick
import org.kde.kirigami as Kirigami

QtObject {
    id: theme

    // true = the system's colours (Plasma), false = `style` (see Styles.qml)
    property bool follow: true
    property var style: Styles.defaults("oxygen")
    // Distance from the top of the screen while following the system (Settings → General).
    property int systemTop: 6
    // KWin really blurs what is behind the island (native helper + Blur effect).
    property bool blurActive: false

    // ---- the system's colours -------------------------------------------------
    // Two things can be "the system" inside plasmashell:
    //   the colour scheme  what System Settings → Colours applies, with the accent
    //                      colour (systemScheme, read by ColorSchemeBackend when KDE
    //                      announces a change);
    //   the Plasma style   what the panel and other widgets use: Kirigami.Theme,
    //                      here libplasma's PlasmaTheme over Plasma::Theme, which
    //                      follows Plasma::Theme::themeChanged by itself. It is the
    //                      colour scheme too unless the style brings its own colours.
    // Both are bindings: a change shows at once and nothing is polled.
    // 0 = the colour scheme (the Plasma style where it cannot be read), 1 = the Plasma style
    property int systemSource: 0
    // { background, text, accent } of the applied colour scheme; null = not known
    property var systemScheme: null
    Kirigami.Theme.colorSet: Kirigami.Theme.Window
    Kirigami.Theme.inherit: false
    readonly property var scheme: systemSource === 0 ? systemScheme : null
    readonly property color systemBackground: scheme ? scheme.background : Kirigami.Theme.backgroundColor
    readonly property color systemText: scheme ? scheme.text : Kirigami.Theme.textColor
    readonly property color systemAccent: scheme ? scheme.accent : Kirigami.Theme.highlightColor
    readonly property real systemFrameContrast: Kirigami.Theme.frameContrast > 0 ? Kirigami.Theme.frameContrast : 0.2

    // ---- the look ---------------------------------------------------------------
    readonly property string material: follow ? "flat" : style.material
    // High contrast: nothing translucent that text has to be read on or with.
    readonly property bool strong: !follow && style.strong === true
    readonly property color base: follow ? systemBackground : gradientFill ? gradientAverage : style.background === "accent" ? systemAccent : style.background
    readonly property bool dark: luminance(base) < 0.179     // white reads better on it than black
    readonly property bool blurWanted: follow ? true : style.blur
    readonly property int blurLevel: follow ? 1 : style.blurLevel
    readonly property real scale: follow ? 1 : style.scale / 100
    readonly property real roundness: follow ? 1 : style.radius / 100
    readonly property int topOffset: follow ? systemTop : style.top
    readonly property int offsetX: follow ? 0 : style.offsetX
    readonly property int borderWidth: follow ? 1 : style.border ? style.borderWidth : 0
    readonly property int shadowLevel: follow ? 1 : style.shadow
    // A corner radius under the roundness setting (100% = as designed, a full capsule).
    function rounded(radius: real): real { return radius * roundness; }

    // ---- gradient fill ------------------------------------------------------------
    // A custom style can fill the island with a gradient (2 or 3 colours; linear
    // at any angle, or radial) instead of one colour: IslandShape draws it. What
    // is derived from the background (dark or light, the automatic text colour,
    // readable(), the frame) takes the gradient's average then, so text is
    // chosen against the mean brightness of what it sits on.
    readonly property bool gradientFill: !follow && style.fill === "gradient"
    readonly property string gradientKind: gradientFill ? style.gradientType : ""
    readonly property real gradientAngle: gradientFill ? style.gradientAngle : 0
    function fromHex(text: string): color {
        const n = parseInt(String(text).slice(1), 16);
        return Qt.rgba(((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255, 1);
    }
    readonly property var gradientColors: gradientFill ? style.gradientStops.map(fromHex) : []
    // The gradient at t (0..1) along its line.
    function gradientAt(t: real): color {
        const c = gradientColors, at = Math.max(0, Math.min(1, t)) * (c.length - 1);
        const i = Math.min(c.length - 2, Math.floor(at));
        return mix(c[i], c[i + 1], at - i);
    }
    // Its mean, taken in linear light: the colour whose luminance is the mean luminance.
    readonly property color gradientAverage: {
        if (gradientColors.length < 2) return "black";
        const linear = v => v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        const display = v => v <= 0.0031308 ? v * 12.92 : 1.055 * Math.pow(v, 1 / 2.4) - 0.055;
        const samples = 24;
        let r = 0, g = 0, b = 0;
        for (let i = 0; i < samples; ++i) {
            const c = gradientAt((i + 0.5) / samples);
            r += linear(c.r); g += linear(c.g); b += linear(c.b);
        }
        return Qt.rgba(display(r / samples), display(g / samples), display(b / samples), 1);
    }
    // What the shape draws: the colours at 0, ½ and 1, as translucent as the surface.
    readonly property var gradientBody: gradientFill ? [0, 0.5, 1].map(t => { const c = gradientAt(t); return Qt.rgba(c.r, c.g, c.b, alpha); }) : []
    // The text's contrast against the gradient's own colours, the worst of them
    // (21 without a gradient). Under 3:1 a part of the island is too light or
    // too dark for the one text colour: the settings warn.
    readonly property real gradientContrast: {
        let worst = 21;
        for (const c of gradientColors) worst = Math.min(worst, contrast(text, c));
        return worst;
    }
    readonly property bool gradientUneven: gradientFill && gradientContrast < 3

    // ---- metrics --------------------------------------------------------------
    readonly property real gu: Kirigami.Units.gridUnit          // ~18px @ 1x
    readonly property real pillWidth: Math.round(gu * 10)       // ~180
    readonly property real pillHeight: Math.round(gu * 2)       // ~36
    readonly property real liveWidth: Math.round(gu * 13)
    readonly property real notificationWidth: Math.round(gu * 22)
    readonly property real notificationHeight: Math.round(gu * 4)
    readonly property real expandedWidth: Math.round(gu * 24)
    readonly property real expandedHeight: Math.round(gu * 11.5)
    // A page that needs the room (the Habits year) widens the expanded island to this.
    readonly property real wideWidth: Math.round(gu * 36)
    // And one that needs it downwards (the AI tab's conversation) makes it this tall.
    readonly property real tallHeight: Math.round(gu * 20)
    readonly property real expandedRadius: rounded(28)
    readonly property real notificationRadius: rounded(26)
    // Transient system events (charging, Bluetooth, volume…): a wide pill.
    readonly property real eventWidth: Math.round(gu * 19)
    readonly property real eventHeight: Math.round(gu * 2.9)
    // An event that asks something: a sentence and its buttons under it.
    readonly property real questionHeight: Math.round(gu * 4.7)
    // Split island: main pill + detached "minimal" bubble on the right.
    readonly property real splitMainWidth: Math.round(gu * 11.5)
    readonly property real splitGap: 7
    readonly property real bubbleSize: pillHeight
    // Privacy dots right of the island.
    readonly property real privacyDotSize: 7
    readonly property real privacyAreaWidth: 30
    // Half-width the small window must cover around the centered main pill.
    readonly property real smallHalfWidth: Math.max(liveWidth / 2, splitMainWidth / 2 + splitGap + bubbleSize) + privacyAreaWidth
    readonly property real spacing: Kirigami.Units.smallSpacing * 2
    readonly property real padding: Math.round(gu * 0.9)

    // Transparent margin around the island inside its window (room for the
    // drop shadow and for OutBack overshoot).
    readonly property real shadowSize: shadowLevel === 0 ? 0 : shadowLevel === 1 ? 12 : 18
    readonly property real windowSidePad: 26
    readonly property real windowTopPad: 6
    readonly property real windowBottomPad: 28

    // ---- motion ---------------------------------------------------------------
    readonly property int morphDuration: 380
    readonly property int collapseDuration: 300
    readonly property int fadeDuration: 180
    readonly property real overshoot: 0.9

    // ---- colors -------------------------------------------------------------
    // Following the system keeps the surface readable without blur; a custom
    // style takes the opacity as it is set.
    readonly property real alpha: follow ? (blurActive ? 0.82 : 0.92) : style.opacity / 100
    function shade(c: color, factor: real, a: real): color {
        return Qt.rgba(Math.min(1, c.r * factor), Math.min(1, c.g * factor), Math.min(1, c.b * factor), a);
    }
    function mix(a: color, b: color, t: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }
    readonly property bool metal: material === "metal"

    // Metal: Oxygen-like brushed metal, a vertical gradient around the base colour
    // (graphite top → near-black bottom, or brushed aluminium). Flat and glass: one colour.
    readonly property color bodyTop: shade(base, !metal ? 1 : dark ? 2 : 1.107, alpha)
    readonly property color bodyMid: shade(base, 1, alpha)
    readonly property color bodyBottom: shade(base, !metal ? 1 : dark ? 0.45 : 0.905, alpha)

    // The border. Its own colour: metal a silver rim, brighter at the top; glass
    // a hairline of light; flat the system's frame colour (text into background).
    readonly property color borderGiven: !follow && style.borderColor.length > 0 ? style.borderColor : "transparent"
    readonly property bool borderOwn: !follow && style.borderColor.length > 0
    readonly property color rimTop: borderOwn ? borderGiven
        : metal ? (dark ? Qt.rgba(0.80, 0.82, 0.86, 0.55) : Qt.rgba(1, 1, 1, 0.95))
        : material === "glass" ? (dark ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(0, 0, 0, 0.22))
        : mix(base, text, systemFrameContrast)
    readonly property color rimBottom: borderOwn ? borderGiven
        : metal ? (dark ? Qt.rgba(0.35, 0.36, 0.39, 0.35) : Qt.rgba(0.55, 0.56, 0.60, 0.55))
        : material === "glass" ? (dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.12))
        : rimTop

    readonly property color highlight: metal ? (dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.55))
        : material === "glass" ? (dark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.30)) : "transparent"
    readonly property color innerShadow: !metal ? "transparent" : dark ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(0, 0, 0, 0.10)
    readonly property color dropShadow: shadowLevel === 0 ? "transparent"
        : shadowLevel === 1 ? (dark ? Qt.rgba(0, 0, 0, 0.26) : Qt.rgba(0, 0, 0, 0.14))
        : dark ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(0, 0, 0, 0.22)
    // Frosting over the blurred background. The blur itself is KWin's and has one
    // strength for the whole desktop; a level adds a milky veil that hides more of
    // what is behind.
    readonly property color frost: !blurActive || blurLevel === 0 ? "transparent"
        : Qt.rgba(1, 1, 1, (dark ? [0, 0.05, 0.11] : [0, 0.18, 0.34])[blurLevel])

    readonly property color text: follow ? systemText : style.text.length > 0 ? style.text : dark ? "#f4f5f7" : "#16171a"
    readonly property color subText: strong ? mix(text, base, 0.12) : Qt.rgba(text.r, text.g, text.b, dark ? 0.62 : 0.74)
    readonly property color faint: dark ? Qt.rgba(1, 1, 1, strong ? 0.20 : 0.12) : Qt.rgba(0, 0, 0, strong ? 0.16 : 0.10)
    readonly property color track: dark ? Qt.rgba(1, 1, 1, strong ? 0.42 : 0.16) : Qt.rgba(0, 0, 0, strong ? 0.45 : 0.14)
    // Buttons, fields, selections. The accent is the system's unless the style names a colour.
    // Kept visible on the surface (3:1, as WCAG asks of controls): a dull accent is lightened or darkened.
    readonly property color controlGiven: follow || style.control === "accent" ? systemAccent : style.control
    readonly property color control: ensure(controlGiven, surface, 3)
    // Sliders: the text colour in Oxygen Metallic as it comes (its iOS-like white), else the control colour.
    readonly property color sliderFill: !follow && style.preset === "oxygen" && style.control === Styles.presets.oxygen.control ? text : control
    readonly property color accent: follow || style.control === "accent" || style.preset === "oxygen" && style.control === Styles.presets.oxygen.control
        ? systemAccent : controlGiven
    readonly property color live: "#32d74b"      // iOS green: charging, camera, success
    readonly property color orange: "#ff9f0a"    // microphone, timers
    readonly property color red: "#ff3b30"       // recording, low battery, errors
    readonly property color purple: "#bf5af2"    // do not disturb
    readonly property color blue: "#0a84ff"      // Bluetooth, info
    readonly property color network: "#0a84ff"   // iOS blue
    readonly property color warning: "#ff9f0a"
    readonly property color danger: "#ff453a"

    // ---- contrast (WCAG 2.x) ----------------------------------------------------
    // Opaque approximation of the body behind content.
    readonly property color surface: Qt.rgba(base.r, base.g, base.b, 1)
    // State fills for buttons/chips, visible on dark and light surfaces.
    readonly property color hoverFill: dark ? Qt.rgba(1, 1, 1, strong ? 0.16 : 0.08) : Qt.rgba(0, 0, 0, strong ? 0.12 : 0.06)
    readonly property color pressedFill: dark ? Qt.rgba(1, 1, 1, strong ? 0.30 : 0.20) : Qt.rgba(0, 0, 0, strong ? 0.26 : 0.16)
    readonly property real minContrast: 4.5

    function luminance(c: color): real {
        const f = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
    }
    // Composites a (possibly translucent) colour over an opaque background.
    function over(fg: color, bg: color): color {
        const a = fg.a;
        return Qt.rgba(fg.r * a + bg.r * (1 - a), fg.g * a + bg.g * (1 - a), fg.b * a + bg.b * (1 - a), 1);
    }
    function contrast(fg: color, bg: color): real {
        const b = over(bg, surface);
        const l1 = luminance(over(fg, b)) + 0.05, l2 = luminance(b) + 0.05;
        return l1 > l2 ? l1 / l2 : l2 / l1;
    }
    // White or near-black, whichever reads better on `bg` (e.g. icon on a tinted toggle).
    function onColor(bg: color): color {
        const w = Qt.rgba(1, 1, 1, 1), k = Qt.rgba(0.07, 0.07, 0.08, 1);
        return contrast(w, bg) >= contrast(k, bg) ? w : k;
    }
    // `c` adjusted (lighter on dark, darker on light) until it reaches 4.5:1 on `bg`.
    function readable(c: color, bg: color): color { return ensure(c, bg, minContrast); }
    function ensure(c: color, bg: color, ratio: real): color {
        const back = bg === undefined ? surface : bg;
        let out = Qt.rgba(c.r, c.g, c.b, 1);
        // Black cannot be lightened by a factor.
        if (luminance(out) < 0.004 && luminance(over(back, surface)) < 0.2) out = Qt.rgba(0.2, 0.2, 0.2, 1);
        for (let i = 0; i < 24 && contrast(out, back) < ratio; ++i) {
            out = luminance(over(back, surface)) < 0.2 ? Qt.lighter(out, 1.12) : Qt.darker(out, 1.12);
            if (luminance(out) > 0.98 || luminance(out) < 0.005) break;
        }
        return out;
    }

    // ---- typography ---------------------------------------------------------
    readonly property real fontNormal: Kirigami.Theme.defaultFont.pointSize > 0 ? Kirigami.Theme.defaultFont.pointSize : 10
    readonly property real fontSmall: Kirigami.Theme.smallFont.pointSize > 0 ? Math.min(Kirigami.Theme.smallFont.pointSize, fontNormal) : fontNormal * 0.86
    readonly property real fontTitle: fontNormal * 1.08
}
