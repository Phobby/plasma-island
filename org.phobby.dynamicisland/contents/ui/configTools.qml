/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Timer / alarm sound, Pomodoro lengths and the Pomodoro statistics (reset).
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasmoid
import "PomodoroStats.js" as Stats

KCM.SimpleKCM {
    id: page

    property string cfg_language
    Binding { target: Lang; property: "setting"; value: cfg_language; restoreMode: Binding.RestoreNone }
    property alias cfg_timerSoundEnabled: soundCheck.checked
    property alias cfg_timerSound: soundField.text
    property alias cfg_pomodoroWork: workSpin.value
    property alias cfg_pomodoroShortBreak: shortSpin.value
    property alias cfg_pomodoroLongBreak: longSpin.value
    property alias cfg_pomodoroRounds: roundsSpin.value
    // The statistics are the widget's own record, read and reset in its configuration
    // directly: as a cfg_ value Apply would write back what was counted when this
    // page opened and lose a round finished meanwhile.
    function widget(): var { try { return Plasmoid.configuration; } catch (e) { return null; } }
    readonly property string statsText: { const c = widget(); return c ? String(c.pomodoroStats || "") : ""; }
    readonly property var stats: Stats.parse(statsText)
    property bool confirmReset: false

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

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Lang.i18n("Pomodoro statistics")
        }
        QQC2.Label {
            Kirigami.FormData.label: Lang.i18n("Completed focus rounds:")
            text: Lang.i18n("Today: %1 · This week: %2 · Streak: %3", Stats.count(page.stats, new Date()), Stats.week(page.stats, new Date()),
                            Lang.i18np("%1 day", "%1 days", Stats.streak(page.stats, new Date())))
        }
        QQC2.Label {
            text: Lang.i18n("Total: %1 · Longest streak: %2", page.stats.total, Lang.i18np("%1 day", "%1 days", Stats.bestStreak(page.stats, new Date())))
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: Lang.i18n("Only focus rounds that ran to their end count; breaks, and rounds that were skipped or stopped, do not.")
        }
        QQC2.Button {
            visible: !page.confirmReset
            enabled: page.stats.total > 0
            icon.name: "edit-delete"
            text: Lang.i18n("Reset statistics…")
            onClicked: page.confirmReset = true
        }
        RowLayout {
            visible: page.confirmReset
            QQC2.Label { text: Lang.i18n("Delete all Pomodoro statistics?") }
            QQC2.Button {
                icon.name: "edit-delete"
                text: Lang.i18n("Delete")
                onClicked: { const c = page.widget(); if (c) c.pomodoroStats = ""; page.confirmReset = false; }
            }
            QQC2.Button {
                text: Lang.i18n("Cancel")
                onClicked: page.confirmReset = false
            }
        }
        QQC2.Label {
            visible: page.stats.total === 0 && !page.confirmReset
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: Lang.i18n("Nothing counted yet.")
        }
    }
}
