/*
    SPDX-License-Identifier: GPL-2.0-or-later

    "Something is missing", in the settings window: the same as the island's
    RequirementCard (RequirementCatalog's texts), in the window's own look.
    What is missing, why, the command to copy (one per distribution where
    that differs), its page, "Set the path by hand" (Settings › Diagnostics)
    and "Check again". A page shows it only where what it needs is not there.
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: notice
    objectName: "requirementNotice"

    property string requirement: ""
    // "Set the path by hand" (a command only; not on the Diagnostics page itself, which has the field)
    property bool offerPath: true
    property bool offerRecheck: true
    // Only what is missing and why (the commands are left to Settings › Diagnostics).
    property bool brief: false
    signal recheck()

    readonly property var item: RequirementCatalog.item(requirement)
    readonly property bool isNative: requirement === "native"
    readonly property var installs: RequirementCatalog.installs(requirement)
    property int chosen: 0
    onRequirementChanged: chosen = 0

    Layout.fillWidth: true
    Layout.maximumWidth: Kirigami.Units.gridUnit * 30
    spacing: Kirigami.Units.smallSpacing

    function escaped(value: string): string { return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }
    function copy(value: string): void {
        clip.text = value;
        clip.selectAll();
        clip.copy();
        clip.text = "";
    }
    TextEdit { id: clip; visible: false; textFormat: TextEdit.PlainText }

    component CommandRow: RowLayout {
        id: row
        property string command
        Layout.fillWidth: true
        QQC2.TextField {
            Layout.fillWidth: true
            readOnly: true
            text: row.command
            font.family: "monospace"
            Accessible.name: Lang.i18n("Command to copy")
        }
        QQC2.Button {
            icon.name: "edit-copy"
            text: copied.running ? Lang.i18n("Copied") : Lang.i18n("Copy")
            onClicked: { notice.copy(row.command); copied.restart(); }
            Timer { id: copied; interval: 2000 }
        }
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        visible: true
        type: notice.item !== null && notice.item.optional === true ? Kirigami.MessageType.Information : Kirigami.MessageType.Warning
        // (the message reads its text as rich text: the catalog's own words, escaped all the same)
        text: notice.item === null ? "" : "<b>" + notice.escaped(notice.item.what) + "</b><br>" + notice.escaped(notice.item.why
              + (notice.isNative && !notice.brief ? " " + notice.item.more : ""))
        actions: [
            Kirigami.Action {
                text: notice.isNative ? Lang.i18n("GitHub page") : Lang.i18n("Its website")
                icon.name: "internet-services"
                visible: notice.item !== null && String(notice.item.link || "").length > 0
                onTriggered: Qt.openUrlExternally(notice.item.link)
            },
            Kirigami.Action {
                text: Lang.i18n("Set the path by hand")
                icon.name: "document-edit"
                visible: notice.offerPath && notice.item !== null && notice.item.kind === "command" && SettingsNav.canGo(notice, "configDiagnostics")
                onTriggered: SettingsNav.go(notice, "configDiagnostics", notice.requirement)
            },
            Kirigami.Action {
                text: Lang.i18n("Check again")
                icon.name: "view-refresh"
                visible: notice.offerRecheck
                onTriggered: { Requirements.recheck(); notice.recheck(); }
            }
        ]
    }
    // one command per distribution: chosen with a button
    RowLayout {
        visible: !notice.brief && notice.installs.length > 1
        spacing: Kirigami.Units.smallSpacing
        Repeater {
            model: notice.brief ? [] : notice.installs.length > 1 ? notice.installs : []
            delegate: QQC2.Button {
                required property var modelData
                required property int index
                text: modelData.distro
                checkable: true
                checked: index === notice.chosen
                onClicked: notice.chosen = index
            }
        }
    }
    CommandRow {
        visible: !notice.brief && notice.installs.length > 0
        command: notice.installs.length > 0 ? notice.installs[Math.min(notice.chosen, notice.installs.length - 1)].command : ""
    }
    CommandRow {
        visible: !notice.brief && notice.isNative
        command: RequirementCatalog.installCommand
    }
    QQC2.Label {
        textFormat: Text.PlainText
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        font: Kirigami.Theme.smallFont
        opacity: 0.8
        text: notice.item !== null && notice.item.optional === true ? Lang.i18n("Only this part needs it; everything else works as it is.")
                                                                   : Lang.i18n("Everything else of the island works without it.")
    }
}
