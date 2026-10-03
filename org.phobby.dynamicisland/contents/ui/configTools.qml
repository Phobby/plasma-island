/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Timer / alarm sound and Pomodoro lengths.
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {

    property string cfg_language
    Binding { target: Lang; property: "setting"; value: cfg_language; restoreMode: Binding.RestoreNone }
    property alias cfg_timerSoundEnabled: soundCheck.checked
    property alias cfg_timerSound: soundField.text
    property alias cfg_pomodoroWork: workSpin.value
    property alias cfg_pomodoroShortBreak: shortSpin.value
    property alias cfg_pomodoroLongBreak: longSpin.value
    property alias cfg_pomodoroRounds: roundsSpin.value

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: soundCheck
            Kirigami.FormData.label: Lang.i18n("Timer & alarm:")
            text: Lang.i18n("Play a sound when they go off")
        }
        RowLayout {
            Kirigami.FormData.label: Lang.i18n("Sound file:")
            enabled: soundCheck.checked
            QQC2.TextField {
                id: soundField
                Layout.preferredWidth: Kirigami.Units.gridUnit * 16
            }
            QQC2.Button {
                icon.name: "document-open"
                text: Lang.i18n("Choose…")
                onClicked: fileDialog.open()
            }
        }
        Dialogs.FileDialog {
            id: fileDialog
            nameFilters: [Lang.i18n("Sound files (*.oga *.ogg *.wav *.mp3 *.flac)")]
            currentFolder: "file:///usr/share/sounds"
            onAccepted: soundField.text = selectedFile.toString().replace(/^file:\/\//, "")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Lang.i18n("Pomodoro")
        }
        QQC2.SpinBox {
            id: workSpin
            Kirigami.FormData.label: Lang.i18n("Focus:")
            from: 5; to: 120
            textFromValue: (v) => Lang.i18n("%1 min", v)
            valueFromText: (t) => parseInt(t)
        }
        QQC2.SpinBox {
            id: shortSpin
            Kirigami.FormData.label: Lang.i18n("Short break:")
            from: 1; to: 60
            textFromValue: (v) => Lang.i18n("%1 min", v)
            valueFromText: (t) => parseInt(t)
        }
        QQC2.SpinBox {
            id: longSpin
            Kirigami.FormData.label: Lang.i18n("Long break:")
            from: 5; to: 90
            textFromValue: (v) => Lang.i18n("%1 min", v)
            valueFromText: (t) => parseInt(t)
        }
        QQC2.SpinBox {
            id: roundsSpin
            Kirigami.FormData.label: Lang.i18n("Long break after:")
            from: 2; to: 10
            textFromValue: (v) => Lang.i18np("%1 round", "%1 rounds", v)
            valueFromText: (t) => parseInt(t)
        }
    }
}
