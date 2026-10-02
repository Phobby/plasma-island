/*
    SPDX-License-Identifier: GPL-2.0-or-later
    "Calendar": the rest of today in chronological order, one row per event
    with the colour of its calendar. Clicking a row opens its meeting link.
    While no calendar is connected the page offers to open the settings.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: page

    required property Theme theme
    property var provider: null            // CalendarProvider
    readonly property var events: provider ? provider.today : []
    readonly property var pinned: provider ? provider.pinned : null
    readonly property bool connected: provider !== null && provider.calendar.available
    signal configureRequested()

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        model: page.events

        header: Text {
            width: list.width
            visible: page.provider !== null && page.provider.errorNames.length > 0
            height: visible ? implicitHeight + 4 : 0
            text: visible ? i18n("Could not update: %1", page.provider.errorNames.join(", ")) : ""
            color: page.theme.readable(page.theme.warning, page.theme.surface)
            font.pointSize: page.theme.fontSmall * 0.9
            elide: Text.ElideRight
        }

        delegate: Rectangle {
            id: row
            required property var modelData
            readonly property bool current: page.pinned !== null && page.pinned.key === modelData.key
            readonly property bool running: !modelData.allDay && !modelData.todo && page.provider.coarseNow >= modelData.start && page.provider.coarseNow < modelData.end
            readonly property bool over: !modelData.allDay && page.provider.coarseNow >= modelData.end
            readonly property bool hasLink: modelData.link.length > 0

            width: list.width
            height: 34
            radius: 10
            color: rowMouse.pressed && hasLink ? page.theme.pressedFill
                 : rowMouse.containsMouse && hasLink ? page.theme.over(page.theme.hoverFill, page.theme.over(page.theme.faint, page.theme.surface))
                 : current || running ? page.theme.faint : "transparent"
            opacity: over ? 0.55 : 1
            Behavior on color { ColorAnimation { duration: 120 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 8
                spacing: 8

                // Source calendar colour
                Rectangle {
                    Layout.preferredWidth: 4
                    Layout.preferredHeight: 22
                    radius: 2
                    color: row.modelData.color
                }
                Text {
                    Layout.preferredWidth: timeMetrics.width
                    text: row.modelData.allDay ? i18n("All day") : page.provider.clock(row.modelData.start)
                    color: row.running ? page.theme.text : page.theme.subText
                    font.pointSize: page.theme.fontSmall
                    font.weight: row.running ? Font.DemiBold : Font.Normal
                    font.features: { "tnum": 1 }
                    TextMetrics { id: timeMetrics; font.pointSize: page.theme.fontSmall; text: i18n("All day") }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        Layout.fillWidth: true
                        text: (row.modelData.todo ? "☐ " : "") + (row.modelData.title || i18n("Event"))
                        color: page.theme.text
                        font.pointSize: page.theme.fontSmall
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        readonly property string where: row.modelData.location && row.modelData.location !== row.modelData.link ? row.modelData.location : ""
                        text: [row.modelData.calendar, where].filter(s => s.length > 0).join(" · ")
                        visible: text.length > 0
                        color: page.theme.subText
                        font.pointSize: page.theme.fontSmall * 0.85
                        elide: Text.ElideRight
                    }
                }
                Text {
                    visible: row.running
                    text: visible ? i18nc("@info time left in a running event", "%1 left", page.provider.span(row.modelData.end - page.provider.coarseNow)) : ""
                    color: page.theme.readable(row.modelData.color, page.theme.surface)
                    font.pointSize: page.theme.fontSmall * 0.9
                    font.features: { "tnum": 1 }
                }
                Kirigami.Icon {
                    visible: row.hasLink
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                    source: "camera-video-symbolic"
                    color: page.theme.text
                    isMask: true
                }
            }
            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: row.hasLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: page.provider.open(row.modelData)
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: page.events.length === 0
        spacing: 6
        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            source: "view-calendar-symbolic"
            color: page.theme.subText
            isMask: true
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: !page.connected ? i18n("No calendar connected")
                : !page.provider.calendar.loaded ? i18n("Loading calendar…") : i18n("Nothing else today")
            color: page.theme.subText
            font.pointSize: page.theme.fontNormal
        }
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            visible: !page.connected
            implicitWidth: connectLabel.implicitWidth + 24
            implicitHeight: 28
            radius: 14
            color: connectMouse.pressed ? page.theme.pressedFill
                 : connectMouse.containsMouse ? page.theme.over(page.theme.hoverFill, page.theme.over(page.theme.faint, page.theme.surface))
                 : page.theme.faint
            scale: connectMouse.pressed ? 0.95 : connectMouse.containsMouse ? 1.05 : 1
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            Text {
                id: connectLabel
                anchors.centerIn: parent
                text: i18nc("@action:button opens the calendar settings", "Connect a calendar…")
                color: page.theme.text
                font.pointSize: page.theme.fontSmall
                font.weight: Font.DemiBold
            }
            MouseArea { id: connectMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.configureRequested() }
        }
    }
}
