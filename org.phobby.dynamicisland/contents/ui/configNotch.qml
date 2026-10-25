/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Notch: the island welded to the top edge of the screen, over a panel
    there (main.qml, NotchWindow.qml). Whether, its colour, what it does over
    a window that fills the screen, which screen, its height and widest, the
    curves where it meets the edge, and the cat.

    The preview is drawn here with what is set, before it is applied: the
    notch over a panel with a clock in the middle, as small as it is idle,
    or as the dot.
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQC
import org.kde.plasma.plasmoid

KCM.SimpleKCM {
    id: page

    property string cfg_language
    Binding { target: Lang; property: "setting"; value: page.cfg_language; restoreMode: Binding.RestoreNone }
    property int cfg_clockFormat
    Binding { target: Lang; property: "clockSetting"; value: page.cfg_clockFormat; restoreMode: Binding.RestoreNone }

    property alias cfg_notchMode: modeCheck.checked
    property alias cfg_notchColor: colorCombo.currentIndex
    property alias cfg_notchFullscreen: fullscreenCombo.currentIndex
    property alias cfg_notchScreen: screenCombo.currentIndex
    property int cfg_notchMaxWidth
    property alias cfg_notchHideCat: catCheck.checked
    property alias cfg_notchHeightMode: heightCombo.currentIndex
    property alias cfg_notchHeight: heightSpin.value
    property alias cfg_notchEars: earsCheck.checked
    property alias cfg_notchBorderEnabled: borderCheck.checked
    property alias cfg_notchBorderWidth: borderSpin.value
    property string cfg_notchBorderColor
    property alias cfg_notchBorderOpacity: borderOpacity.value
    property int cfg_notchPanelSeen
    // For the preview: the island's own look (Appearance) and the dot's size.
    property int cfg_appearanceMode
    property int cfg_followSource
    property string cfg_followStyle
    property string cfg_customStyle
    property int cfg_surfaceOpacity
    property bool cfg_blurEnabled
    property int cfg_topMargin
    property int cfg_themeMode
    property bool cfg_showClock
    property int cfg_dotSize
    property bool cfg_catEnabled

    function widget(): var { try { return Plasmoid.configuration; } catch (e) { return null; } }
    readonly property var systemScheme: { const c = widget(); return c ? Styles.schemeFromText(c.systemScheme) : null; }

    // The notch with this page's settings.
    Theme {
        id: shown
        follow: page.cfg_appearanceMode === 0
        systemSource: page.cfg_followSource
        systemScheme: page.systemScheme
        systemStyle: Styles.parseFollow(page.cfg_followStyle)
        style: Styles.parse(page.cfg_customStyle, { opacity: page.cfg_surfaceOpacity, blur: page.cfg_blurEnabled, top: page.cfg_topMargin, light: page.cfg_themeMode === 2 })
        notch: true
        notchBlack: colorCombo.currentIndex === 0
        notchLook: colorCombo.currentIndex === 2
        notchEars: earsCheck.checked
        notchBorderEnabled: borderCheck.checked
        notchBorderWidth: borderSpin.value
        notchBorderColor: page.cfg_notchBorderColor
        notchBorderOpacity: borderOpacity.value
        // the panel the island found there (36 px where it has not looked yet), or as set
        notchPixels: heightCombo.currentIndex === 1 ? heightSpin.value : page.cfg_notchPanelSeen > 0 ? page.cfg_notchPanelSeen : 36
    }

    component Hint: QQC2.Label {
        textFormat: Text.PlainText
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 24
        wrapMode: Text.Wrap
        font: Kirigami.Theme.smallFont
        opacity: 0.8
    }

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: modeCheck
            objectName: "notchModeCheck"
            Kirigami.FormData.label: Lang.i18n("Notch mode:")
            text: Lang.i18n("Weld the island to the top edge of the screen")
        }
        Hint {
            text: Lang.i18n("Like the notch of a laptop's screen: square where it meets the edge, rounded below, always over a top panel, also one that hides itself. It opens downwards as the island does. Changing this needs no restart.")
        }

        // ---- the preview -------------------------------------------------------------
        QQC2.ComboBox {
            id: previewCombo
            Kirigami.FormData.label: Lang.i18n("Preview:")
            model: [Lang.i18n("Small"), Lang.i18n("Dot")]
        }
        Rectangle {
            id: preview
            objectName: "notchPreview"
            implicitWidth: Kirigami.Units.gridUnit * 24
            implicitHeight: shown.pillHeight * shown.scale + Kirigami.Units.gridUnit * 3
            color: "#2b3a4a"
            clip: true
            opacity: modeCheck.checked ? 1 : 0.55
            // a panel with a clock in the middle
            Rectangle {
                width: parent.width
                height: shown.notchPixels
                color: Qt.rgba(0.85, 0.86, 0.88, 1)
                QQC2.Label {
                    textFormat: Text.PlainText
                    anchors.centerIn: parent
                    color: "#222"
                    text: Lang.i18n("Clock")
                }
                QQC2.Label {
                    textFormat: Text.PlainText
                    anchors.left: parent.left
                    anchors.leftMargin: Kirigami.Units.smallSpacing * 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#222"
                    text: Lang.i18n("Menu")
                }
            }
            NotchOutline {
                id: outline
                readonly property bool dot: previewCombo.currentIndex === 1
                readonly property real limit: page.cfg_notchMaxWidth > 0 ? Math.max(2 * shown.pillHeight, page.cfg_notchMaxWidth) : shown.pillWidth
                // (at its size, as the island is scaled as a whole)
                readonly property real k: shown.scale
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.round(k * (dot ? 2 * page.cfg_dotSize : Math.min(shown.pillWidth, limit)))
                height: Math.round(k * (dot ? page.cfg_dotSize : shown.pillHeight))
                radius: k * (dot ? page.cfg_dotSize : shown.notchRadius)
                ear: k * shown.notchEar
                earDepth: k * shown.notchEarDepth
                edgeWidth: shown.notchEdgeWidth
                edgeColor: shown.notchEdgeColor
                fillColor: shown.notchBody.length === 3 ? "transparent" : shown.bodyMid
                gradientColors: shown.notchBody
                gradientKind: shown.notchBodyKind
                gradientAngle: shown.notchBodyAngle
                QQC2.Label {
                    textFormat: Text.PlainText
                    anchors.centerIn: parent
                    visible: !outline.dot && page.cfg_showClock
                    color: shown.text
                    font.weight: Font.DemiBold
                    scale: outline.k
                    text: Qt.formatTime(new Date(2026, 0, 1, 9, 41), Lang.timeFormat)
                }
            }
        }

        // ---- the look ------------------------------------------------------------------
        QQC2.ComboBox {
            id: colorCombo
            Kirigami.FormData.label: Lang.i18n("Colour:")
            model: [Lang.i18n("Black"), Lang.i18n("The island's colours (Appearance)"), Lang.i18n("The island's look (Appearance)")]
        }
        Hint {
            text: colorCombo.currentIndex === 0 ? Lang.i18n("Opaque black, like a real notch. Text and icons are light.")
                : colorCombo.currentIndex === 1 ? Lang.i18n("The colours of Appearance, a gradient too, but opaque: no blur, no shadow. Text and icons keep a readable contrast.")
                : Lang.i18n("The look of Appearance: its material (metal too, with its glassy gloss), how see-through it is and its blur. No shadow.")
        }
        QQC2.CheckBox {
            id: borderCheck
            objectName: "notchBorderCheck"
            Kirigami.FormData.label: Lang.i18n("Notch border:")
            text: Lang.i18n("Show an edge around the notch")
        }
        QQC2.SpinBox {
            id: borderSpin
            objectName: "notchBorderWidthSpin"
            Kirigami.FormData.label: Lang.i18n("Border thickness:")
            enabled: borderCheck.checked
            from: 1
            to: 8
            textFromValue: (v) => Lang.i18n("%1 px", v)
            valueFromText: (t) => parseInt(t)
        }
        KQC.ColorButton {
            id: borderColorButton
            Kirigami.FormData.label: Lang.i18n("Border colour:")
            enabled: borderCheck.checked
            showAlphaChannel: false
            Binding { target: borderColorButton; property: "color"; value: page.cfg_notchBorderColor || "#4c566a" }
            onAccepted: c => page.cfg_notchBorderColor = "#" + [c.r, c.g, c.b].map(v => Math.round(v * 255).toString(16).padStart(2, "0")).join("")
        }
        QQC2.SpinBox {
            id: borderOpacity
            Kirigami.FormData.label: Lang.i18n("Border opacity:")
            enabled: borderCheck.checked
            from: 0
            to: 100
            textFromValue: (v) => Lang.i18n("%1%", v)
            valueFromText: (t) => parseInt(t)
        }
        Hint {
            text: Lang.i18n("The border follows the sides and lower corners, leaving the top joined to the screen. It applies to every notch colour mode.")
        }
        QQC2.CheckBox {
            id: earsCheck
            Kirigami.FormData.label: Lang.i18n("Upper corners:")
            text: Lang.i18n("Soften where it meets the edge (small curves outwards)")
        }

        // ---- where -----------------------------------------------------------------------
        QQC2.ComboBox {
            id: screenCombo
            Kirigami.FormData.label: Lang.i18n("Screen:")
            model: [Lang.i18n("The screen of the top panel"), Lang.i18n("The primary screen")]
        }
        Hint {
            text: Lang.i18n("Without a panel at the top it sits at the top edge all the same: a panel at the bottom or at a side has nothing to do with it. One notch at a time: not on every screen.")
        }
        QQC2.ComboBox {
            id: fullscreenCombo
            Kirigami.FormData.label: Lang.i18n("Over full screen:")
            model: [Lang.i18n("Hide"), Lang.i18n("Show")]
        }
        Hint {
            text: Lang.i18n("While a window fills that screen (a film, a game, a talk). It is never shown on the lock screen.")
        }

        // ---- its size -----------------------------------------------------------------
        RowLayout {
            Kirigami.FormData.label: Lang.i18n("Height:")
            QQC2.ComboBox {
                id: heightCombo
                model: [Lang.i18n("The top panel's"), Lang.i18n("Set by hand")]
            }
            QQC2.SpinBox {
                id: heightSpin
                visible: heightCombo.currentIndex === 1
                from: 24
                to: 72
                textFromValue: (v) => Lang.i18n("%1 px", v)
                valueFromText: (t) => parseInt(t)
            }
        }
        Hint {
            visible: heightCombo.currentIndex === 0
            text: page.cfg_notchPanelSeen > 0 ? Lang.i18n("The top panel there is %1 px high.", page.cfg_notchPanelSeen)
                : page.cfg_notchPanelSeen === 0 ? Lang.i18n("There is no panel at the top there: the notch is as high as the island.")
                : Lang.i18n("The panel is looked at once notch mode is on; until then the island's own height.")
        }
        RowLayout {
            Kirigami.FormData.label: Lang.i18n("Widest:")
            QQC2.Slider {
                id: widthSlider
                objectName: "notchWidthSlider"
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                from: 0
                to: 600
                stepSize: 10
                onMoved: page.cfg_notchMaxWidth = value < 80 ? 0 : Math.round(value)
                Binding { target: widthSlider; property: "value"; value: page.cfg_notchMaxWidth; when: !widthSlider.pressed }
            }
            QQC2.Label {
                textFormat: Text.PlainText
                font.features: { "tnum": 1 }
                text: page.cfg_notchMaxWidth > 0 ? Lang.i18n("%1 px", page.cfg_notchMaxWidth) : Lang.i18n("No limit")
            }
        }
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            visible: true
            type: Kirigami.MessageType.Warning
            text: Lang.i18n("The notch covers what is under it on the panel, and that part of the panel cannot be clicked. If a clock or task buttons sit in the middle of your panel, narrow it here (where a panel's widgets are cannot be read). Notifications and the open island are wider for as long as they show.")
        }

        // ---- what else changes -----------------------------------------------------------
        QQC2.CheckBox {
            id: catCheck
            Kirigami.FormData.label: Lang.i18n("Cat:")
            enabled: page.cfg_catEnabled
            text: Lang.i18n("Hide the cat in notch mode")
        }
        Hint {
            text: Lang.i18n("Beside the notch it stands on the panel, against the notch's side, and takes the clicks where it is.")
        }
        Hint {
            Kirigami.FormData.label: Lang.i18n("Not in notch mode:")
            text: Lang.i18n("Distance from top (Appearance, General) and Place below top panels: it sits at the edge itself. The look's border and shadow; use the notch border controls above. The horizontal position, the size, the roundness of its lower corners and dot mode still apply.")
        }
        Hint {
            visible: !Qt.platform.pluginName.startsWith("wayland")
            text: Lang.i18n("This is not a Wayland session: the notch goes to the top edge, but whether it stays over the panel is up to the window manager.")
        }
    }
}
