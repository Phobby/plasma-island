/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Control Center: round toggles (Do Not Disturb, Night Light, power profile,
    Bluetooth, Wi-Fi, updates) and the adjustable sliders (brightness). Any
    backend that is not available simply hides its control.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: page

    required property Theme theme
    property var dnd: null
    property var display: null
    property var power: null
    property var bluetooth: null
    property var network: null
    property var core: null
    property bool showBrightness: true

    component Toggle: ColumnLayout {
        id: toggle
        property string icon
        property string label
        property string badge
        property bool checked
        property color tint: page.theme.blue
        signal clicked()
        spacing: 2
        Layout.preferredWidth: 60

        Rectangle {
            id: circle
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 40
            implicitHeight: 40
            radius: 20
            // on: vivid tint; off: neutral fill. Hover/pressed stay distinguishable in both.
            readonly property color base: toggle.checked ? toggle.tint : page.theme.faint
            color: mouse.pressed ? (toggle.checked ? Qt.darker(toggle.tint, 1.25) : page.theme.pressedFill)
                 : mouse.containsMouse && !toggle.checked ? page.theme.over(page.theme.hoverFill, page.theme.over(page.theme.faint, page.theme.surface))
                 : base
            border.width: mouse.containsMouse ? 1.5 : 0
            border.color: page.theme.readable(toggle.checked ? toggle.tint : page.theme.text, page.theme.surface)
            scale: mouse.pressed ? 0.92 : 1
            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on scale { NumberAnimation { duration: 100 } }
            Kirigami.Icon {
                anchors.centerIn: parent
                width: 20
                height: 20
                source: toggle.icon
                // WCAG: icon colour picked against the actual button colour.
                color: toggle.checked ? page.theme.onColor(toggle.tint) : page.theme.text
                isMask: true
            }
            // Small count badge (connected devices, pending updates)
            Rectangle {
                visible: toggle.badge.length > 0
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: -3
                width: Math.max(16, badgeText.implicitWidth + 8)
                height: 16
                radius: 8
                color: page.theme.text
                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: toggle.badge
                    color: page.theme.onColor(page.theme.text)
                    font.pointSize: page.theme.fontSmall * 0.8
                    font.weight: Font.Bold
                }
            }
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: toggle.clicked()
            }
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: toggle.label
            color: page.theme.text
            font.pointSize: page.theme.fontSmall * 0.95
            elide: Text.ElideRight
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6

            Toggle {
                visible: page.dnd !== null
                icon: "weather-clear-night-symbolic"
                label: i18nc("@action:button short for Do Not Disturb", "Focus")
                checked: page.dnd ? page.dnd.active : false
                tint: page.theme.purple
                onClicked: page.dnd.setActive(!page.dnd.active)
            }
            Toggle {
                visible: page.display !== null
                icon: "redshift-status-on"
                label: i18n("Night Light")
                checked: page.display ? !page.display.nightLightInhibited : false
                tint: page.theme.orange
                onClicked: page.display.toggleNightLight()
            }
            Toggle {
                visible: page.power !== null && page.power.profilesAvailable
                icon: page.power ? page.power.iconFor(page.power.profile) : ""
                label: page.power ? page.power.nameFor(page.power.profile) : ""
                checked: page.power ? page.power.profile !== "balanced" : false
                tint: page.power && page.power.profile === "performance" ? page.theme.red : page.theme.live
                onClicked: {
                    const list = page.power.profiles;
                    const i = list.indexOf(page.power.profile);
                    page.power.setProfile(list[(i + 1) % list.length]);
                }
            }
            Toggle {
                visible: page.bluetooth !== null && page.bluetooth.available
                icon: page.bluetooth && page.bluetooth.enabled ? "network-bluetooth-activated" : "network-bluetooth-inactive"
                label: i18n("Bluetooth")
                badge: page.bluetooth && page.bluetooth.connectedDevices.length > 0 ? String(page.bluetooth.connectedDevices.length) : ""
                checked: page.bluetooth ? page.bluetooth.enabled : false
                onClicked: page.bluetooth.setEnabled(!page.bluetooth.enabled)
            }
            Toggle {
                visible: page.core !== null && page.core.updatesAvailable
                icon: "system-software-update"
                label: i18nc("@action:button short", "Updates")
                badge: page.core && page.core.updateCount > 0 ? String(page.core.updateCount) : ""
                checked: page.core ? page.core.securityUpdateCount > 0 : false
                tint: page.theme.red
                onClicked: page.core.startDetached("plasma-discover", ["--mode", "update"])
            }
            Toggle {
                visible: page.network !== null && page.network.wirelessAvailable
                icon: page.network && page.network.wirelessEnabled ? "network-wireless" : "network-wireless-off"
                label: i18n("Wi-Fi")
                checked: page.network ? page.network.wirelessEnabled : false
                onClicked: page.network.setWireless(!page.network.wirelessEnabled)
            }
        }

        // Adjustable controls
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: sliders.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            ColumnLayout {
                id: sliders
                width: parent.width
                spacing: 4
                BrightnessModule {
                    Layout.fillWidth: true
                    theme: page.theme
                    display: page.showBrightness ? page.display : null
                }
            }
        }
    }
}
