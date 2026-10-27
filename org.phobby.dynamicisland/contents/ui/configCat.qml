/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Cat: the companion beside the island (contents/ui/companion). Whether it
    is there, where and how large, its coat, what it reacts to, what may be
    done to it, when it sleeps, what it does beside the dot, and whether it
    moves at all.

    The preview is the cat itself, with what is set here before it is
    applied: it can be stroked and clicked, and the buttons under it let
    happen what the island would tell it. "Show all poses" puts the gallery
    in its place (every pose and every frame of its motions).
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "companion"
import "companion/CatPoses.js" as Poses

KCM.SimpleKCM {
    id: page
    header: SettingsSearch { page: page; pageName: "configCat" }

    property string cfg_language
    Binding { target: Lang; property: "setting"; value: page.cfg_language; restoreMode: Binding.RestoreNone }
    property int cfg_clockFormat
    Binding { target: Lang; property: "clockSetting"; value: page.cfg_clockFormat; restoreMode: Binding.RestoreNone }

    // (the defaults of main.xml, as the window hands them in: what the preview starts from before that)
    property bool cfg_catEnabled: true
    property alias cfg_catSide: sideCombo.currentIndex
    property alias cfg_catSize: sizeSlider.value
    property string cfg_catFur
    property string cfg_catFurColor
    property bool cfg_catMusic: true
    property bool cfg_catThoughts: true
    property bool cfg_catEvents: true
    property bool cfg_catPetting: true
    property bool cfg_catClicks: true
    property bool cfg_catNoAnger: false
    property int cfg_catSulkSeconds: 10
    property int cfg_catSleepSeconds: 20
    property int cfg_catDot
    property bool cfg_catReduceMotion: false

    // The desktop's own "no animations" (System Settings): the cat stands still whatever is set here.
    readonly property bool desktopStill: Kirigami.Units.longDuration <= 1
    property bool gallery: false
    // (for looking at the preview from outside: tests)
    readonly property alias previewMind: mind
    readonly property var coatNames: ({ grey: Lang.i18n("Grey"), orange: Lang.i18n("Orange"), black: Lang.i18n("Black"),
                                        white: Lang.i18n("White"), tuxedo: Lang.i18n("Black and white") })

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        RowLayout {
            Layout.fillWidth: true
            QQC2.Label {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: Lang.i18n("A cat lives beside the island, only to be looked at.")
            }
            Kirigami.ContextualHelpButton {
                toolTipText: Lang.i18n("A cat lives beside the island: it sleeps while nothing happens, puts on headphones for music, thinks along with the AI and likes to be stroked. It is only there to be looked at: it never covers anything of the island, keeps nothing and sends nothing anywhere.")
            }
        }

        // ---- the preview ----------------------------------------------------------------
        Rectangle {
            id: stage
            objectName: "catStage"
            Layout.fillWidth: true
            implicitHeight: page.gallery ? Math.min(Kirigami.Units.gridUnit * 22, poses.height + 2 * Kirigami.Units.largeSpacing) : Kirigami.Units.gridUnit * 6.5
            radius: Kirigami.Units.cornerRadius
            color: "#2b3240"
            border.width: 1
            border.color: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.2)
            clip: true
            // (the gallery scrolls: drawn into a picture of the stage's size, so that no renderer
            // lets a vector shape out of it)
            layer.enabled: page.gallery

            // what the island would tell it: set by the buttons below
            property bool playing: false
            property bool thinking: false
            property bool asking: false
            property bool busy: false
            readonly property real pillHeight: Kirigami.Units.gridUnit * 2
            readonly property bool onRight: sideCombo.currentIndex === 2

            Item {
                anchors.fill: parent
                visible: !page.gallery
                // a pill, as the island's
                Rectangle {
                    id: pill
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(parent.height * 0.3)
                    width: Kirigami.Units.gridUnit * 10
                    height: stage.pillHeight
                    radius: height / 2
                    color: "#1b1c20"
                    border.width: 1
                    border.color: "#5c5e66"
                    QQC2.Label {
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        text: Qt.formatTime(new Date(), Lang.timeFormat)
                        color: "#f4f5f7"
                        font.weight: Font.DemiBold
                    }
                }
                CompanionController {
                    id: mind
                    objectName: "catPreviewMind"
                    active: page.cfg_catEnabled && !page.gallery
                    idle: !stage.busy && !stage.playing
                    playing: stage.playing
                    thinking: stage.thinking
                    asking: stage.asking
                    music: page.cfg_catMusic
                    thoughts: page.cfg_catThoughts
                    events: page.cfg_catEvents
                    petting: page.cfg_catPetting
                    clicks: page.cfg_catClicks
                    noAnger: page.cfg_catNoAnger
                    still: page.cfg_catReduceMotion || page.desktopStill
                    sleepAfter: page.cfg_catSleepSeconds * 1000
                    sulkFor: page.cfg_catSulkSeconds * 1000
                    onGesture: name => figure.gesture(name)
                }
                CatCharacter {
                    id: figure
                    objectName: "catPreview"
                    height: Math.round(stage.pillHeight * sizeSlider.value / 100)
                    width: Math.round(height * Poses.W / Poses.H)
                    x: stage.onRight ? pill.x + pill.width - 1 : pill.x - width + 1
                    y: pill.y + stage.pillHeight / 2 + (height - stage.pillHeight) * 0.25 - height / 2
                    visible: page.cfg_catEnabled
                    body: mind.body
                    accessory: mind.accessory
                    tilt: mind.tilt
                    look: over.hovered ? Math.max(-1, Math.min(1, (over.point.position.x - width / 2) / (width / 2))) * (mirrored ? -1 : 1) : 0
                    mirrored: stage.onRight
                    still: mind.still
                    running: visible && !page.gallery
                    fur: page.cfg_catFur
                    furColor: page.cfg_catFurColor.length > 0 ? page.cfg_catFurColor : "#c9a27c"
                    accent: Kirigami.Theme.highlightColor
                    HoverHandler {
                        id: over
                        onHoveredChanged: mind.hovered(hovered)
                        onPointChanged: if (hovered) mind.pointerAt(point.position.x, figure.width)
                    }
                    TapHandler { onTapped: mind.clicked() }
                }
                CompanionBubble {
                    kind: figure.visible ? mind.bubble : ""
                    still: mind.still
                    running: figure.running
                    side: figure.mirrored ? 1 : -1
                    size: Math.max(15, Math.round(figure.height * 0.4))
                    x: figure.mirrored ? figure.x + figure.bubbleAt.x + 1 : figure.x + figure.bubbleAt.x - width - 1
                    y: Math.max(0, figure.y + figure.bubbleAt.y - height * 0.75)
                }
                QQC2.Label {
                    textFormat: Text.PlainText
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Kirigami.Units.smallSpacing
                    text: Lang.i18n("Stroke it or click it here to see what it does.")
                    color: "#aab1bf"
                    font: Kirigami.Theme.smallFont
                }
            }
            // every pose, in the preview's place
            QQC2.ScrollView {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                visible: page.gallery
                contentWidth: availableWidth
                CatGallery {
                    id: poses
                    width: parent.width
                    // (made only when asked for: it is some two hundred cats)
                    show: page.gallery ? "all" : "none"
                    cell: Kirigami.Units.gridUnit * 4.5
                    fur: page.cfg_catFur
                    furColor: figure.furColor
                    accent: Kirigami.Theme.highlightColor
                    labelColor: "#dfe3ea"
                }
            }
        }
        // (a Flow: in a narrow window the buttons go on to the next line instead of past the edge)
        Flow {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            visible: !page.gallery
            QQC2.Label { textFormat: Text.PlainText; text: Lang.i18n("Try:"); height: implicitHeight; topPadding: Kirigami.Units.smallSpacing }
            QQC2.Button {
                text: Lang.i18n("Music")
                checkable: true
                onCheckedChanged: stage.playing = checked
            }
            QQC2.Button {
                text: Lang.i18n("AI thinking")
                checkable: true
                onCheckedChanged: { stage.thinking = checked; if (!checked) mind.notice("answer"); }
            }
            QQC2.Button {
                text: Lang.i18n("A question")
                checkable: true
                onCheckedChanged: stage.asking = checked
            }
            QQC2.Button {
                text: Lang.i18n("An event")
                onClicked: { stage.busy = true; mind.notice("perk"); eventOver.restart(); }
            }
            QQC2.Button {
                text: Lang.i18n("Timer done")
                onClicked: { stage.busy = true; mind.notice("cheer"); eventOver.restart(); }
            }
            Timer { id: eventOver; interval: 3000; onTriggered: stage.busy = false }
        }
        QQC2.Button {
            objectName: "catGalleryButton"
            icon.name: page.gallery ? "go-previous-symbolic" : "view-list-icons-symbolic"
            text: page.gallery ? Lang.i18n("Back to the preview") : Lang.i18n("Show all poses")
            onClicked: page.gallery = !page.gallery
        }

        Kirigami.FormLayout {
            id: form
            Layout.fillWidth: true

            SettingCheck {
                settings: page; key: "catEnabled"
                Kirigami.FormData.label: Lang.i18n("Cat:")
                text: Lang.i18n("Show the cat beside the island")
            }
            RowLayout {
                Kirigami.FormData.label: Lang.i18n("Side:")
                visible: page.cfg_catEnabled
                // (search needs: "catEnabled")
                QQC2.ComboBox {
                    id: sideCombo
                    objectName: "setting-catSide"
                    model: [Lang.i18n("By itself (the free side)"), Lang.i18n("Left"), Lang.i18n("Right")]
                    Accessible.name: Lang.i18n("Side:") + " " + currentText
                }
                Kirigami.ContextualHelpButton {
                    toolTipText: Lang.i18n("By itself it sits on the left: the split island's bubble and the privacy dots are on the right. On the right it keeps clear of them. Where a side has no room on the screen it takes the other.")
                }
            }
            RowLayout {
                objectName: "setting-catSize"
                Kirigami.FormData.label: Lang.i18n("Size:")
                visible: page.cfg_catEnabled
                // (search needs: "catEnabled")
                QQC2.Slider {
                    id: sizeSlider
                    from: 100
                    to: 180
                    stepSize: 5
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                }
                QQC2.Label { textFormat: Text.PlainText; text: Lang.i18n("%1 of the pill's height", Lang.percent(sizeSlider.value)) }
            }
            RowLayout {
                objectName: "setting-catFur"
                Kirigami.FormData.label: Lang.i18n("Coat:")
                visible: page.cfg_catEnabled
                // (search needs: "catEnabled")
                spacing: Kirigami.Units.smallSpacing
                Repeater {
                    model: ["grey", "orange", "black", "white", "tuxedo"]
                    delegate: QQC2.AbstractButton {
                        id: coat
                        required property string modelData
                        readonly property bool chosen: page.cfg_catFur === modelData
                        objectName: "coat-" + modelData
                        implicitWidth: Kirigami.Units.gridUnit * 1.7
                        implicitHeight: implicitWidth
                        onClicked: page.cfg_catFur = modelData
                        QQC2.ToolTip.text: page.coatNames[modelData]
                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                        Accessible.name: page.coatNames[modelData]
                        background: Rectangle {
                            radius: width / 2
                            color: figure.coats[coat.modelData].fur
                            border.width: coat.chosen ? 3 : 1
                            border.color: coat.chosen ? Kirigami.Theme.highlightColor
                                : Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.35)
                            // the second colour of a coat that has one
                            Rectangle {
                                visible: coat.modelData === "tuxedo"
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: parent.height * 0.14
                                width: parent.width * 0.4
                                height: width
                                radius: width / 2
                                color: figure.coats.tuxedo.soft
                            }
                        }
                    }
                }
                ColorPickerButton {
                    id: customCoat
                    objectName: "coat-custom"
                    showAlphaChannel: false
                    Component.onCompleted: color = page.cfg_catFurColor.length > 0 ? page.cfg_catFurColor : "#c9a27c"
                    onAccepted: c => { page.cfg_catFurColor = String(c).slice(0, 7); page.cfg_catFur = "custom"; }
                    QQC2.ToolTip.text: Lang.i18n("A colour of your own")
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
                QQC2.Label {
                    textFormat: Text.PlainText
                    text: page.cfg_catFur === "custom" ? Lang.i18n("A colour of your own") : (page.coatNames[page.cfg_catFur] ?? "")
                    opacity: 0.75
                }
            }

            SettingsFold {
                title: Lang.i18n("Behaviour")
                foldId: "cat.behaviour"
                twin: form
                visible: page.cfg_catEnabled
                needs: "catEnabled"
                keys: ["catMusic", "catThoughts", "catEvents", "catPetting", "catClicks", "catNoAnger", "catSulkSeconds",
                       "catSleepSeconds", "catDot", "catReduceMotion"]
                content: Kirigami.FormLayout {
                    SettingCheck {
                        settings: page; key: "catMusic"
                        Kirigami.FormData.label: Lang.i18n("Reactions:")
                        text: Lang.i18n("Music: headphones, and it nods along")
                    }
                    SettingCheck { settings: page; key: "catThoughts"; text: Lang.i18n("The AI and questions: a bubble beside its head") }
                    SettingCheck { settings: page; key: "catEvents"; text: Lang.i18n("Events: it wakes up, looks, is glad when a timer runs out") }
                    SettingCheck {
                        settings: page; key: "catPetting"
                        Kirigami.FormData.label: Lang.i18n("With the pointer:")
                        text: Lang.i18n("Stroking: the pointer back and forth over it")
                    }
                    SettingCheck { settings: page; key: "catClicks"; text: Lang.i18n("Clicks: startled by one, angry at too many, or when woken") }
                    SettingCheck {
                        settings: page; key: "catNoAnger"
                        enabled: page.cfg_catClicks
                        text: Lang.i18n("Never angry: every click is met with curiosity")
                    }
                    SettingSpin {
                        settings: page; key: "catSulkSeconds"
                        Kirigami.FormData.label: Lang.i18n("It sulks for:")
                        enabled: page.cfg_catClicks && !page.cfg_catNoAnger
                        from: 3; to: 120
                        unit: Lang.i18n("%1 s")
                    }
                    RowLayout {
                        Kirigami.FormData.label: Lang.i18n("It falls asleep after:")
                        SettingSpin {
                            settings: page; key: "catSleepSeconds"
                            from: 5; to: 3600; stepSize: 5
                            unit: Lang.i18n("%1 s")
                        }
                        Kirigami.ContextualHelpButton {
                            toolTipText: Lang.i18n("…of the island showing nothing but the clock. Asleep it costs next to nothing: nothing of it runs but a slow breath.")
                        }
                    }
                    SettingCombo {
                        settings: page; key: "catDot"
                        Kirigami.FormData.label: Lang.i18n("While the island is a dot:")
                        model: [Lang.i18n("Hidden"), Lang.i18n("Asleep beside the dot")]
                    }
                    SettingCheck {
                        settings: page; key: "catReduceMotion"
                        Kirigami.FormData.label: Lang.i18n("Motion:")
                        enabled: !page.desktopStill
                        text: Lang.i18n("Reduce motion: still poses, nothing nods or floats")
                    }
                    QQC2.Label {
                        textFormat: Text.PlainText
                        visible: page.desktopStill
                        Layout.maximumWidth: Kirigami.Units.gridUnit * 24
                        wrapMode: Text.Wrap
                        font: Kirigami.Theme.smallFont
                        opacity: 0.75
                        text: Lang.i18n("The desktop's animations are switched off (System Settings): the cat stands still whatever is set here.")
                    }
                }
            }
        }
    }
}
