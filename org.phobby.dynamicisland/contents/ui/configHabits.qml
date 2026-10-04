/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Habits: the permanent habits (rename, delete, drag into order), the evening
    review and its reminder, the calendar's colours, and "reset all data".
    Whether the Habits tab is shown is set in Layout.

    The habits and the days are the widget's own record (Habits.js), read and
    changed in its configuration directly, without Apply: as a cfg_ value
    Apply would write back what the record was when this page opened and lose
    what was ticked on the island meanwhile.
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasmoid
import "Habits.js" as Habits

KCM.SimpleKCM {
    id: page

    property string cfg_language
    Binding { target: Lang; property: "setting"; value: page.cfg_language; restoreMode: Binding.RestoreNone }

    property string cfg_habitsReviewTime
    property alias cfg_habitsReminder: reminderCheck.checked
    property alias cfg_habitsColorSource: colorCombo.currentIndex

    function widget(): var { try { return Plasmoid.configuration; } catch (e) { return null; } }
    readonly property string recordText: { const c = widget(); return c ? String(c.habitsData || "") : ""; }
    readonly property var record: Habits.parse(recordText)
    function store(next: var): void {
        const c = widget();
        if (c && next !== record) c.habitsData = Habits.text(next);
    }
    readonly property var year: Habits.summary(record, new Date(), 365)
    property int confirmDelete: -1          // the habit asked about
    property bool confirmReset: false

    // The list follows the record; a drag moves rows, the drop writes the order back.
    ListModel { id: rows }
    function sync(): void {
        const habits = Habits.active(record);
        let same = rows.count === habits.length;
        for (let i = 0; same && i < rows.count; ++i) same = rows.get(i).habitId === habits[i].id && rows.get(i).name === habits[i].name;
        if (same) return;
        rows.clear();
        for (const h of habits) rows.append({ habitId: h.id, name: h.name });
    }
    onRecordChanged: sync()
    Component.onCompleted: sync()
    function storeOrder(): void {
        const ids = [];
        for (let i = 0; i < rows.count; ++i) ids.push(rows.get(i).habitId);
        store(Habits.orderHabits(record, ids));
    }
    function add(): void {
        store(Habits.addHabit(record, newField.text, new Date()));
        newField.text = "";
    }

    readonly property int minutes: Habits.minutesOf(cfg_habitsReviewTime)
    function setTime(hour: int, minute: int): void {
        const two = n => (n < 10 ? "0" : "") + n;
        cfg_habitsReviewTime = two(hour) + ":" + two(minute);
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading {
            level: 4
            text: Lang.i18n("Permanent habits")
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: Lang.i18n("They are on every day's list until you delete them. Drag one by its handle to change the order. A deleted habit stays in the days already recorded; what you change here applies at once.")
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: contentHeight
            visible: rows.count > 0
            interactive: false
            spacing: Kirigami.Units.smallSpacing
            model: rows

            moveDisplaced: Transition {
                YAnimator { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad }
            }

            // The handle reads `index` from the delegate's context: no required properties here.
            delegate: Item {
                id: wrapper
                readonly property bool asking: page.confirmDelete === model.habitId
                width: list.width
                height: row.implicitHeight

                QQC2.ItemDelegate {
                    id: row
                    // Lifted off the list while it is being dragged.
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
                            onDropped: page.storeOrder()
                        }
                        QQC2.TextField {
                            id: nameField
                            Layout.fillWidth: true
                            visible: !wrapper.asking
                            text: model.name
                            // A name that is empty or another habit's is not taken: the field shows the kept one again.
                            onEditingFinished: {
                                page.store(Habits.renameHabit(page.record, model.habitId, text));
                                text = Qt.binding(() => model.name);
                            }
                        }
                        QQC2.ToolButton {
                            visible: !wrapper.asking
                            icon.name: "edit-delete"
                            display: QQC2.AbstractButton.IconOnly
                            text: Lang.i18n("Delete")
                            onClicked: page.confirmDelete = model.habitId
                            QQC2.ToolTip.visible: hovered
                            QQC2.ToolTip.text: text
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            visible: wrapper.asking
                            text: Lang.i18n("Delete “%1”? Earlier days keep it.", model.name)
                            elide: Text.ElideRight
                        }
                        QQC2.Button {
                            visible: wrapper.asking
                            icon.name: "edit-delete"
                            text: Lang.i18n("Delete")
                            onClicked: { page.confirmDelete = -1; page.store(Habits.deleteHabit(page.record, model.habitId, new Date())); }
                        }
                        QQC2.Button {
                            visible: wrapper.asking
                            text: Lang.i18n("Cancel")
                            onClicked: page.confirmDelete = -1
                        }
                    }
                }
            }
        }
        QQC2.Label {
            Layout.fillWidth: true
            visible: rows.count === 0
            wrapMode: Text.Wrap
            opacity: 0.7
            text: Lang.i18n("No habits yet. Add them here or on the island's Habits page.")
        }
        RowLayout {
            Layout.fillWidth: true
            QQC2.TextField {
                id: newField
                Layout.fillWidth: true
                placeholderText: Lang.i18n("New habit")
                onAccepted: page.add()
            }
            QQC2.Button {
                icon.name: "list-add"
                text: Lang.i18n("Add")
                enabled: newField.text.trim().length > 0
                onClicked: page.add()
            }
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: Lang.i18n("Evening review")
            }
            RowLayout {
                Kirigami.FormData.label: Lang.i18n("Time:")
                QQC2.SpinBox {
                    id: hourSpin
                    from: 0; to: 23
                    wrap: true
                    Binding { target: hourSpin; property: "value"; value: Math.floor(page.minutes / 60) }
                    textFromValue: v => (v < 10 ? "0" : "") + v
                    valueFromText: t => parseInt(t)
                    onValueModified: page.setTime(value, minuteSpin.value)
                }
                QQC2.Label { text: ":" }
                QQC2.SpinBox {
                    id: minuteSpin
                    from: 0; to: 59
                    stepSize: 5
                    wrap: true
                    Binding { target: minuteSpin; property: "value"; value: page.minutes % 60 }
                    textFromValue: v => (v < 10 ? "0" : "") + v
                    valueFromText: t => parseInt(t)
                    onValueModified: page.setTime(hourSpin.value, value)
                }
            }
            QQC2.CheckBox {
                id: reminderCheck
                Kirigami.FormData.label: Lang.i18n("Reminder:")
                text: Lang.i18n("Ask on the island how the day went")
            }
            QQC2.Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                wrapMode: Text.Wrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                text: Lang.i18n("If the computer is off, asleep or locked at that time, the question comes at the next start, wake-up or unlock and is still recorded for its own day. Only the latest missed day is asked; earlier ones can be filled in from the calendar. Without the reminder a dot on the Habits tab still shows that a day is not reviewed.")
            }

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: Lang.i18n("Calendar")
            }
            QQC2.ComboBox {
                id: colorCombo
                Kirigami.FormData.label: Lang.i18n("Colours:")
                model: [Lang.i18n("GitHub green"), Lang.i18n("The system's accent colour")]
            }

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: Lang.i18n("Data")
            }
            QQC2.Label {
                Kirigami.FormData.label: Lang.i18n("Recorded:")
                text: page.year.days > 0 ? Lang.i18np("%1 day recorded · %2 on average", "%1 days recorded · %2 on average", page.year.days, Lang.percent(Math.round(page.year.average * 100)))
                                         : Lang.i18n("Nothing recorded yet.")
            }
            QQC2.Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                wrapMode: Text.Wrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                text: Lang.i18n("Kept in the widget's own settings as one small text: the habits, each day's list with what was done, and whether it was reviewed, for the last year.")
            }
            QQC2.Button {
                visible: !page.confirmReset
                enabled: page.recordText.length > 0
                icon.name: "edit-delete"
                text: Lang.i18n("Reset all data…")
                onClicked: page.confirmReset = true
            }
            RowLayout {
                visible: page.confirmReset
                QQC2.Label { text: Lang.i18n("Delete all habits and every day's record?") }
                QQC2.Button {
                    icon.name: "edit-delete"
                    text: Lang.i18n("Delete")
                    onClicked: { const c = page.widget(); if (c) c.habitsData = ""; page.confirmReset = false; }
                }
                QQC2.Button {
                    text: Lang.i18n("Cancel")
                    onClicked: page.confirmReset = false
                }
            }
        }
    }
}
