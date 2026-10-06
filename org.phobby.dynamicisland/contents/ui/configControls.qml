/*
    SPDX-License-Identifier: GPL-2.0-or-later
    The buttons of the Controls page: which ones (at most six) and in what
    order (drag by the handle). The others are listed below to add. The same
    choice can be changed in the island by holding a button.
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property string cfg_language
    Binding { target: Lang; property: "setting"; value: page.cfg_language; restoreMode: Binding.RestoreNone }

    property string cfg_controlTiles

    ControlCatalog { id: catalog }
    readonly property var chosen: catalog.normalize(cfg_controlTiles)
    readonly property bool full: chosen.length >= catalog.maximum

    // The shown list follows cfg_controlTiles; a drag moves rows, the drop writes it back.
    ListModel { id: rows }
    function load(): void {
        rows.clear();
        for (const key of chosen) rows.append({ key: key });
    }
    function store(): void {
        const keys = [];
        for (let i = 0; i < rows.count; ++i) keys.push(rows.get(i).key);
        cfg_controlTiles = keys.join(",");
    }
    Component.onCompleted: load()
    onChosenChanged: {
        let same = rows.count === chosen.length;
        for (let i = 0; same && i < rows.count; ++i) same = rows.get(i).key === chosen[i];
        if (!same) load();
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        QQC2.Label {
            textFormat: Text.PlainText
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: Lang.i18n("The buttons on the Controls page, at most %1. Drag one by its handle to move it. In the island, holding a button changes them too.", catalog.maximum)
        }

        Kirigami.Heading {
            textFormat: Text.PlainText
            level: 4
            text: Lang.i18n("In the island (%1 of %2)", page.chosen.length, catalog.maximum)
        }
        QQC2.Label {
            textFormat: Text.PlainText
            visible: rows.count === 0
            text: Lang.i18n("None: the Controls page only shows the sliders.")
            opacity: 0.7
        }
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: contentHeight
            interactive: false
            spacing: Kirigami.Units.smallSpacing
            model: rows
            moveDisplaced: Transition {
                YAnimator { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad }
            }
            // The handle reads `index` from the delegate's context: no required properties here.
            delegate: Item {
                id: wrapper
                readonly property var info: catalog.info(model.key)
                width: list.width
                height: row.implicitHeight

                QQC2.ItemDelegate {
                    id: row
                    readonly property bool dragging: parent === list
                    width: wrapper.width
                    hoverEnabled: true
                    down: false
                    scale: dragging ? 1.03 : 1
                    Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                    background: Kirigami.ShadowedRectangle {
                        radius: Kirigami.Units.cornerRadius
                        color: row.dragging ? Kirigami.Theme.backgroundColor
                             : row.hovered ? Qt.alpha(Kirigami.Theme.highlightColor, 0.12)
                             : Qt.alpha(Kirigami.Theme.textColor, 0.04)
                        border.width: row.dragging ? 1 : 0
                        border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.6)
                        shadow.size: row.dragging ? Kirigami.Units.gridUnit : 0
                        shadow.color: Qt.rgba(0, 0, 0, 0.3)
                        shadow.yOffset: 2
                    }
                    contentItem: RowLayout {
                        spacing: Kirigami.Units.smallSpacing
                        Kirigami.ListItemDragHandle {
                            listItem: row
                            listView: list
                            onMoveRequested: (oldIndex, newIndex) => rows.move(oldIndex, newIndex, 1)
                            onDropped: page.store()
                        }
                        QQC2.Label {
                            textFormat: Text.PlainText
                            text: String(index + 1)
                            opacity: 0.6
                            Layout.preferredWidth: Kirigami.Units.gridUnit
                        }
                        Kirigami.Icon {
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                            source: wrapper.info ? wrapper.info.icon : ""
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            QQC2.Label { textFormat: Text.PlainText; Layout.fillWidth: true; text: wrapper.info ? wrapper.info.title : model.key; elide: Text.ElideRight }
                            QQC2.Label {
                                textFormat: Text.PlainText
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: wrapper.info ? wrapper.info.hint : ""
                                font: Kirigami.Theme.smallFont
                                opacity: 0.7
                                elide: Text.ElideRight
                            }
                        }
                        QQC2.ToolButton {
                            icon.name: "list-remove"
                            text: Lang.i18n("Remove")
                            display: QQC2.AbstractButton.IconOnly
                            QQC2.ToolTip.visible: hovered
                            QQC2.ToolTip.text: text
                            onClicked: page.cfg_controlTiles = page.chosen.filter(k => k !== model.key).join(",")
                        }
                    }
                }
            }
        }

        Kirigami.Heading {
            textFormat: Text.PlainText
            level: 4
            text: Lang.i18n("Other controls")
        }
        QQC2.Label {
            textFormat: Text.PlainText
            visible: page.full
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: Lang.i18n("The island has %1 buttons: remove one to add another.", catalog.maximum)
            opacity: 0.7
        }
        Repeater {
            model: catalog.tiles.filter(t => page.chosen.indexOf(t.key) < 0)
            delegate: QQC2.ItemDelegate {
                id: spare
                required property var modelData
                Layout.fillWidth: true
                hoverEnabled: true
                down: false
                background: Rectangle {
                    radius: Kirigami.Units.cornerRadius
                    color: spare.hovered ? Qt.alpha(Kirigami.Theme.highlightColor, 0.12) : "transparent"
                }
                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    Kirigami.Icon {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                        source: spare.modelData.icon
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        QQC2.Label { textFormat: Text.PlainText; Layout.fillWidth: true; text: spare.modelData.title; elide: Text.ElideRight }
                        QQC2.Label {
                            textFormat: Text.PlainText
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: spare.modelData.hint
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                            elide: Text.ElideRight
                        }
                    }
                    QQC2.ToolButton {
                        icon.name: "list-add"
                        text: Lang.i18n("Add")
                        display: QQC2.AbstractButton.IconOnly
                        enabled: !page.full
                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.text: text
                        onClicked: page.cfg_controlTiles = page.chosen.concat([spare.modelData.key]).join(",")
                    }
                }
            }
        }

        QQC2.Button {
            icon.name: "edit-undo"
            text: Lang.i18n("Restore default buttons")
            enabled: page.chosen.join(",") !== catalog.defaultTiles.join(",")
            onClicked: page.cfg_controlTiles = catalog.defaultTiles.join(",")
        }
    }
}
