/*
    SPDX-License-Identifier: GPL-2.0-or-later

    "Clipboard": everything copied recently (texts, code, images, files),
    from Plasma's clipboard history (ClipboardBackend). A click copies an
    entry again. Like Plasma's own clipboard popup: search, stars and the
    starred-only filter, edit a text, show it as a QR code, run the configured
    actions, remove one entry, clear the history. An image opens larger on
    the page itself, without leaving the island.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: page

    required property Theme theme
    required property var clipboard         // ClipboardBackend

    // "list" | "edit" | "qr" | "image"
    property string view: "list"
    property bool typing: false             // the search field has the keyboard
    property bool confirmClear: false
    property string status: ""
    property var target: null               // the row being edited, shown as a QR code or as an image
    readonly property bool interacting: visible && (typing || view === "edit")
    // A question waits for an answer ("Clear the history?"): for who watches the island (the companion).
    readonly property bool asking: visible && confirmClear
    // Klipper's actions menu ("open with…") is open: the island stays open
    // until something is chosen in it or it is closed.
    readonly property bool holdOpen: visible && awaitingMenu
    property bool awaitingMenu: false
    property bool menuSeen: false
    function runAction(uuid: string): void {
        menuSeen = false;
        awaitingMenu = popups.item !== null;
        clipboard.runAction(uuid);
        if (awaitingMenu) menuWait.restart();
    }
    Loader {
        id: popups
        source: "PopupBridge.qml"
        onStatusChanged: if (status === Loader.Error) console.info("org.phobby.dynamicisland: native module too old to keep the island open over clipboard menus; run install.sh again")
    }
    Binding { target: popups.item; property: "active"; value: page.awaitingMenu; when: popups.item !== null }
    Connections {
        target: popups.item
        function onOpenChanged() {
            if (popups.item.open) { page.menuSeen = true; menuWait.stop(); }
            else if (page.menuSeen) page.awaitingMenu = false;
        }
    }
    // No actions for this entry: Klipper shows no menu at all.
    Timer { id: menuWait; interval: 1500; onTriggered: if (!page.menuSeen) page.awaitingMenu = false }
    // Never held forever (e.g. some other popup stays open).
    Timer { interval: 60000; running: page.awaitingMenu; onTriggered: page.awaitingMenu = false }
    onVisibleChanged: if (!visible) { typing = false; confirmClear = false; }
    function back(): void { view = "list"; target = null; }

    function say(text: string): void { status = text; statusTimer.restart(); }
    Timer { id: statusTimer; interval: 2500; onTriggered: page.status = "" }
    Timer { id: clearTimer; interval: 4000; onTriggered: page.confirmClear = false }

    // Several lines with code-like punctuation or indentation, or a one-liner that looks like a statement.
    function isCode(text: string): bool {
        const t = text.slice(0, 2000);
        if (/^\s*(#include|import |from \S+ import|def |class |function |const |let |var |public |private |fn |func |package |using |SELECT |<\?php|#!\/)/m.test(t)) return true;
        if (t.indexOf("\n") >= 0) return /[{};]\s*$/m.test(t) || /^(\t| {2,})\S/m.test(t) && /[=(){}\[\]]/.test(t);
        return /(=>|\(\)|;\s*$|^\s*\$ |^\s*<\/?[a-z][^>]*>\s*$)/.test(t);
    }
    function kind(type: int, text: string): string {
        return type === 4 ? "image" : type === 8 ? "files" : isCode(text) ? "code" : /^\s*https?:\/\/\S+\s*$/i.test(text) ? "link" : "text";
    }
    readonly property var kindIcons: ({ image: "viewimage-symbolic", files: "document-multiple-symbolic", code: "code-context-symbolic",
                                        link: "link-symbolic", text: "edit-paste-symbolic" })
    function fileNames(text: string): string {
        return text.split(/\s+/).filter(s => s.length > 0).map(u => decodeURIComponent(u.replace(/\/+$/, "").replace(/^.*\//, ""))).join(", ");
    }

    // ---- list ----------------------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        visible: page.view === "list"
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            PillField {
                id: searchField
                theme: page.theme
                Layout.fillWidth: true
                implicitHeight: 26
                placeholder: page.status.length > 0 ? page.status : Lang.i18n("Search the clipboard…")
                onEdited: page.clipboard.filter = text
                onEscaped: { text = ""; page.clipboard.filter = ""; page.typing = false; }
                // The first click asks the island for the keyboard.
                MouseArea {
                    anchors.fill: parent
                    visible: !page.typing
                    cursorShape: Qt.IBeamCursor
                    onClicked: { page.typing = true; Qt.callLater(() => searchField.input.forceActiveFocus()); }
                }
            }
            // Starred entries only
            IconButton {
                visible: page.clipboard.starredCount > 0 || page.clipboard.starredOnly
                iconName: page.clipboard.starredOnly ? "starred-symbolic" : "non-starred-symbolic"
                iconSize: 14
                implicitWidth: 24; implicitHeight: 24
                color: page.clipboard.starredOnly ? page.theme.readable(page.theme.orange, page.theme.surface) : page.theme.text
                hoverColor: page.theme.faint
                onClicked: page.clipboard.starredOnly = !page.clipboard.starredOnly
            }
            // Clear the history (asks once more)
            IconButton {
                visible: !page.confirmClear && page.clipboard.count > 0
                iconName: "edit-clear-history-symbolic"
                iconSize: 14
                implicitWidth: 24; implicitHeight: 24
                color: page.theme.text
                hoverColor: page.theme.faint
                onClicked: { page.confirmClear = true; clearTimer.restart(); }
            }
            PillButton {
                visible: page.confirmClear
                theme: page.theme
                implicitHeight: 24
                primary: true
                tint: page.theme.danger
                text: Lang.i18n("Clear all")
                onClicked: { page.clipboard.clear(); page.confirmClear = false; }
            }
        }

        IslandListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2
            model: page.clipboard.model

            delegate: Rectangle {
                id: row
                required property var model
                required property int index
                required property string uuid
                required property int type
                required property var decoration
                required property size imageSize
                readonly property string text: model.display || ""
                readonly property string kind: page.kind(type, text)
                readonly property bool starred: model.starred === true
                readonly property bool hovered: rowMouse.containsMouse || buttonsHover.hovered

                width: list.width
                height: 34
                radius: 10
                color: rowMouse.pressed ? page.theme.pressedFill
                     : hovered ? page.theme.over(page.theme.hoverFill, page.theme.over(page.theme.faint, page.theme.surface)) : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (row.kind === "image") {
                            page.target = { uuid: row.uuid, image: row.decoration, size: row.imageSize };
                            page.view = "image";
                            return;
                        }
                        page.clipboard.copy(row.uuid); page.say(Lang.i18n("Copied")); list.positionViewAtBeginning();
                    }
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 4
                    spacing: 8

                    // Thumbnail of an image, else what kind of entry it is
                    Item {
                        Layout.preferredWidth: row.kind === "image" ? 44 : 16
                        Layout.preferredHeight: 28
                        Image {
                            anchors.fill: parent
                            visible: row.kind === "image"
                            source: visible ? row.decoration : ""
                            sourceSize.height: 56
                            cache: false
                            smooth: true
                            fillMode: Image.PreserveAspectFit
                        }
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            visible: row.kind !== "image"
                            width: 14; height: 14
                            source: page.kindIcons[row.kind]
                            color: row.starred ? page.theme.readable(page.theme.orange, page.theme.surface) : page.theme.subText
                            isMask: true
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: row.kind === "image" ? Lang.i18n("Image · %1 × %2", row.imageSize.width, row.imageSize.height)
                            : row.kind === "files" ? page.fileNames(row.text)
                            : row.text.slice(0, 400).replace(/^\s+/, "").replace(/\t/g, "  ")
                        textFormat: Text.PlainText
                        color: page.theme.text
                        font.pointSize: page.theme.fontSmall * (row.kind === "code" ? 0.85 : 0.95)
                        font.family: row.kind === "code" ? "monospace" : Kirigami.Theme.defaultFont.family
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                    Kirigami.Icon {
                        visible: row.starred && !row.hovered
                        Layout.preferredWidth: 12
                        Layout.preferredHeight: 12
                        source: "starred-symbolic"
                        color: page.theme.readable(page.theme.orange, page.theme.surface)
                        isMask: true
                    }
                    // Under the mouse: star, QR code, edit, actions, remove
                    Row {
                        visible: row.hovered
                        spacing: 0
                        HoverHandler { id: buttonsHover }
                        Repeater {
                            model: [
                                { icon: row.starred ? "starred-symbolic" : "non-starred-symbolic", show: true, run: () => row.model.starred = !row.starred },
                                { icon: "view-barcode-qr-symbolic", show: row.type === 2 && qrProbe.status === Loader.Ready, run: () => { page.target = { text: row.text }; page.view = "qr"; } },
                                { icon: "document-edit-symbolic", show: row.type === 2, run: () => page.edit(row.model, row.uuid, row.text) },
                                { icon: "system-run-symbolic", show: row.type === 2, run: () => page.runAction(row.uuid) },
                                { icon: "edit-delete-symbolic", show: true, run: () => page.clipboard.remove(row.uuid) }
                            ].filter(b => b.show)
                            delegate: IconButton {
                                required property var modelData
                                iconName: modelData.icon
                                iconSize: 12
                                implicitWidth: 22; implicitHeight: 22
                                color: page.theme.text
                                hoverColor: page.theme.faint
                                onClicked: modelData.run()
                            }
                        }
                    }
                }
            }

            Text {
                textFormat: Text.PlainText
                anchors.centerIn: parent
                width: parent.width
                visible: list.count === 0
                horizontalAlignment: Text.AlignHCenter
                text: page.clipboard.filter.length > 0 ? Lang.i18n("Nothing matches") : page.clipboard.starredOnly ? Lang.i18n("No starred entries") : Lang.i18n("The clipboard is empty")
                color: page.theme.subText
                font.pointSize: page.theme.fontSmall
            }
        }
    }
    // Whether QR codes can be made at all (Prison installed).
    Loader { id: qrProbe; active: true; visible: false; source: "ClipboardQr.qml" }

    // ---- edit a text ---------------------------------------------------------------
    function edit(model: var, uuid: string, text: string): void {
        target = { model: model, uuid: uuid };
        editor.text = text;
        view = "edit";
        Qt.callLater(() => { editor.forceActiveFocus(); editor.cursorPosition = editor.length; });
    }
    function saveEdit(): void {
        if (target && target.model) {
            target.model.display = editor.text;
            clipboard.copy(target.uuid);
            say(Lang.i18n("Saved and copied"));
        }
        view = "list"; target = null;
    }
    ColumnLayout {
        anchors.fill: parent
        visible: page.view === "edit"
        spacing: 4
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            IconButton {
                iconName: "go-previous-symbolic"
                iconSize: 12
                implicitWidth: 20; implicitHeight: 20
                color: page.theme.text
                hoverColor: page.theme.faint
                onClicked: page.back()
            }
            Text {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                text: Lang.i18n("Edit the copied text")
                color: page.theme.subText
                font.pointSize: page.theme.fontSmall * 0.9
            }
            PillButton {
                theme: page.theme
                implicitHeight: 20
                primary: true
                text: Lang.i18n("Save")
                onClicked: page.saveEdit()
            }
        }
        IslandFlickable {
            id: editorView
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: editor.implicitHeight
            function follow(r: rect): void {
                if (r.y < contentY) contentY = r.y;
                else if (r.y + r.height > contentY + height) contentY = r.y + r.height - height;
            }
            TextEdit {
                id: editor
                width: editorView.width
                height: Math.max(implicitHeight, editorView.height)
                wrapMode: TextEdit.Wrap
                textFormat: TextEdit.PlainText
                color: page.theme.text
                selectionColor: page.theme.control
                font.pointSize: page.theme.fontSmall
                selectByMouse: true
                onCursorRectangleChanged: editorView.follow(cursorRectangle)
                Keys.onEscapePressed: { page.view = "list"; page.target = null; }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_S && (event.modifiers & Qt.ControlModifier)) { page.saveEdit(); event.accepted = true; }
                }
            }
        }
    }

    // ---- an image, as large as the page ----------------------------------------------
    Item {
        anchors.fill: parent
        visible: page.view === "image"

        Image {
            id: bigImage
            anchors.fill: parent
            anchors.topMargin: imageBar.height + 4
            source: page.view === "image" && page.target ? page.target.image : ""
            sourceSize.width: Math.round(width * Screen.devicePixelRatio)
            sourceSize.height: Math.round(height * Screen.devicePixelRatio)
            cache: false
            smooth: true
            mipmap: true
            fillMode: Image.PreserveAspectFit
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.BackButton
            onClicked: page.back()
        }

        // Back, size, copy, remove
        Rectangle {
            id: imageBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 28
            radius: 14
            color: page.theme.faint
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 4
                spacing: 4
                IconButton {
                    iconName: "go-previous-symbolic"
                    iconSize: 12
                    implicitWidth: 22; implicitHeight: 22
                    color: page.theme.text
                    hoverColor: page.theme.faint
                    onClicked: page.back()
                }
                Text {
                    textFormat: Text.PlainText
                    Layout.fillWidth: true
                    text: page.target && page.target.size ? Lang.i18n("Image · %1 × %2", page.target.size.width, page.target.size.height) : ""
                    color: page.theme.subText
                    font.pointSize: page.theme.fontSmall * 0.9
                    elide: Text.ElideRight
                }
                PillButton {
                    theme: page.theme
                    implicitHeight: 22
                    primary: true
                    text: Lang.i18n("Copy")
                    onClicked: {
                        page.clipboard.copy(page.target.uuid);
                        page.back();
                        page.say(Lang.i18n("Copied"));
                        list.positionViewAtBeginning();
                    }
                }
                IconButton {
                    iconName: "edit-delete-symbolic"
                    iconSize: 12
                    implicitWidth: 22; implicitHeight: 22
                    color: page.theme.text
                    hoverColor: page.theme.faint
                    onClicked: { page.clipboard.remove(page.target.uuid); page.back(); }
                }
            }
        }
    }

    // ---- QR code -------------------------------------------------------------------
    RowLayout {
        anchors.fill: parent
        visible: page.view === "qr"
        spacing: 10
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4
            IconButton {
                iconName: "go-previous-symbolic"
                iconSize: 12
                implicitWidth: 20; implicitHeight: 20
                color: page.theme.text
                hoverColor: page.theme.faint
                onClicked: page.back()
            }
            Text {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: page.view === "qr" && page.target ? page.target.text.slice(0, 300) : ""
                textFormat: Text.PlainText
                color: page.theme.subText
                font.pointSize: page.theme.fontSmall * 0.9
                wrapMode: Text.Wrap
                elide: Text.ElideRight
            }
        }
        // White tile: a QR code needs a light, quiet border to scan.
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: height
            radius: 8
            color: "white"
            Loader {
                anchors.fill: parent
                anchors.margins: 6
                active: page.view === "qr"
                source: "ClipboardQr.qml"
                onLoaded: item.content = Qt.binding(() => page.target ? page.target.text : "")
            }
        }
    }
}
