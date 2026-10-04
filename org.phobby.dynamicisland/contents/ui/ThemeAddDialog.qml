/*
    SPDX-License-Identifier: GPL-2.0-or-later

    "Add New…" of Settings → Appearance: a theme from a file (chosen or
    dropped), or from the store. Either way the theme is checked
    (ThemeLibrary / ThemeStore), added to the user's looks under its own name
    and shown with its preview; it becomes the island's look only with
    "Apply". When a look of that name is there already the dialog asks first:
    overwrite, or add under another name.

    The store is asked for its list when its tab is opened, never before.
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.Dialog {
    id: dialog

    required property var library           // ThemeLibrary
    required property var store             // ThemeStore
    property var systemScheme: null
    // "Apply" was pressed on a theme (one of ThemeLibrary.themes).
    signal chosen(var theme)

    title: Lang.i18n("Add a Look")
    standardButtons: Kirigami.Dialog.Close
    preferredWidth: Kirigami.Units.gridUnit * 32
    padding: Kirigami.Units.largeSpacing

    // 0 = from a file, 1 = the store
    property alias section: tabs.currentIndex
    property string problem: ""
    property var added: null                // the theme that was just added
    property var pending: null              // a theme waiting for "overwrite or rename?"
    onOpened: { problem = ""; added = null; pending = null; }

    // A file was chosen or dropped.
    function take(path: string): void {
        problem = ""; added = null; pending = null;
        const read = library.readFile(path);
        if (read.ok) offer(read.theme); else problem = library.explain(read.error, read.field);
    }
    // Into the list, unless a look of that name is there: then the user is asked.
    function offer(theme: var): void {
        const result = library.add(theme, false);
        if (result.ok) { added = result.theme; pending = null; return; }
        if (result.error !== "exists") { problem = library.explain(result.error, ""); return; }
        pending = theme;
        renameField.text = library.freeName(theme.name);
    }
    function overwrite(): void {
        const result = library.add(pending, true);
        if (result.ok) added = result.theme; else problem = library.explain(result.error, "");
        pending = null;
    }
    function rename(): void {
        const name = renameField.text.trim();
        if (name.length === 0 || name.length > 60) return;
        offer(Object.assign({}, pending, { name: name }));
    }
    function download(entry: var): void {
        problem = ""; added = null; pending = null;
        store.download(entry, result => {
            if (result.ok) dialog.offer(result.theme);
            else dialog.problem = dialog.library.explain(result.error, result.field);
        });
    }

    component Card: QQC2.Frame {
        id: card
        property var style
        property string name
        property string author
        property string description
        default property alias actions: buttons.data
        Layout.fillWidth: true
        contentItem: RowLayout {
            spacing: Kirigami.Units.largeSpacing
            ThemePreview {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 7
                Layout.preferredHeight: Kirigami.Units.gridUnit * 3
                style: card.style
                systemScheme: dialog.systemScheme
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                QQC2.Label { Layout.fillWidth: true; text: card.name; font.weight: Font.DemiBold; elide: Text.ElideRight }
                QQC2.Label {
                    Layout.fillWidth: true
                    visible: card.author.length > 0
                    text: Lang.i18n("by %1", card.author)
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                    elide: Text.ElideRight
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    visible: card.description.length > 0
                    text: card.description
                    font: Kirigami.Theme.smallFont
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }
            RowLayout { id: buttons; spacing: Kirigami.Units.smallSpacing }
        }
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        QQC2.TabBar {
            id: tabs
            Layout.fillWidth: true
            QQC2.TabButton { icon.name: "document-open"; text: Lang.i18n("From a File") }
            QQC2.TabButton { icon.name: "get-hot-new-stuff"; text: Lang.i18n("Browse the Store") }
            // The store is only asked once its tab is looked at.
            onCurrentIndexChanged: {
                dialog.problem = ""; dialog.added = null; dialog.pending = null;
                if (currentIndex === 1 && dialog.store.state === "") dialog.store.browse();
            }
        }

        // ---- what happened to the last file or download: added, or a question, or why not ----
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: dialog.problem.length > 0
            type: Kirigami.MessageType.Error
            text: dialog.problem
        }
        ColumnLayout {
            Layout.fillWidth: true
            visible: dialog.pending !== null
            spacing: Kirigami.Units.smallSpacing
            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: true
                type: Kirigami.MessageType.Warning
                text: dialog.pending !== null ? Lang.i18n("You already have a look called “%1”.", dialog.pending.name) : ""
            }
            RowLayout {
                Layout.fillWidth: true
                QQC2.Button {
                    icon.name: "document-replace"
                    text: Lang.i18n("Overwrite")
                    onClicked: dialog.overwrite()
                }
                QQC2.Label { text: Lang.i18n("or add it as:") }
                QQC2.TextField {
                    id: renameField
                    Layout.fillWidth: true
                    maximumLength: 60
                    onAccepted: dialog.rename()
                }
                QQC2.Button {
                    icon.name: "edit-rename"
                    text: Lang.i18n("Rename")
                    enabled: renameField.text.trim().length > 0 && dialog.library.find(renameField.text) === null
                    onClicked: dialog.rename()
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            visible: dialog.added !== null
            spacing: Kirigami.Units.smallSpacing
            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: true
                type: Kirigami.MessageType.Positive
                text: Lang.i18n("Added to your looks. It is not in use until you apply it.")
            }
            Card {
                style: dialog.added !== null ? dialog.added.style : Styles.defaults("oxygen")
                name: dialog.added !== null ? dialog.added.name : ""
                author: dialog.added !== null ? dialog.added.author : ""
                description: dialog.added !== null ? dialog.added.description : ""
                QQC2.Button {
                    icon.name: "dialog-ok-apply"
                    text: Lang.i18n("Apply")
                    onClicked: { dialog.chosen(dialog.added); dialog.close(); }
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            currentIndex: tabs.currentIndex

            // ---- from a file ----
            ColumnLayout {
                spacing: Kirigami.Units.largeSpacing
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 6
                    radius: Kirigami.Units.cornerRadius
                    color: drop.containsDrag ? Qt.alpha(Kirigami.Theme.highlightColor, 0.18) : Qt.alpha(Kirigami.Theme.textColor, 0.04)
                    border.width: drop.containsDrag ? 2 : 1
                    border.color: drop.containsDrag ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, 0.25)
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Kirigami.Units.smallSpacing
                        Kirigami.Icon {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                            source: "document-import"
                        }
                        QQC2.Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: Lang.i18n("Drop a theme file here (.islandtheme.json)")
                        }
                        QQC2.Button {
                            Layout.alignment: Qt.AlignHCenter
                            icon.name: "document-open"
                            text: Lang.i18n("Choose a File…")
                            onClicked: chooser.open()
                        }
                    }
                    DropArea {
                        id: drop
                        anchors.fill: parent
                        onDropped: event => { if (event.hasUrls && event.urls.length > 0) dialog.take(dialog.library.pathOf(event.urls[0])); }
                    }
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                    text: Lang.i18n("A theme file holds settings only, no code: it is checked, added to your looks under its own name, and kept in %1.", dialog.library.directory)
                }
            }

            // ---- the store ----
            ColumnLayout {
                spacing: Kirigami.Units.smallSpacing
                RowLayout {
                    Layout.fillWidth: true
                    visible: dialog.store.state === "loading"
                    QQC2.BusyIndicator { Layout.preferredWidth: Kirigami.Units.gridUnit * 1.5; Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5; running: visible }
                    QQC2.Label { text: Lang.i18n("Asking the store…") }
                }
                Kirigami.InlineMessage {
                    Layout.fillWidth: true
                    visible: dialog.store.state === "error"
                    type: dialog.store.configured ? Kirigami.MessageType.Error : Kirigami.MessageType.Information
                    text: dialog.store.configured ? dialog.store.error
                        : Lang.i18n("The store has no address yet: the project's catalog is not published. Themes can be added from files meanwhile.")
                    actions: Kirigami.Action {
                        visible: dialog.store.configured
                        icon.name: "view-refresh"
                        text: Lang.i18n("Try again")
                        onTriggered: dialog.store.browse()
                    }
                }
                QQC2.ScrollView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(Kirigami.Units.gridUnit * 16, storeList.implicitHeight + 2)
                    visible: dialog.store.state === "ready"
                    contentWidth: availableWidth
                    ColumnLayout {
                        id: storeList
                        width: parent.width
                        spacing: Kirigami.Units.smallSpacing
                        Repeater {
                            model: dialog.store.entries
                            delegate: Card {
                                id: entryCard
                                required property var modelData
                                readonly property var owned: dialog.library.find(modelData.name)
                                style: owned !== null ? owned.style : Styles.normalize(modelData.preview)
                                name: modelData.name
                                author: modelData.author
                                description: modelData.description
                                QQC2.Button {
                                    visible: entryCard.owned !== null
                                    icon.name: "dialog-ok-apply"
                                    text: Lang.i18n("Apply")
                                    onClicked: { dialog.chosen(entryCard.owned); dialog.close(); }
                                }
                                QQC2.Button {
                                    icon.name: "download"
                                    enabled: dialog.store.busy[entryCard.modelData.id] !== true
                                    text: dialog.store.busy[entryCard.modelData.id] === true ? Lang.i18n("Downloading…")
                                        : entryCard.owned !== null ? Lang.i18n("Download Again") : Lang.i18n("Download")
                                    onClicked: dialog.download(entryCard.modelData)
                                }
                            }
                        }
                        QQC2.Label {
                            visible: dialog.store.entries.length === 0
                            text: Lang.i18n("The store has no themes yet.")
                            opacity: 0.7
                        }
                    }
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                    text: Lang.i18n("The list comes from the project's catalog on GitHub when this tab is opened, a theme when you press Download; nothing else is asked, and nothing in the background. A download is checked against the catalog's checksum and added to your looks; it is not applied by itself.")
                }
            }
        }
    }

    Dialogs.FileDialog {
        id: chooser
        nameFilters: [Lang.i18n("Island themes (*.islandtheme.json)"), Lang.i18n("All files (*)")]
        onAccepted: dialog.take(dialog.library.pathOf(selectedFile))
    }
}
