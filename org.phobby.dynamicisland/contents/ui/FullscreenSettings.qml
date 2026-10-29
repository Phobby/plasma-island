/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Settings → Appearance, Layout: the full-screen mode, for both layouts
    (main.qml, FullscreenPeek.qml): what the island does while a window fills
    its screen: stays, hides, slides up or shrinks, said as what it does,
    with how it comes back under it; whether maximised windows count and
    whether it does so on the desktop too once nothing goes on; for peeking, how
    much shows (0 px: nothing) and the light at the edge, with its colour; in its
    Details the preview, the light's strength, how high and wide the place at the
    edge is that opens it, how soon it opens and whether a call opens it.

    The preview plays it with what is set, before it is applied: a screen,
    the island at its top, and "Try it" puts a window over the whole of it;
    the pointer at its top edge then does what it would do on the screen.

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
    // The island with the page's settings (a Theme), for the preview's colours and size.
    required property var shown

    component Hint: QQC2.Label {
        textFormat: Text.PlainText
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 24
        wrapMode: Text.Wrap
        font: Kirigami.Theme.smallFont
        opacity: 0.8
    }
    component ValueSlider: RowLayout {
        id: row
        property alias from: slider.from
        property alias to: slider.to
        property alias stepSize: slider.stepSize
        property real value
        property string valueText
        signal moved(real value)
        QQC2.Slider {
            id: slider
            Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            onMoved: row.moved(value)
            Binding { target: slider; property: "value"; value: row.value; when: !slider.pressed }
        }
        QQC2.Label {
            textFormat: Text.PlainText
            font.features: { "tnum": 1 }
            text: row.valueText
        }
    }

    // The four, in the order shown; `value` is what is kept (fullscreenMode); `text` says what the
    // island does, `hint` how it comes back.
    readonly property var modes: [
        { value: 1, text: Lang.i18n("Stays as it is"), hint: Lang.i18n("Nothing changes.") },
        { value: 0, text: Lang.i18n("Hides"), hint: Lang.i18n("It comes back when the window leaves full screen.") },
        { value: 2, text: Lang.i18n("Slides up, a thin strip shows"), hint: Lang.i18n("Move the pointer to the top edge and it opens.") },
        { value: 3, text: Lang.i18n("Shrinks to a small nub"), hint: Lang.i18n("Move the pointer onto the nub and it opens.") }
    ]
    readonly property int mode: section.page.cfg_fullscreenMode
    readonly property int modeIndex: Math.max(0, modes.findIndex(m => m.value === section.mode))
    readonly property bool peeking: section.mode === 2
    readonly property bool opensAtEdge: section.mode === 2 || section.mode === 3

    Kirigami.Separator {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: Lang.i18n("Full screen")
    }
    ColumnLayout {
        id: modeChoice
        objectName: "setting-fullscreenMode"
        Kirigami.FormData.label: Lang.i18n("In full screen, the island:")
        Kirigami.FormData.buddyFor: modeButtons.count > 0 ? modeButtons.itemAt(0) : null
        spacing: 0
        QQC2.ButtonGroup { id: modeGroup }
        Repeater {
            id: modeButtons
            model: section.modes
            delegate: QQC2.RadioButton {
                required property var modelData
                required property int index
                objectName: "fullscreenMode-" + modelData.value
                text: modelData.text
                QQC2.ButtonGroup.group: modeGroup
                checked: section.mode === modelData.value
                onToggled: if (checked) section.page.cfg_fullscreenMode = modelData.value
            }
        }
    }
    Hint {
        objectName: "fullscreenModeHint"
        text: section.modes[section.modeIndex].hint
              + (section.mode === 1 && !section.page.notch ? " " + Lang.i18n("In the oval layout that is under the full-screen window, as before.") : "")
    }
    Hint {
        visible: section.opensAtEdge && !Qt.platform.pluginName.startsWith("wayland")
        text: Lang.i18n("Only on Wayland: elsewhere a window that fills the screen lies over the island, which then stays as it is.")
    }

    // ---- when else ------------------------------------------------------------------------
    RowLayout {
        Kirigami.FormData.label: Lang.i18n("Also:")
        visible: section.mode !== 1
        QQC2.CheckBox {
            id: maximizedCheck
            objectName: "setting-peekMaximized"
            text: Lang.i18n("For maximised windows")
            Binding { target: maximizedCheck; property: "checked"; value: section.page.cfg_peekMaximized }
            onToggled: section.page.cfg_peekMaximized = checked
            Accessible.name: text
        }
        Kirigami.ContextualHelpButton {
            toolTipText: Lang.i18n("Off: only a window in full screen counts (any application: a video, a browser's F11, a terminal, a game), and only the one in front, on the island's screen and the desktop shown. While a top panel shows, a maximised window never meets the island anyway.")
        }
    }
    // (on the desktop too: only sliding up or shrinking, hiding would leave nothing to bring it back)
    RowLayout {
        visible: section.opensAtEdge
        QQC2.CheckBox {
            id: idleCheck
            objectName: "setting-peekIdle"
            text: Lang.i18n("On the desktop when nothing is going on, after")
            Binding { target: idleCheck; property: "checked"; value: section.page.cfg_peekIdle }
            onToggled: section.page.cfg_peekIdle = checked
            Accessible.name: text
        }
        SettingSpin {
            // (search needs: "peekIdle")
            settings: section.page; key: "peekIdleDelay"
            enabled: section.page.cfg_peekIdle
            Layout.preferredWidth: Kirigami.Units.gridUnit * 5
            from: 2; to: 300
            unit: Lang.i18n("%1 s")
            Accessible.name: Lang.i18n("Waiting time on the desktop")
        }
        Kirigami.ContextualHelpButton {
            toolTipText: Lang.i18n("Without a full-screen window: once the island has shown nothing but itself for a while (no music, timer, download or other live activity, no notification, not open and the pointer not on it), it draws up or in just as it does in full screen. The pointer at the edge opens it; anything that comes brings it back at once.")
        }
    }

    // ---- peeking: how much shows, and the light at the edge ---------------------------------
    ValueSlider {
        objectName: "setting-peekStrip"
        Kirigami.FormData.label: Lang.i18n("Part that shows:")
        visible: section.peeking
        from: 0; to: 12; stepSize: 1
        value: section.page.cfg_peekStrip
        valueText: section.page.cfg_peekStrip > 0 ? Lang.i18n("%1 px", section.page.cfg_peekStrip) : Lang.i18n("Nothing")
        onMoved: value => section.page.cfg_peekStrip = Math.round(value)
    }
    RowLayout {
        Kirigami.FormData.label: Lang.i18n("Light at the edge:")
        visible: section.peeking
        QQC2.CheckBox {
            id: glowCheck
            objectName: "setting-peekGlow"
            text: Lang.i18n("Light up when the pointer comes near")
            Binding { target: glowCheck; property: "checked"; value: section.page.cfg_peekGlow }
            onToggled: section.page.cfg_peekGlow = checked
            Accessible.name: text
        }
    }
    RowLayout {
        objectName: "setting-peekGlowColor"
        // (search needs: "peekGlow")
        Kirigami.FormData.label: Lang.i18n("Light colour:")
        visible: section.peeking && section.page.cfg_peekGlow
        QQC2.ComboBox {
            id: glowColour
            model: [Lang.i18n("The island's look"), Lang.i18n("Accent colour"), Lang.i18n("A colour of my own")]
            currentIndex: section.page.cfg_peekGlowColor
            onActivated: index => section.page.cfg_peekGlowColor = index
            Accessible.name: Lang.i18n("Light colour:")
        }
        ColorPickerButton {
            id: glowCustom
            objectName: "setting-peekGlowCustom"
            // (search needs: "peekGlow")
            visible: section.page.cfg_peekGlowColor === 2
            showAlphaChannel: false
            Binding { target: glowCustom; property: "color"; value: section.page.cfg_peekGlowCustom || "#3daee9" }
            onAccepted: c => section.page.cfg_peekGlowCustom = "#" + [c.r, c.g, c.b].map(v => Math.round(v * 255).toString(16).padStart(2, "0")).join("")
            Accessible.name: Lang.i18n("A colour of my own")
        }
    }
    Hint {
        objectName: "peekInvisibleHint"
        visible: section.peeking && section.page.cfg_peekStrip === 0 && !section.page.cfg_peekGlow
        color: Kirigami.Theme.neutralTextColor
        opacity: 1
        text: Lang.i18n("The island is wholly hidden: move the pointer to the top edge of the screen to open it.")
    }

    // ---- the rest: folded (not there in the normal mode, which has nothing more) ---------
    SettingsFold {
        title: Lang.i18n("Full-screen details")
        foldId: "appearance.fullscreen"
        twin: section
        visible: section.mode !== 1
        keys: ["peekGlowStrength", "peekTrigger", "peekDelay", "peekWidth", "peekEvents"]
        content: Kirigami.FormLayout {

            // ---- the preview ------------------------------------------------------------------
            RowLayout {
                Kirigami.FormData.label: Lang.i18n("Preview:")
                spacing: Kirigami.Units.largeSpacing
                Rectangle {
                    id: screenBox
                    objectName: "fullscreenPreview"
                    implicitWidth: Kirigami.Units.gridUnit * 16
                    implicitHeight: Kirigami.Units.gridUnit * 6
                    color: "#2b3a4a"
                    clip: true
                    readonly property bool full: tryButton.checked
                    readonly property real k: 0.6
                    readonly property real pillW: Math.round(Math.min(width * 0.6, section.shown.pillWidth * k))
                    readonly property real pillH: Math.round(Math.max(8, section.shown.pillHeight * k))
                    // what the island is in the preview
                    readonly property bool away: full && section.mode === 2 && !down
                    readonly property bool small: full && section.mode === 3 && !down
                    property bool down: false
                    onFullChanged: down = false
                    // the window over the whole screen: a film
                    Rectangle {
                        anchors.fill: parent
                        visible: screenBox.full
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#141820" }
                            GradientStop { position: 1; color: "#3a2a1a" }
                        }
                        QQC2.Label {
                            textFormat: Text.PlainText
                            anchors.centerIn: parent
                            color: "#c8c8c8"
                            font: Kirigami.Theme.smallFont
                            text: Lang.i18n("A window in full screen")
                        }
                    }
                    Item {
                        id: islandShape
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: screenBox.down ? screenBox.pillW * 1.6 : screenBox.pillW
                        height: screenBox.down ? screenBox.pillH * 2.6 : screenBox.pillH
                        readonly property real rest: section.page.notch ? 0 : Math.round(4 * screenBox.k)
                        y: screenBox.away ? section.page.cfg_peekStrip - screenBox.pillH : rest
                        scale: screenBox.small ? 0.5 : 1
                        transformOrigin: Item.Top
                        opacity: screenBox.full && section.mode === 0 ? 0 : 1
                        Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        NotchOutline {
                            anchors.fill: parent
                            visible: section.page.notch
                            radius: Math.min(height / 2, section.shown.notchRadius * screenBox.k)
                            ear: section.shown.notchEar * screenBox.k
                            earDepth: section.shown.notchEarDepth * screenBox.k
                            fillColor: section.shown.notchBody.length === 3 ? "transparent" : section.shown.bodyMid
                            gradientColors: section.shown.notchBody
                            gradientKind: section.shown.notchBodyKind
                            gradientAngle: section.shown.notchBodyAngle
                        }
                        Rectangle {
                            anchors.fill: parent
                            visible: !section.page.notch
                            radius: Math.min(height, screenBox.pillH) / 2
                            color: section.shown.bodyMid
                        }
                        HoverHandler { id: shapeHover; enabled: !screenBox.away }
                    }
                    // the strip at the edge that opens it (drawn up), or the nub
                    Item {
                        id: edgeStrip
                        visible: screenBox.away || screenBox.small
                        readonly property real wanted: section.page.cfg_peekWidth > 0 ? section.page.cfg_peekWidth * screenBox.k : islandShape.width
                        width: Math.min(screenBox.width, screenBox.small ? islandShape.width : wanted)
                        height: screenBox.small ? islandShape.height * 0.5 + islandShape.rest : Math.max(section.page.cfg_peekStrip, section.page.cfg_peekTrigger)
                        anchors.horizontalCenter: parent.horizontalCenter
                        HoverHandler { id: edgeHover }
                        Rectangle {
                            anchors.fill: parent
                            visible: screenBox.away
                            color: "transparent"
                            border.width: 1
                            border.color: Qt.alpha("#ff453a", 0.7)
                        }
                    }
                    // the light at the edge, as the island draws it (and for a moment with "Preview the light")
                    PeekGlow {
                        objectName: "fullscreenPreviewGlow"
                        width: Math.min(screenBox.width, edgeStrip.width + 40 * screenBox.k)
                        height: Math.round(18 * screenBox.k)
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: section.page.cfg_peekGlowColor === 2 ? section.page.cfg_peekGlowCustom
                             : section.page.cfg_peekGlowColor === 0 ? section.shown.accent : Kirigami.Theme.highlightColor
                        strength: section.page.cfg_peekGlowStrength / 100
                        lit: glowPreview.running || screenBox.away && section.page.cfg_peekGlow && edgeHover.hovered
                    }
                    Timer { id: glowPreview; interval: 2500 }
                    Timer {
                        id: opening
                        interval: Math.max(1, section.page.cfg_peekDelay)
                        onTriggered: if (edgeHover.hovered) screenBox.down = true
                    }
                    Connections {
                        target: edgeHover
                        function onHoveredChanged() { if (edgeHover.hovered) opening.restart(); else opening.stop(); }
                    }
                    Timer {
                        interval: 600
                        running: screenBox.down && !shapeHover.hovered
                        onTriggered: screenBox.down = false
                    }
                }
                ColumnLayout {
                    QQC2.Button {
                        id: tryButton
                        objectName: "fullscreenPreviewButton"
                        checkable: true
                        icon.name: checked ? "view-restore" : "view-fullscreen"
                        text: checked ? Lang.i18n("Leave full screen") : Lang.i18n("Try it")
                    }
                    QQC2.Button {
                        objectName: "fullscreenGlowPreview"
                        visible: section.peeking
                        icon.name: "games-highscores"
                        text: Lang.i18n("Preview the light")
                        onClicked: glowPreview.restart()
                    }
                    Hint {
                        Layout.maximumWidth: Kirigami.Units.gridUnit * 8
                        visible: tryButton.checked && section.opensAtEdge
                        text: section.peeking ? Lang.i18n("Move the pointer to the top edge, onto the red frame.") : Lang.i18n("Move the pointer onto the nub.")
                    }
                }
            }

            // ---- peeking --------------------------------------------------------------------------
            Hint {
                visible: section.peeking
                text: Lang.i18n("Only moved up, never made smaller: its lower edge shows. That strip opens it, from the topmost row of pixels down, so the pointer pushed against the edge finds it; nothing else of it takes a click.")
            }
            ValueSlider {
                objectName: "setting-peekGlowStrength"
                // (search needs: "peekGlow")
                Kirigami.FormData.label: Lang.i18n("Light strength:")
                visible: section.peeking && section.page.cfg_peekGlow
                from: 10; to: 100; stepSize: 10
                value: section.page.cfg_peekGlowStrength
                valueText: Lang.percent(section.page.cfg_peekGlowStrength)
                onMoved: value => section.page.cfg_peekGlowStrength = Math.round(value / 10) * 10
            }
            ValueSlider {
                objectName: "setting-peekTrigger"
                Kirigami.FormData.label: Lang.i18n("Opening place:")
                visible: section.peeking
                from: 1; to: 8; stepSize: 1
                value: section.page.cfg_peekTrigger
                valueText: Lang.i18n("%1 px", section.page.cfg_peekTrigger)
                onMoved: value => section.page.cfg_peekTrigger = Math.round(value)
            }
            Hint {
                visible: section.peeking
                text: Lang.i18n("How high the place is that opens it, from the topmost row of pixels down, where less of the island shows (or nothing): those rows of the window under it take no click. 1 px is enough for a pointer pushed against the edge.")
            }
            ValueSlider {
                objectName: "setting-peekDelay"
                Kirigami.FormData.label: Lang.i18n("Opens after:")
                visible: section.opensAtEdge
                from: 0; to: 1000; stepSize: 50
                value: section.page.cfg_peekDelay
                valueText: Lang.i18n("%1 ms", section.page.cfg_peekDelay)
                onMoved: value => section.page.cfg_peekDelay = Math.round(value / 50) * 50
            }
            Hint {
                visible: section.opensAtEdge
                text: Lang.i18n("How long the pointer rests there before it opens, so that passing over it does not.")
            }
            ValueSlider {
                objectName: "setting-peekWidth"
                Kirigami.FormData.label: Lang.i18n("Trigger width:")
                visible: section.peeking
                from: 0; to: 1200; stepSize: 10
                value: section.page.cfg_peekWidth
                valueText: section.page.cfg_peekWidth > 0 ? Lang.i18n("%1 px", section.page.cfg_peekWidth) : Lang.i18n("As wide as the island")
                onMoved: value => section.page.cfg_peekWidth = value < 40 ? 0 : Math.round(value / 10) * 10
            }
            Hint {
                visible: section.peeking
                text: Lang.i18n("Only across the island's place at the top: the rest of the edge is the full-screen window's. A browser or a video player shows its own bar when the pointer reaches its top edge; where that gets in the way, keep the width small.")
            }
            QQC2.CheckBox {
                id: callOpens
                objectName: "setting-peekEvents"
                Kirigami.FormData.label: Lang.i18n("Important events:")
                visible: section.opensAtEdge
                text: Lang.i18n("Open in full screen too, for an incoming call")
                Binding { target: callOpens; property: "checked"; value: section.page.cfg_peekEvents }
                onToggled: section.page.cfg_peekEvents = checked
            }
            Hint {
                visible: section.opensAtEdge
                text: Lang.i18n("Everything else only colours the part that shows: green for a call, yellow for a critical warning. The microphone and the camera in use and the screen recorded or shared colour nothing there.")
            }
        }
    }
}
