/*
    SPDX-License-Identifier: GPL-2.0-or-later

    New event, written to a calendar of a connected account (CalDavClient or
    GoogleCalendar) so that it reaches the phone: title, day, time or all day,
    place. `created(result, calendar, day)` carries the stored event.
*/
import QtQuick
import QtQuick.Layouts

Item {
    id: form

    required property Theme theme
    property var client: null               // CalDavClient
    property var google: null               // GoogleCalendar
    // [{ key, kind: "apple" | "google", name, color, ref }] the calendars events can go to
    property var calendars: []
    property string preferred: ""           // key of the calendar picked last
    signal picked(string key)
    signal created(var result, var calendar, real day)
    signal cancelled()

    property string error: ""
    property bool busy: false
    property bool allDay: false
    property var calendar: null
    readonly property bool interacting: true

    function pad(n: int): string { return n < 10 ? "0" + n : String(n); }
    // `day`: local midnight (ms) of the day selected in the month view.
    function reset(day: real): void {
        error = ""; busy = false; allDay = false;
        calendar = calendars.find(c => c.key === preferred) || calendars[0] || null;
        const d = new Date(day), now = new Date();
        const hour = Math.min(22, now.getHours() + 1);
        titleField.text = ""; placeField.text = "";
        dateField.text = pad(d.getDate()) + "." + pad(d.getMonth() + 1) + "." + d.getFullYear();
        startField.text = pad(hour) + ":00";
        endField.text = pad(hour + 1) + ":00";
        Qt.callLater(() => titleField.input.forceActiveFocus());
    }
    function nextCalendar(): void {
        const list = calendars;
        if (list.length < 2) return;
        calendar = list[(list.findIndex(c => c.key === calendar.key) + 1) % list.length];
        picked(calendar.key);
    }
    // Minutes since midnight, or -1.
    function minutes(text: string): int {
        const m = /^\s*(\d{1,2})[:.](\d{2})\s*$/.exec(text);
        if (!m || Number(m[1]) > 23 || Number(m[2]) > 59) return -1;
        return Number(m[1]) * 60 + Number(m[2]);
    }
    function submit(): void {
        if (busy || !calendar) return;
        const title = titleField.text.trim();
        if (title.length === 0) { error = Lang.i18n("Give the event a title."); return; }
        const dm = /^\s*(\d{1,2})[.\/-](\d{1,2})[.\/-](\d{4})\s*$/.exec(dateField.text);
        const date = dm ? new Date(Number(dm[3]), Number(dm[2]) - 1, Number(dm[1])) : null;
        if (!date || date.getMonth() !== Number(dm[2]) - 1 || date.getDate() !== Number(dm[1])) { error = Lang.i18n("Write the date as dd.mm.yyyy."); return; }
        const day = date.getTime();
        let start = day, end = new Date(date.getFullYear(), date.getMonth(), date.getDate() + 1).getTime();
        if (!allDay) {
            const from = minutes(startField.text), to = minutes(endField.text);
            if (from < 0 || to < 0) { error = Lang.i18n("Write the time as hh:mm (e.g. 14:30)."); return; }
            if (to <= from) { error = Lang.i18n("The end time must be after the start."); return; }
            start = new Date(date.getFullYear(), date.getMonth(), date.getDate(), Math.floor(from / 60), from % 60).getTime();
            end = new Date(date.getFullYear(), date.getMonth(), date.getDate(), Math.floor(to / 60), to % 60).getTime();
        }
        busy = true; error = "";
        const target = calendar;
        (target.kind === "google" ? google : client).createEvent(target.ref, { title: title, start: start, end: end, allDay: allDay, location: placeField.text.trim(), notes: "" }, result => {
            busy = false;
            if (!result.ok) { error = result.error; return; }
            form.created(result, target, day);
        });
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 5

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            spacing: 6
            Text {
                Layout.fillWidth: true
                text: form.error.length > 0 ? form.error : Lang.i18n("New event")
                color: form.error.length > 0 ? form.theme.readable(form.theme.danger, form.theme.surface) : form.theme.text
                font.pointSize: form.theme.fontSmall
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            // Which calendar the event goes to; a click picks the next one.
            Rectangle {
                visible: form.calendar !== null
                implicitWidth: calendarRow.implicitWidth + 16
                implicitHeight: 20
                radius: 10
                color: calendarMouse.containsMouse ? form.theme.over(form.theme.hoverFill, form.theme.over(form.theme.faint, form.theme.surface)) : form.theme.faint
                Row {
                    id: calendarRow
                    anchors.centerIn: parent
                    spacing: 5
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: form.calendar ? form.calendar.color : "transparent" }
                    Text {
                        text: form.calendar ? form.calendar.name : ""
                        color: form.theme.text
                        font.pointSize: form.theme.fontSmall * 0.9
                        font.weight: Font.DemiBold
                    }
                }
                MouseArea { id: calendarMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: form.nextCalendar() }
            }
            IconButton {
                iconName: "window-close-symbolic"
                iconSize: 12
                implicitWidth: 20; implicitHeight: 20
                color: form.theme.subText
                hoverColor: form.theme.faint
                onClicked: form.cancelled()
            }
        }

        PillField {
            id: titleField
            theme: form.theme
            Layout.fillWidth: true
            placeholder: Lang.i18n("Title")
            enabled: !form.busy
            onEdited: form.error = ""
            onAccepted: form.submit()
            onEscaped: form.cancelled()
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            PillField {
                id: dateField
                theme: form.theme
                Layout.preferredWidth: 104
                placeholder: Lang.i18n("dd.mm.yyyy")
                enabled: !form.busy
                onEdited: form.error = ""
                onAccepted: form.submit()
                onEscaped: form.cancelled()
            }
            PillButton {
                theme: form.theme
                implicitHeight: 28
                primary: form.allDay
                text: Lang.i18n("All day")
                onClicked: form.allDay = !form.allDay
            }
            PillField {
                id: startField
                theme: form.theme
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                opacity: form.allDay ? 0.35 : 1
                placeholder: "09:00"
                enabled: !form.busy && !form.allDay
                onEdited: form.error = ""
                onAccepted: form.submit()
                onEscaped: form.cancelled()
            }
            Text { text: "–"; color: form.theme.subText; font.pointSize: form.theme.fontSmall; opacity: form.allDay ? 0.35 : 1 }
            PillField {
                id: endField
                theme: form.theme
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                opacity: form.allDay ? 0.35 : 1
                placeholder: "10:00"
                enabled: !form.busy && !form.allDay
                onEdited: form.error = ""
                onAccepted: form.submit()
                onEscaped: form.cancelled()
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            PillField {
                id: placeField
                theme: form.theme
                Layout.fillWidth: true
                placeholder: Lang.i18n("Place or link (optional)")
                enabled: !form.busy
                onEdited: form.error = ""
                onAccepted: form.submit()
                onEscaped: form.cancelled()
            }
            PillButton {
                theme: form.theme
                implicitHeight: 28
                primary: true
                text: form.busy ? Lang.i18n("Adding…") : Lang.i18n("Add")
                enabled: !form.busy
                onClicked: form.submit()
            }
        }
        Item { Layout.fillHeight: true }
    }
}
