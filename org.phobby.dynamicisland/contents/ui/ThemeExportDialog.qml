/*
    SPDX-License-Identifier: GPL-2.0-or-later
    "Export Theme…" of Settings → Appearance: the look being edited, written
    as a theme file (ThemeFile.js) under a name, to where the user chooses.
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "ThemeFile.js" as ThemeFile

Kirigami.Dialog {
    id: dialog

    required property var library           // ThemeLibrary
    property var style: Styles.defaults("oxygen")
    property string suggestedName: ""
    property string outcome: ""
    property bool failed: false

    title: Lang.i18n("Export Theme")
    standardButtons: Kirigami.Dialog.Close
    preferredWidth: Kirigami.Units.gridUnit * 26
    padding: Kirigami.Units.largeSpacing
    onOpened: { outcome = ""; failed = false; nameField.text = suggestedName; nameField.forceActiveFocus(); nameField.selectAll(); }

    function save(path: string): void {
        const written = library.exportTo(path, nameField.text, authorField.text, descriptionField.text, style);
        failed = written.length === 0;
        outcome = failed ? library.explain("write", "") : Lang.i18n("Saved as %1", written);
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing
        Kirigami.FormLayout {
            Layout.fillWidth: true
            QQC2.TextField {
                id: nameField
                Kirigami.FormData.label: Lang.i18n("Name:")
                Layout.preferredWidth: Kirigami.Units.gridUnit * 16
                maximumLength: 60
                placeholderText: Lang.i18n("What the theme is called in the list")
                onAccepted: if (saveButton.enabled) saveButton.clicked()
            }
            QQC2.TextField {
                id: authorField
                Kirigami.FormData.label: Lang.i18n("Author:")
                Layout.preferredWidth: Kirigami.Units.gridUnit * 16
                maximumLength: 80
                placeholderText: Lang.i18n("Optional")
            }
            QQC2.TextField {
                id: descriptionField
                Kirigami.FormData.label: Lang.i18n("Description:")
                Layout.preferredWidth: Kirigami.Units.gridUnit * 16
                maximumLength: 300
                placeholderText: Lang.i18n("Optional")
            }
        }
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: dialog.outcome.length > 0
            type: dialog.failed ? Kirigami.MessageType.Error : Kirigami.MessageType.Positive
            text: dialog.outcome
        }
        RowLayout {
            Layout.fillWidth: true
            QQC2.Label {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                text: Lang.i18n("Every Appearance setting of the custom look goes into one .islandtheme.json file; “Add New…” brings it back, here or on another computer.")
            }
            QQC2.Button {
                id: saveButton
                icon.name: "document-save-as"
                text: Lang.i18n("Save As…")
                enabled: nameField.text.trim().length > 0
                onClicked: {
                    saver.currentFile = saver.currentFolder + "/" + ThemeFile.slug(nameField.text) + ThemeFile.SUFFIX;
                    saver.open();
                }
            }
        }
    }

    Dialogs.FileDialog {
        id: saver
        fileMode: Dialogs.FileDialog.SaveFile
        nameFilters: [Lang.i18n("Island themes (*.islandtheme.json)")]
        defaultSuffix: "json"
        onAccepted: dialog.save(dialog.library.pathOf(selectedFile))
    }
}
