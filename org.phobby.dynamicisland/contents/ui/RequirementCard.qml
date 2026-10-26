/*
    SPDX-License-Identifier: GPL-2.0-or-later

    "Something is missing", in the island, the same everywhere: what is
    missing, why this needs it (one sentence), how to get it (its page, and a
    command to copy: never run from here), "Set the path by hand" and "Check
    again", and that the rest of the island works without it. The texts are
    RequirementCatalog's; `title`, `text` and `command` can say something
    else for a case of the page's own (a model server that is installed but
    not running).

    Shown only where the feature is: a page shows it when it is opened and
    what it needs is not there; nothing about it is said anywhere else.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

IslandFlickable {
    id: card
    objectName: "requirementCard"

    required property Theme theme
    // The catalog's id (RequirementCatalog.order).
    property string requirement: ""
    property string title: ""
    property string text: ""
    property string command: ""
    // Whether "Set the path by hand" is offered (only for a command, and only in the island).
    property bool offerPath: true
    // Whether it says what is missing as a title of its own (not under a page's heading that says it).
    property bool showTitle: true
    signal recheck()

    readonly property var item: RequirementCatalog.item(requirement)
    readonly property bool isNative: requirement === "native"
    readonly property var installs: command.length > 0 ? [{ distro: "", command: command }] : RequirementCatalog.installs(requirement)
    property int chosen: 0
    onRequirementChanged: chosen = 0

    contentHeight: column.implicitHeight
    function copy(value: string): void {
        clip.text = value;
        clip.selectAll();
        clip.copy();
        clip.text = "";
    }
    TextEdit { id: clip; visible: false; textFormat: TextEdit.PlainText }

    component CommandLine: RowLayout {
        id: line
        property string command
        spacing: 6
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 28
            radius: 14
            color: card.theme.faint
            clip: true
            TextEdit {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextEdit.AlignVCenter
                readOnly: true
                selectByMouse: true
                textFormat: TextEdit.PlainText
                text: line.command
                color: card.theme.text
                selectionColor: card.theme.control
                font.family: "monospace"
                font.pointSize: card.theme.fontSmall * 0.85
                Accessible.name: line.command
            }
        }
        PillButton {
            theme: card.theme
            primary: true
            text: copied.running ? Lang.i18n("Copied") : Lang.i18n("Copy")
            onClicked: { card.copy(line.command); copied.restart(); }
            Timer { id: copied; interval: 2000 }
        }
    }

    ColumnLayout {
        id: column
        width: card.width
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            visible: card.showTitle
            spacing: 8
            Kirigami.Icon {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                source: card.isNative ? "run-build-install" : "dialog-warning-symbolic"
                color: card.theme.warning
                isMask: !card.isNative
            }
            Text {
                textFormat: Text.PlainText
                objectName: "requirementTitle"
                Layout.fillWidth: true
                text: card.title.length > 0 ? card.title : card.item !== null ? card.item.what : ""
                color: card.theme.text
                font.pointSize: card.theme.fontNormal
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
            }
        }
        Text {
            textFormat: Text.PlainText
            objectName: "requirementWhy"
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: card.text.length > 0 ? card.text
                : card.item === null ? "" : card.item.why + (card.isNative ? " " + card.item.more : "")
            color: card.theme.text
            font.pointSize: card.theme.fontSmall * 0.95
        }
        // one command per distribution: chosen with a chip
        Flow {
            Layout.fillWidth: true
            spacing: 4
            visible: card.installs.length > 1
            Repeater {
                model: card.installs.length > 1 ? card.installs : []
                delegate: PillButton {
                    required property var modelData
                    required property int index
                    theme: card.theme
                    primary: index === card.chosen
                    text: modelData.distro
                    onClicked: card.chosen = index
                }
            }
        }
        CommandLine {
            Layout.fillWidth: true
            visible: card.installs.length > 0
            command: card.installs.length > 0 ? card.installs[Math.min(card.chosen, card.installs.length - 1)].command : ""
        }
        // the native module: then the island itself, from its GitHub page
        CommandLine {
            Layout.fillWidth: true
            visible: card.isNative && card.command.length === 0
            command: RequirementCatalog.installCommand
        }
        Text {
            textFormat: Text.PlainText
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: card.item !== null && card.item.optional === true ? Lang.i18n("Only this part needs it; everything else works as it is.")
                                                                   : Lang.i18n("Everything else of the island works without it.")
            color: card.theme.subText
            font.pointSize: card.theme.fontSmall * 0.9
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            PillButton {
                theme: card.theme
                visible: card.item !== null && String(card.item.link || "").length > 0
                text: card.isNative ? Lang.i18n("GitHub page") : Lang.i18n("Its website")
                onClicked: Qt.openUrlExternally(card.item.link)
            }
            PillButton {
                objectName: "requirementPath"
                theme: card.theme
                visible: card.offerPath && card.item !== null && card.item.kind === "command" && typeof Requirements.openSettings === "function" && Requirements.nativeAvailable
                text: Lang.i18n("Set the path by hand")
                onClicked: Requirements.openSettings("configDiagnostics:" + card.requirement)
            }
            Item { Layout.fillWidth: true }
            PillButton {
                objectName: "requirementRecheck"
                theme: card.theme
                primary: true
                text: Lang.i18n("Check again")
                onClicked: { Requirements.recheck(); card.recheck(); }
            }
        }
    }
}
