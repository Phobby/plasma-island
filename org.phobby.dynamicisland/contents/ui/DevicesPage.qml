/*
    SPDX-License-Identifier: GPL-2.0-or-later
    "Devices": connected Bluetooth devices and paired phones with battery rings.
    `devices` is a list of { icon, name, detail, battery (-1 = unknown), charging }.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: page

    required property Theme theme
    property var devices: []
    property int lowBattery: 15

    Flickable {
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: grid.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        Flow {
            id: grid
            width: parent.width
            spacing: 10

            Repeater {
                model: page.devices
                delegate: Column {
                    required property var modelData
                    width: 70
                    spacing: 3
                    MiniRing {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 46
                        height: 46
                        lineWidth: 3.5
                        value: modelData.battery >= 0 ? modelData.battery / 100 : 0
                        color: modelData.battery >= 0 && modelData.battery <= page.lowBattery ? page.theme.red
                             : modelData.charging ? page.theme.live : page.theme.live
                        trackColor: page.theme.track
                        icon: modelData.icon
                        textColor: page.theme.text
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.name
                        color: page.theme.text
                        font.pointSize: page.theme.fontSmall
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.battery >= 0 ? Lang.percent(modelData.battery) + (modelData.charging ? " ⚡" : "") : (modelData.detail || "")
                        color: page.theme.subText
                        font.pointSize: page.theme.fontSmall * 0.95
                        font.features: { "tnum": 1 }
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: page.devices.length === 0
        spacing: 6
        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            source: "network-bluetooth-symbolic"
            color: page.theme.subText
            isMask: true
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Lang.i18n("No connected devices")
            color: page.theme.subText
            font.pointSize: page.theme.fontNormal
        }
    }
}
