/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Screen brightness, one slider per display (laptop panel / DDC monitors),
    styled like VolumeModule.
*/
import QtQuick
import QtQuick.Layouts

Item {
    id: module

    required property Theme theme
    property var display: null          // DisplayBackend

    readonly property int count: repeater.count
    implicitHeight: column.implicitHeight
    visible: display !== null && display.brightnessAvailable && count > 0

    ColumnLayout {
        id: column
        anchors.fill: parent
        spacing: 4

        Repeater {
            id: repeater
            model: module.display ? module.display.displays : null
            delegate: RowLayout {
                id: row
                required property string displayName
                required property string label
                required property int brightness
                required property int maxBrightness
                Layout.fillWidth: true
                spacing: 8

                IconButton {
                    iconName: "video-display-brightness-symbolic"
                    color: module.theme.text
                    hoverColor: module.theme.hoverFill
                    toolTip: row.label
                    // Click toggles between dim (25%) and full, like the OSD keys.
                    onClicked: module.display.setBrightness(row.displayName, row.brightness > row.maxBrightness / 2 ? Math.round(row.maxBrightness * 0.25) : row.maxBrightness)
                }
                GlassSlider {
                    Layout.fillWidth: true
                    value: row.maxBrightness > 0 ? row.brightness / row.maxBrightness : 0
                    fillColor: module.theme.sliderFill
                    trackColor: module.theme.track
                    onMoved: v => module.display.setBrightness(row.displayName, Math.max(1, Math.round(v * row.maxBrightness)))
                }
                Text {
                    textFormat: Text.PlainText
                    Layout.preferredWidth: 36
                    horizontalAlignment: Text.AlignRight
                    text: Lang.percent(Math.round(row.maxBrightness > 0 ? row.brightness * 100 / row.maxBrightness : 0))
                    color: module.theme.subText
                    font.pointSize: module.theme.fontSmall
                    font.features: { "tnum": 1 }
                }
            }
        }
    }
}
