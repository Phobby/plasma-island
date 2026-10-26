/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Settings → Appearance, Layout: Notch. What the notch layout has of its own
    (main.qml, NotchWindow.qml): its colour and border, the curves where it
    meets the edge, which screen, its size and width open over a window that
    fills the screen, its height and widest, and the cat beside it. Shown under the
    layout's choice while the notch is chosen.

    The preview is drawn here with what is set, before it is applied: the
    notch over a panel with a clock in the middle, as small as it is idle,
    or as the dot, at the island's size.

    The settings are the page's (cfg_*): each control shows its own and
    writes it back.
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: section

    // The settings page (configAppearance.qml): its cfg_* are read and written here.
    required property var page
    // The notch with the page's settings (a Theme with notch: true).
    required property var shown

    component Hint: QQC2.Label {
        textFormat: Text.PlainText
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 24
        wrapMode: Text.Wrap
        font: Kirigami.Theme.smallFont
        opacity: 0.8
    }
    // Controls that keep showing the setting after they were used (a plain binding would be gone with the first click).
    component Check: QQC2.CheckBox {
        id: check
        property bool on
        Binding { target: check; property: "checked"; value: check.on }
    }
    component Choice: QQC2.ComboBox {
        id: choice
        property int index
        Binding { target: choice; property: "currentIndex"; value: choice.index }
        // (a model whose texts change starts again at its first entry: the choice is put back)
        onModelChanged: Qt.callLater(() => { if (choice.currentIndex !== choice.index) choice.currentIndex = choice.index; })
    }
    component Spin: QQC2.SpinBox {
        id: spin
        property int shownValue
        Binding { target: spin; property: "value"; value: spin.shownValue }
        valueFromText: (t) => parseInt(t)
    }

    Kirigami.Separator {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: Lang.i18n("Notch")
    }

    // ---- the preview -------------------------------------------------------------
    Choice {
        id: previewCombo
        Kirigami.FormData.label: Lang.i18n("Preview:")
        model: [Lang.i18n("Small"), Lang.i18n("Dot")]
        onActivated: index = currentIndex
    }
    Rectangle {
        id: preview
        objectName: "notchPreview"
        implicitWidth: Kirigami.Units.gridUnit * 24
        implicitHeight: section.shown.pillHeight * section.shown.scale + Kirigami.Units.gridUnit * 3
        color: "#2b3a4a"
        clip: true
        // a panel with a clock in the middle
        Rectangle {
            width: parent.width
            height: section.shown.notchPixels
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
            // (the width set, as the island has it; the preview is only so wide: past it, it is cut)
            readonly property real limit: section.page.cfg_notchMaxWidth > 0 ? Math.max(2 * section.shown.pillHeight, section.page.cfg_notchMaxWidth) : section.shown.pillWidth
            // (at its size, as the island is scaled as a whole)
            readonly property real k: section.shown.scale
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(k * (dot ? 2 * section.page.cfg_dotSize : limit))
            height: Math.round(k * (dot ? section.page.cfg_dotSize : section.shown.pillHeight))
            radius: k * (dot ? section.page.cfg_dotSize : section.shown.notchRadius)
            ear: k * section.shown.notchEar
            earDepth: k * section.shown.notchEarDepth
            edgeWidth: section.shown.notchEdgeWidth
            edgeColor: section.shown.notchEdgeColor
            fillColor: section.shown.notchBody.length === 3 ? "transparent" : section.shown.bodyMid
            gradientColors: section.shown.notchBody
            gradientKind: section.shown.notchBodyKind
            gradientAngle: section.shown.notchBodyAngle
            QQC2.Label {
                textFormat: Text.PlainText
                anchors.centerIn: parent
                visible: !outline.dot && section.page.cfg_showClock
                color: section.shown.text
                font.weight: Font.DemiBold
                scale: outline.k
                text: Qt.formatTime(new Date(2026, 0, 1, 9, 41), Lang.timeFormat)
            }
        }
    }

    // ---- the look ------------------------------------------------------------------
    Choice {
        id: colorCombo
        objectName: "notchColorCombo"
        Kirigami.FormData.label: Lang.i18n("Colour:")
        model: [Lang.i18n("Black"), Lang.i18n("The island's colours (Appearance)"), Lang.i18n("The island's look (Appearance)")]
        index: section.page.cfg_notchColor
        onActivated: section.page.cfg_notchColor = currentIndex
    }
    Hint {
        text: colorCombo.currentIndex === 0 ? Lang.i18n("Opaque black, like a real notch. Text and icons are light.")
            : colorCombo.currentIndex === 1 ? Lang.i18n("The colours of Appearance, a gradient too, but opaque: no blur, no shadow. Text and icons keep a readable contrast.")
            : Lang.i18n("The look of Appearance: its material (metal too, with its glassy gloss), how see-through it is and its blur. No shadow.")
    }
    Check {
        id: borderCheck
        objectName: "notchBorderCheck"
        Kirigami.FormData.label: Lang.i18n("Notch border:")
        text: Lang.i18n("Show an edge around the notch")
        on: section.page.cfg_notchBorderEnabled
        onToggled: section.page.cfg_notchBorderEnabled = checked
    }
    Spin {
        objectName: "notchBorderWidthSpin"
        Kirigami.FormData.label: Lang.i18n("Border thickness:")
        enabled: borderCheck.checked
        from: 1
        to: 8
        shownValue: section.page.cfg_notchBorderWidth
        textFromValue: (v) => Lang.i18n("%1 px", v)
        onValueModified: section.page.cfg_notchBorderWidth = value
    }
    ColorPickerButton {
        id: borderColorButton
        Kirigami.FormData.label: Lang.i18n("Border colour:")
        enabled: borderCheck.checked
        showAlphaChannel: false
        Binding { target: borderColorButton; property: "color"; value: section.page.cfg_notchBorderColor || "#4c566a" }
        onAccepted: c => section.page.cfg_notchBorderColor = "#" + [c.r, c.g, c.b].map(v => Math.round(v * 255).toString(16).padStart(2, "0")).join("")
    }
    Spin {
        Kirigami.FormData.label: Lang.i18n("Border opacity:")
        enabled: borderCheck.checked
        from: 0
        to: 100
        shownValue: section.page.cfg_notchBorderOpacity
        textFromValue: (v) => Lang.i18n("%1%", v)
        onValueModified: section.page.cfg_notchBorderOpacity = value
    }
    Hint {
        text: Lang.i18n("The border follows the sides and lower corners, leaving the top joined to the screen. It applies to every notch colour mode.")
    }
    Check {
        Kirigami.FormData.label: Lang.i18n("Upper corners:")
        text: Lang.i18n("Soften where it meets the edge (small curves outwards)")
        on: section.page.cfg_notchEars
        onToggled: section.page.cfg_notchEars = checked
    }

    // ---- where -----------------------------------------------------------------------
    Choice {
        Kirigami.FormData.label: Lang.i18n("Screen:")
        model: [Lang.i18n("The screen of the top panel"), Lang.i18n("The primary screen")]
        index: section.page.cfg_notchScreen
        onActivated: section.page.cfg_notchScreen = currentIndex
    }
    Hint {
        text: Lang.i18n("Without a panel at the top it sits at the top edge all the same: a panel at the bottom or at a side has nothing to do with it. One notch at a time: not on every screen.")
    }
    // (what it does over a window that fills the screen is the full-screen mode, for both layouts: below;
    // peeking or shrunk, the notch has these of its own)
    QQC2.CheckBox {
        id: dodgeWindows
        objectName: "notchDodgeWindows"
        Kirigami.FormData.label: Lang.i18n("Full screen:")
        visible: section.page.cfg_fullscreenMode >= 2
        text: Lang.i18n("Also for a window that reaches under it (moved up to the edge)")
        Binding { target: dodgeWindows; property: "checked"; value: section.page.cfg_notchDodgeWindows }
        onToggled: section.page.cfg_notchDodgeWindows = checked
    }
    RowLayout {
        objectName: "notchDodgeSize"
        Kirigami.FormData.label: Lang.i18n("Size there:")
        visible: section.page.cfg_fullscreenMode >= 2
        QQC2.Slider {
            id: dodgeSizeSlider
            Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            // (the left end, under the size range: as usual)
            from: Styles.scaleMin - 5
            to: Styles.scaleMax
            stepSize: 5
            onMoved: section.page.cfg_notchDodgeSize = value < Styles.scaleMin ? 0 : Math.round(value / 5) * 5
            Binding { target: dodgeSizeSlider; property: "value"; value: section.page.cfg_notchDodgeSize > 0 ? section.page.cfg_notchDodgeSize : dodgeSizeSlider.from; when: !dodgeSizeSlider.pressed }
        }
        QQC2.Label {
            textFormat: Text.PlainText
            font.features: { "tnum": 1 }
            text: section.page.cfg_notchDodgeSize > 0 ? Lang.percent(section.page.cfg_notchDodgeSize) : Lang.i18n("As usual")
        }
    }
    RowLayout {
        objectName: "notchDodgeWidth"
        Kirigami.FormData.label: Lang.i18n("Width there:")
        visible: section.page.cfg_fullscreenMode >= 2
        QQC2.Slider {
            id: dodgeWidthSlider
            Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            from: 0
            to: 1200
            stepSize: 10
            onMoved: section.page.cfg_notchDodgeWidth = value < 80 ? 0 : Math.round(value / 10) * 10
            Binding { target: dodgeWidthSlider; property: "value"; value: section.page.cfg_notchDodgeWidth; when: !dodgeWidthSlider.pressed }
        }
        QQC2.Label {
            textFormat: Text.PlainText
            font.features: { "tnum": 1 }
            text: section.page.cfg_notchDodgeWidth > 0 ? Lang.i18n("%1 px", section.page.cfg_notchDodgeWidth) : Lang.i18n("As usual")
        }
    }
    Hint {
        visible: section.page.cfg_fullscreenMode >= 2
        text: Lang.i18n("While it is open over a window that fills the screen (Full-screen mode: Peek at the edge or Shrink, below); as usual: the size and width set for it everywhere.")
    }

    // ---- its size -----------------------------------------------------------------
    RowLayout {
        Kirigami.FormData.label: Lang.i18n("Height:")
        Choice {
            id: heightCombo
            model: [Lang.i18n("The top panel's"), Lang.i18n("Set by hand")]
            index: section.page.cfg_notchHeightMode
            onActivated: section.page.cfg_notchHeightMode = currentIndex
        }
        Spin {
            visible: heightCombo.currentIndex === 1
            from: 24
            to: 72
            shownValue: section.page.cfg_notchHeight
            textFromValue: (v) => Lang.i18n("%1 px", v)
            onValueModified: section.page.cfg_notchHeight = value
        }
    }
    Hint {
        visible: heightCombo.currentIndex === 0
        text: section.page.cfg_notchPanelSeen > 0 ? Lang.i18n("The top panel there is %1 px high.", section.page.cfg_notchPanelSeen)
            : section.page.cfg_notchPanelSeen === 0 ? Lang.i18n("There is no panel at the top there: the notch is as high as the island.")
            : Lang.i18n("The panel is looked at once the notch layout is on; until then the island's own height.")
    }
    RowLayout {
        Kirigami.FormData.label: Lang.i18n("Width:")
        QQC2.Slider {
            id: widthSlider
            objectName: "notchWidthSlider"
            Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            from: 0
            to: 1200
            stepSize: 10
            // (at the left end: as wide as what it shows)
            onMoved: section.page.cfg_notchMaxWidth = value < 80 ? 0 : Math.round(value / 10) * 10
            Binding { target: widthSlider; property: "value"; value: section.page.cfg_notchMaxWidth; when: !widthSlider.pressed }
        }
        QQC2.Label {
            textFormat: Text.PlainText
            font.features: { "tnum": 1 }
            Layout.minimumWidth: widestWidth.advanceWidth
            TextMetrics { id: widestWidth; font.features: { "tnum": 1 }; text: Lang.i18n("%1 px", 1200) }
            text: section.page.cfg_notchMaxWidth > 0 ? Lang.i18n("%1 px", section.page.cfg_notchMaxWidth) : Lang.i18n("Automatic")
        }
    }
    Hint {
        text: Lang.i18n("Automatic: as wide as what it shows (the clock, a song, a timer). Set, it is that wide, narrower or wider, at 100 % size; the size setting scales it, and it never goes past the screen.")
    }
    Check {
        objectName: "notchOpenWidthCheck"
        enabled: section.page.cfg_notchMaxWidth > 0
        text: Lang.i18n("Open it as wide too, where that is wider than the open island")
        on: section.page.cfg_notchOpenWidth
        onToggled: section.page.cfg_notchOpenWidth = checked
    }
    Hint {
        text: Lang.i18n("When the pointer opens it, the island keeps the notch's width and its pages spread out sideways; its height stays. Off: it opens at its own width.")
    }
    Kirigami.InlineMessage {
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 24
        visible: true
        type: Kirigami.MessageType.Warning
        text: Lang.i18n("The notch covers what is under it on the panel, and that part of the panel cannot be clicked. If a clock or task buttons sit in the middle of your panel, narrow it here (where a panel's widgets are cannot be read). Notifications and the open island are wider for as long as they show.")
    }

    // ---- what else changes -----------------------------------------------------------
    Check {
        Kirigami.FormData.label: Lang.i18n("Cat:")
        enabled: section.page.cfg_catEnabled
        text: Lang.i18n("Hide the cat in the notch layout")
        on: section.page.cfg_notchHideCat
        onToggled: section.page.cfg_notchHideCat = checked
    }
    Hint {
        text: Lang.i18n("Beside the notch it stands on the panel, against the notch's side, and takes the clicks where it is.")
    }
    Hint {
        Kirigami.FormData.label: Lang.i18n("Not in the notch layout:")
        text: Lang.i18n("Distance from top (Fine tuning below, General) and Place below top panels: it sits at the edge itself. The look's border and shadow; use the notch border controls above. The horizontal position, the size, the roundness of its lower corners and dot mode still apply.")
    }
    Hint {
        visible: !Qt.platform.pluginName.startsWith("wayland")
        text: Lang.i18n("This is not a Wayland session: the notch goes to the top edge, but whether it stays over the panel is up to the window manager.")
    }
}
