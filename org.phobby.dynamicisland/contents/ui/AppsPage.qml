/*
    SPDX-License-Identifier: GPL-2.0-or-later

    "Apps": a grid of shortcuts to the applications the user chose. A click
    starts one; a right click selects it for renaming or removing; dragging
    moves it. "Add" lists the installed applications with a search field.

    `shortcuts` is the JSON list kept in the settings: { id (menu id of the
    .desktop file), name, icon, label (the user's own name, "" = the
    application's) }. Every change is handed back with edited(json).
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: page

    required property Theme theme
    property var apps: null                 // backend/AppsBackend.qml
    property string shortcuts: "[]"
    signal edited(string json)
    // An application was started: the island can close.
    signal launched()

    // More would neither fit the page nor stay a quick choice.
    readonly property int maximum: 12
    readonly property var list: {
        try {
            const given = JSON.parse(shortcuts || "[]");
            return Array.isArray(given) ? given.filter(s => s && typeof s.id === "string" && s.id.length > 0).slice(0, maximum) : [];
        } catch (e) { return []; }
    }
    readonly property bool full: list.length >= maximum

    // "grid" | "add"
    property string view: "grid"
    property int selected: -1               // the shortcut being renamed / removed
    property bool typing: false
    // A text field has the keyboard: the island stays open and focused.
    readonly property bool interacting: visible && typing
    onVisibleChanged: if (!visible) { view = "grid"; selected = -1; typing = false; dragFrom = -1; }
    onViewChanged: { typing = false; if (view === "add") Qt.callLater(() => { searchField.text = ""; page.typing = true; searchField.input.forceActiveFocus(); }); }

    Binding { target: page.apps; property: "listing"; value: page.visible && page.view === "add"; when: page.apps !== null }
    Binding { target: page.apps; property: "watching"; value: page.visible && page.view === "grid" && page.list.length > 0; when: page.apps !== null }

    function store(next: var): void { edited(JSON.stringify(next)); }
    function add(app: var): void {
        if (full || list.some(s => s.id === app.id)) return;
        store(list.concat([{ id: app.id, name: app.name, icon: app.icon, label: "" }]));
        view = "grid";
    }
    function remove(index: int): void {
        store(list.filter((s, i) => i !== index));
        selected = -1;
    }
    function rename(index: int, label: string): void {
        const text = label.trim();
        store(list.map((s, i) => i === index ? Object.assign({}, s, { label: text === s.name ? "" : text }) : s));
    }
    function move(from: int, to: int): void {
        if (from === to || from < 0 || to < 0 || from >= list.length || to >= list.length) return;
        const next = list.slice();
        next.splice(to, 0, next.splice(from, 1)[0]);
        store(next);
    }
    function start(index: int): void {
        const s = list[index];
        if (!s || !apps) return;
        if (apps.launch(s.id)) launched();
    }

    // ---- dragging a shortcut to another place -----------------------------------------
    readonly property real cellWidth: Math.floor(width / 6)
    readonly property real cellHeight: 58
    readonly property int columns: Math.max(1, Math.floor(width / cellWidth))
    property int dragFrom: -1
    property int dragTo: -1
    property real dragX: 0
    property real dragY: 0
    // Where a shortcut sits while another one is dragged past it.
    function slotOf(index: int): int {
        if (dragFrom < 0 || index === dragFrom) return index;
        if (dragFrom < dragTo && index > dragFrom && index <= dragTo) return index - 1;
        if (dragTo < dragFrom && index >= dragTo && index < dragFrom) return index + 1;
        return index;
    }

    // ---- the grid -----------------------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        visible: page.view === "grid"
        spacing: 4

        // Nothing yet
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: page.list.length === 0
            spacing: 8
            Item { Layout.fillHeight: true }
            Text {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: Lang.i18n("No applications added yet")
                color: page.theme.text
                font.pointSize: page.theme.fontSmall
                font.weight: Font.DemiBold
            }
            Text {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: Lang.i18n("Add the ones you start often; a click here opens them.")
                color: page.theme.subText
                font.pointSize: page.theme.fontSmall * 0.9
            }
            PillButton {
                Layout.alignment: Qt.AlignHCenter
                theme: page.theme
                primary: true
                text: Lang.i18n("+ Add an application")
                onClicked: page.view = "add"
            }
            Item { Layout.fillHeight: true }
        }

        Item {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: page.list.length > 0

            Repeater {
                // The shortcuts and, after them, the "add" tile.
                model: page.list.length + 1
                delegate: Item {
                    id: cell
                    required property int index
                    readonly property bool adder: index === page.list.length
                    readonly property var entry: adder ? null : page.list[index]
                    readonly property bool dragged: page.dragFrom === index
                    readonly property int slot: adder ? index : page.slotOf(index)
                    readonly property bool missing: !adder && page.apps !== null && !page.apps.known(entry.id)
                    width: page.cellWidth
                    height: page.cellHeight
                    x: dragged ? page.dragX : (slot % page.columns) * page.cellWidth
                    y: dragged ? page.dragY : Math.floor(slot / page.columns) * page.cellHeight
                    z: dragged ? 2 : 0
                    Behavior on x { enabled: !cell.dragged; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on y { enabled: !cell.dragged; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 12
                        color: page.selected === cell.index && !cell.adder ? page.theme.faint
                             : mouse.containsMouse || cell.dragged ? page.theme.hoverFill : "transparent"
                        border.width: page.selected === cell.index && !cell.adder ? 1 : 0
                        border.color: page.theme.control
                    }
                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - 6
                        spacing: 2
                        opacity: cell.adder ? (page.full ? 0.4 : 0.85) : cell.missing ? 0.4 : 1
                        scale: cell.dragged ? 1.12 : mouse.pressed ? 0.94 : 1
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            Kirigami.Icon {
                                anchors.fill: parent
                                visible: !cell.adder
                                source: cell.entry ? cell.entry.icon : ""
                                fallback: "application-x-executable"
                            }
                            Rectangle {
                                anchors.fill: parent
                                visible: cell.adder
                                radius: 10
                                color: page.theme.faint
                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    width: 14; height: 14
                                    source: "list-add-symbolic"
                                    color: page.theme.text
                                    isMask: true
                                }
                            }
                            // Running: a dot under the icon
                            Rectangle {
                                visible: !cell.adder && page.apps !== null && page.apps.isRunning(cell.entry.id)
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.bottom
                                anchors.topMargin: -1
                                width: 5; height: 5; radius: 2.5
                                color: page.theme.control
                                border.width: 1
                                border.color: page.theme.surface
                            }
                        }
                        Text {
                            textFormat: Text.PlainText
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: cell.adder ? Lang.i18n("Add") : (cell.entry.label || cell.entry.name)
                            color: page.theme.text
                            font.pointSize: page.theme.fontSmall * 0.85
                            elide: Text.ElideRight
                        }
                    }
                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: cell.dragged ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                        preventStealing: true
                        property real pressX: 0
                        property real pressY: 0
                        onPressed: event => { pressX = event.x; pressY = event.y; }
                        onPositionChanged: event => {
                            if (cell.adder || !(pressedButtons & Qt.LeftButton)) return;
                            if (!cell.dragged) {
                                if (Math.abs(event.x - pressX) + Math.abs(event.y - pressY) < 8) return;
                                page.selected = -1;
                                page.dragX = cell.x; page.dragY = cell.y;
                                page.dragFrom = page.dragTo = cell.index;
                            }
                            const at = mapToItem(grid, event.x, event.y);
                            page.dragX = Math.max(0, Math.min(grid.width - cell.width, at.x - pressX));
                            page.dragY = Math.max(0, Math.min(grid.height - cell.height, at.y - pressY));
                            const column = Math.max(0, Math.min(page.columns - 1, Math.floor(at.x / page.cellWidth)));
                            const row = Math.max(0, Math.floor(at.y / page.cellHeight));
                            page.dragTo = Math.max(0, Math.min(page.list.length - 1, row * page.columns + column));
                        }
                        onReleased: {
                            if (!cell.dragged) return;
                            const from = page.dragFrom, to = page.dragTo;
                            page.dragFrom = -1; page.dragTo = -1;
                            page.move(from, to);
                        }
                        onCanceled: { page.dragFrom = -1; page.dragTo = -1; }
                        onClicked: event => {
                            if (cell.adder) { if (!page.full) page.view = "add"; return; }
                            if (event.button === Qt.RightButton) { page.selected = page.selected === cell.index ? -1 : cell.index; return; }
                            if (page.selected >= 0) { page.selected = -1; return; }
                            page.start(cell.index);
                        }
                    }
                }
            }
        }

        // The limit, said where "Add" stops working
        Text {
            textFormat: Text.PlainText
            Layout.fillWidth: true
            visible: page.full && page.selected < 0 && page.list.length > 0
            horizontalAlignment: Text.AlignHCenter
            text: Lang.i18n("%1 applications at most: remove one to add another.", page.maximum)
            color: page.theme.subText
            font.pointSize: page.theme.fontSmall * 0.85
            elide: Text.ElideRight
        }

        // Right click: rename or remove the selected shortcut
        RowLayout {
            Layout.fillWidth: true
            visible: page.selected >= 0 && page.selected < page.list.length
            spacing: 6
            PillField {
                id: renameField
                theme: page.theme
                Layout.fillWidth: true
                implicitHeight: 22
                placeholder: Lang.i18n("Name")
                readonly property var entry: page.list[page.selected] ?? null
                onEntryChanged: text = entry ? (entry.label || entry.name) : ""
                onAccepted: { page.rename(page.selected, text); page.typing = false; page.selected = -1; }
                onEscaped: { page.typing = false; page.selected = -1; }
                Connections {
                    target: renameField.input
                    function onActiveFocusChanged() { page.typing = renameField.input.activeFocus || (page.view === "add" && searchField.input.activeFocus); }
                }
            }
            PillButton {
                theme: page.theme
                implicitHeight: 22
                primary: true
                text: Lang.i18n("Rename")
                onClicked: { page.rename(page.selected, renameField.text); page.typing = false; page.selected = -1; }
            }
            PillButton {
                theme: page.theme
                implicitHeight: 22
                primary: true
                tint: page.theme.red
                text: Lang.i18n("Remove")
                onClicked: { page.typing = false; page.remove(page.selected); }
            }
        }
    }

    // ---- adding: the installed applications ------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        visible: page.view === "add"
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
                onClicked: page.view = "grid"
            }
            PillField {
                id: searchField
                theme: page.theme
                Layout.fillWidth: true
                implicitHeight: 22
                placeholder: Lang.i18n("Search applications…")
                onEscaped: page.view = "grid"
                onAccepted: if (results.count > 0) page.add(results.model[0])
            }
        }
        IslandListView {
            id: results
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2
            model: {
                const all = page.apps ? page.apps.all : [];
                const q = searchField.text.trim().toLowerCase();
                const taken = page.list.map(s => s.id);
                return all.filter(a => taken.indexOf(a.id) < 0 && (q.length === 0 || a.name.toLowerCase().indexOf(q) >= 0 || a.generic.toLowerCase().indexOf(q) >= 0));
            }
            delegate: Rectangle {
                id: row
                required property var modelData
                width: results.width
                height: 26
                radius: 8
                color: rowMouse.containsMouse ? page.theme.hoverFill : "transparent"
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 8
                    spacing: 8
                    Kirigami.Icon {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        source: row.modelData.icon
                        fallback: "application-x-executable"
                    }
                    Text {
                        textFormat: Text.PlainText
                        text: row.modelData.name
                        color: page.theme.text
                        font.pointSize: page.theme.fontSmall
                        elide: Text.ElideRight
                        Layout.maximumWidth: row.width * 0.55
                    }
                    Text {
                        textFormat: Text.PlainText
                        Layout.fillWidth: true
                        text: row.modelData.generic
                        color: page.theme.subText
                        font.pointSize: page.theme.fontSmall * 0.9
                        elide: Text.ElideRight
                    }
                }
                MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.add(row.modelData) }
            }
            Text {
                textFormat: Text.PlainText
                anchors.centerIn: parent
                visible: results.count === 0
                text: page.apps && page.apps.all.length === 0 ? Lang.i18n("Loading…") : Lang.i18n("No application matches.")
                color: page.theme.subText
                font.pointSize: page.theme.fontSmall
            }
        }
    }
}
