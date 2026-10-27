/*
    SPDX-License-Identifier: GPL-2.0-or-later

    A folding part of a settings page ("Details"): a row with an arrow and a
    title that opens and closes what is below it, with the mouse or the
    keyboard (Tab to it, Space or Enter), and says whether it is open to a
    screen reader. What it holds is made only once it is first opened
    (`content`, usually a Kirigami.FormLayout lined up with the page's own:
    `twin`), so a closed part costs nothing when the page opens. Whether it
    was left open is remembered (SettingsMemory, by `foldId`).

    `keys`: the settings it holds; the search (SettingsSearch) opens it to
    show one of them. `needs`: the switch that shows it, when it is only
    there while that is on (written into SettingsIndex by tools/settings-index).

    Put it in a page's Kirigami.FormLayout (it spans the whole width there) or
    in a ColumnLayout.
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: fold
    objectName: "foldingSection"

    property string title: Lang.i18n("Details")
    // One short line of what is in it, shown while it is closed.
    property string summary: ""
    // "<page>.<part>": where its being open is remembered.
    property string foldId: ""
    property var keys: []
    // The switch that shows this part when it is there only while that is on (the search
    // shows that switch instead while it is off).
    property string needs: ""
    property Component content
    // The page's FormLayout the content's labels line up with.
    property Item twin: null
    property bool expanded: SettingsMemory.isOpen(foldId)
    onExpandedChanged: { SettingsMemory.setOpen(foldId, expanded); if (expanded) made = true; }
    // (made once opened, and kept: closing it does not throw away what was typed)
    property bool made: expanded
    readonly property Item item: loader.item

    Kirigami.FormData.isSection: true
    Layout.fillWidth: true
    spacing: 0

    function open(): void { expanded = true; }

    QQC2.AbstractButton {
        id: header
        objectName: "foldHeader"
        Layout.fillWidth: true
        implicitHeight: Math.max(Kirigami.Units.gridUnit * 2, row.implicitHeight + Kirigami.Units.smallSpacing * 2)
        hoverEnabled: true
        focusPolicy: Qt.StrongFocus
        onClicked: fold.expanded = !fold.expanded
        Accessible.role: Accessible.Button
        Accessible.name: fold.title
        Accessible.description: fold.expanded ? Lang.i18n("Open; press to close") : Lang.i18n("Closed; press to open")
        background: Rectangle {
            radius: Kirigami.Units.cornerRadius
            color: header.down ? Qt.alpha(Kirigami.Theme.highlightColor, 0.25)
                 : header.hovered || header.visualFocus ? Qt.alpha(Kirigami.Theme.highlightColor, 0.12) : "transparent"
            border.width: header.visualFocus ? 1 : 0
            border.color: Kirigami.Theme.focusColor
        }
        contentItem: RowLayout {
            id: row
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                source: "arrow-right"
                rotation: fold.expanded ? 90 : 0
                Behavior on rotation { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
            }
            QQC2.Label {
                textFormat: Text.PlainText
                text: fold.title
                font.weight: Font.DemiBold
            }
            QQC2.Label {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                visible: !fold.expanded && fold.summary.length > 0
                text: fold.summary
                elide: Text.ElideRight
                opacity: 0.65
                font: Kirigami.Theme.smallFont
            }
            Kirigami.Separator { Layout.fillWidth: !(fold.summary.length > 0 && !fold.expanded); Layout.leftMargin: Kirigami.Units.smallSpacing }
        }
    }

    Item {
        id: body
        Layout.fillWidth: true
        clip: true
        implicitHeight: fold.expanded && loader.item ? loader.item.implicitHeight + Kirigami.Units.smallSpacing : 0
        visible: implicitHeight > 0 || shut.running
        Behavior on implicitHeight { NumberAnimation { id: shut; duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
        Loader {
            id: loader
            width: parent.width
            active: fold.made
            sourceComponent: fold.content
            onLoaded: {
                if (!fold.twin || item.twinFormLayouts === undefined) return;
                item.twinFormLayouts = [fold.twin];
                // (wide or narrow as the page is: left to itself it is narrow while it is first laid out and
                // the page around it moves to and fro as it opens)
                if (fold.twin.wideMode !== undefined) item.wideMode = Qt.binding(() => fold.twin.wideMode);
            }
        }
    }
}
