/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Activity priorities, split island, event duration and per-module switches.
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property string cfg_priorityOrder
    property alias cfg_splitIsland: splitCheck.checked
    property alias cfg_eventDuration: eventSpin.value
    property alias cfg_showPowerEvents: powerCheck.checked
    property alias cfg_showBluetoothEvents: btCheck.checked
    property alias cfg_showOsdEvents: osdCheck.checked
    property alias cfg_showKeyboardEvents: keyboardCheck.checked
    property alias cfg_showNetworkEvents: networkCheck.checked
    property alias cfg_showDndEvents: dndCheck.checked
    property alias cfg_showRecording: recordingCheck.checked
    property alias cfg_showPrivacy: privacyCheck.checked
    property alias cfg_showUnlock: unlockCheck.checked
    property alias cfg_showJobs: jobsCheck.checked
    property alias cfg_showKdeConnect: kdeconnectCheck.checked
    property alias cfg_showUpdates: updatesCheck.checked
    property alias cfg_showThermalWarning: thermalCheck.checked
    property alias cfg_enableDbusApi: dbusCheck.checked
    property alias cfg_showDevicesModule: devicesCheck.checked
    property alias cfg_showQuickSettings: quickCheck.checked
    property alias cfg_showTools: toolsCheck.checked
    property alias cfg_showCalendar: calendarCheck.checked

    readonly property var categoryNames: ({
        privacy: i18n("Privacy indicators"),
        call: i18n("Phone calls"),
        recording: i18n("Screen recording"),
        event: i18n("Transient events"),
        timer: i18n("Timers, Pomodoro, calendar"),
        transfer: i18n("File operations & custom activities"),
        media: i18n("Media")
    })
    readonly property var order: cfg_priorityOrder.split(",").map(s => s.trim()).filter(s => s.length > 0)

    function move(index: int, delta: int): void {
        const list = order.slice();
        const target = index + delta;
        if (target < 0 || target >= list.length) return;
        const item = list.splice(index, 1)[0];
        list.splice(target, 0, item);
        cfg_priorityOrder = list.join(",");
    }

    Kirigami.FormLayout {
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Priority")
        }

        ColumnLayout {
            Kirigami.FormData.label: i18n("Highest first:")
            Kirigami.FormData.labelAlignment: Qt.AlignTop
            spacing: 2
            Repeater {
                model: page.order
                delegate: RowLayout {
                    required property int index
                    required property string modelData
                    QQC2.Label {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 16
                        text: (index + 1) + ". " + (page.categoryNames[modelData] ?? modelData)
                    }
                    QQC2.ToolButton {
                        icon.name: "go-up"
                        enabled: index > 0
                        onClicked: page.move(index, -1)
                        QQC2.ToolTip.text: i18n("Move up")
                        QQC2.ToolTip.visible: hovered
                    }
                    QQC2.ToolButton {
                        icon.name: "go-down"
                        enabled: index < page.order.length - 1
                        onClicked: page.move(index, 1)
                        QQC2.ToolTip.text: i18n("Move down")
                        QQC2.ToolTip.visible: hovered
                    }
                }
            }
            QQC2.Label {
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                wrapMode: Text.Wrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                text: i18n("The highest active item takes the island. Transient events cover everything ranked below \"Transient events\" and wait while something ranked above it is active.")
            }
        }

        QQC2.CheckBox {
            id: splitCheck
            Kirigami.FormData.label: i18n("Split island:")
            text: i18n("Show a second activity in a separate bubble")
        }
        QQC2.SpinBox {
            id: eventSpin
            Kirigami.FormData.label: i18n("Transient events stay:")
            from: 1000
            to: 10000
            stepSize: 500
            textFromValue: (v) => i18n("%1 s", (v / 1000).toLocaleString(Qt.locale(), 'f', 1))
            valueFromText: (t) => Math.round(Number.fromLocaleString(Qt.locale(), t.replace(/[^\d.,]/g, "")) * 1000)
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("System events")
        }
        QQC2.CheckBox { id: powerCheck; Kirigami.FormData.label: i18n("Show:"); text: i18n("Charging, battery and power profile") }
        QQC2.CheckBox { id: btCheck; text: i18n("Bluetooth devices") }
        QQC2.CheckBox { id: osdCheck; text: i18n("Volume, brightness and audio output") }
        QQC2.CheckBox { id: keyboardCheck; text: i18n("Caps Lock, Num Lock and keyboard layout") }
        QQC2.CheckBox { id: networkCheck; text: i18n("Wi-Fi, VPN and hotspot") }
        QQC2.CheckBox { id: dndCheck; text: i18n("Do Not Disturb") }
        QQC2.CheckBox { id: unlockCheck; text: i18n("\"Unlocked\" after the screen is unlocked") }
        QQC2.CheckBox { id: thermalCheck; text: i18n("High temperature warning") }
        QQC2.CheckBox { id: updatesCheck; text: i18n("Available updates") }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Live activities")
        }
        QQC2.CheckBox { id: recordingCheck; Kirigami.FormData.label: i18n("Show:"); text: i18n("Screen recording / sharing") }
        QQC2.CheckBox { id: privacyCheck; text: i18n("Microphone and camera indicators") }
        QQC2.CheckBox { id: jobsCheck; text: i18n("File operations and downloads") }
        QQC2.CheckBox { id: kdeconnectCheck; text: i18n("KDE Connect (calls, phone battery)") }
        QQC2.CheckBox { id: dbusCheck; text: i18n("Activities from other programs (D-Bus, island-push)") }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Expanded pages")
        }
        QQC2.CheckBox { id: devicesCheck; Kirigami.FormData.label: i18n("Show:"); text: i18n("Devices") }
        QQC2.CheckBox { id: quickCheck; text: i18n("Controls (Control Center)") }
        QQC2.CheckBox { id: toolsCheck; text: i18n("Tools (timer, stopwatch, Pomodoro, alarm)") }
        QQC2.CheckBox { id: calendarCheck; text: i18n("Upcoming calendar event") }

        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: i18n("Screen recording, privacy indicators, unlock, calls, updates and the D-Bus API need the native module (install.sh builds it).")
        }
    }
}
