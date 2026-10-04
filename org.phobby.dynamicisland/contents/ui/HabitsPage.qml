/*
    SPDX-License-Identifier: GPL-2.0-or-later

    "Habits": today's checklist beside a calendar of the last weeks in the
    manner of GitHub's contribution graph (columns are weeks, rows the days of
    the week, today at the far right, five shades). A click on a day opens it
    for correcting; "All year" shows the last 53 weeks in a wider island.

    The first-run questions and the evening review take the page over while
    they last. The record and the rules are providers/HabitsProvider.qml and
    Habits.js; this page only shows them, and reads no clock: "today" is the
    provider's.

    The island has no tooltips: what a hovered day or button means is written
    into the page (the calendar's caption, the header's hint).
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "Habits.js" as Habits

Item {
    id: page

    required property Theme theme
    required property var habits            // providers/HabitsProvider.qml
    // The calendar in the system's accent colour instead of GitHub's greens.
    property bool accentColors: false

    readonly property var record: habits.record
    // "today" | "year" | "day" (one day, opened from a calendar)
    property string view: "today"
    readonly property string mode: !record.setup ? "setup" : habits.reviewDay !== "" ? "review" : view
    property string shownDay: ""
    property bool fromYear: false
    property int setupStep: 0               // 0 the habits, 1 the review time
    property int setupHour: Math.floor(Habits.minutesOf(habits.reviewTime) / 60)
    property int setupMinute: Habits.minutesOf(habits.reviewTime) % 60
    property bool adding: false             // the field for a new habit is shown
    property int confirmDelete: -1          // the habit asked about: delete for good?
    property string hint: ""
    property string notice: ""

    // A text field has the keyboard: the island stays open and focused.
    property bool typing: false
    readonly property bool interacting: visible && typing
    // The year needs the wider island; a day opened from it keeps it.
    readonly property bool wide: visible && record.setup === 1 && (view === "year" || view === "day" && fromYear)
    // The page's width in the island's usual size: all but the year's calendar
    // stays within it, so nothing moves from under the pointer when the island narrows.
    readonly property real usual: Math.min(width, theme.expandedWidth - 2 * theme.padding)

    onVisibleChanged: if (!visible) { typing = false; adding = false; confirmDelete = -1; hint = ""; }
    onModeChanged: { typing = false; adding = false; confirmDelete = -1; hint = ""; }
    Timer { id: confirmTimer; interval: 5000; onTriggered: page.confirmDelete = -1 }
    onConfirmDeleteChanged: if (confirmDelete >= 0) confirmTimer.restart()
    Timer { id: noticeTimer; interval: 6000; onTriggered: page.notice = "" }
    function say(text: string): void { notice = text; noticeTimer.restart(); }
    function grab(field: var): void { typing = true; Qt.callLater(() => field.input.forceActiveFocus()); }

    function openDay(key: string, fromYear: bool): void {
        shownDay = key;
        page.fromYear = fromYear;
        view = "day";
    }
    // "12 October · 3/5"
    function caption(key: string): string {
        const c = Habits.cell(record, key), date = Habits.dateOf(key).toLocaleDateString(Lang.locale, "d MMMM");
        if (!c.listed) return date + " · " + Lang.i18n("no record");
        return date + " · " + c.done + "/" + c.total + (c.known ? "" : " · " + Lang.i18n("not reviewed"));
    }
    function two(n: int): string { return (n < 10 ? "0" : "") + n; }

    // The five shades: GitHub's (for a dark or a light surface), or the system's accent colour thinned out.
    readonly property color tone: habits.tone
    readonly property var shades: accentColors
        ? [theme.faint, theme.mix(theme.surface, tone, 0.3), theme.mix(theme.surface, tone, 0.52), theme.mix(theme.surface, tone, 0.76), tone]
        : theme.dark ? [theme.faint, "#0e4429", "#006d32", "#26a641", "#39d353"] : [theme.faint, "#9be9a8", "#40c463", "#30a14e", "#216e39"]
    readonly property color toneText: theme.readable(tone, theme.surface)

    // ---- pieces ---------------------------------------------------------------------
    component Tick: Rectangle {
        property bool on: false
        implicitWidth: 14
        implicitHeight: 14
        radius: 4
        color: on ? page.tone : "transparent"
        border.width: on ? 0 : 1.5
        border.color: page.theme.subText
        Kirigami.Icon {
            anchors.centerIn: parent
            width: 10
            height: 10
            visible: parent.on
            source: "checkmark-symbolic"
            color: page.theme.onColor(page.tone)
            isMask: true
        }
    }

    component SmallButton: IconButton {
        property string hint
        iconSize: 12
        implicitWidth: 20
        implicitHeight: 20
        color: page.theme.subText
        hoverColor: page.theme.faint
        HoverHandler { onHoveredChanged: page.hint = hovered ? parent.hint : "" }
    }

    // The first click asks the island for the keyboard; Enter hands the name on and keeps the field.
    component NameField: PillField {
        id: nameField
        signal submitted(string name)
        function submit(): void {
            const name = text.trim();
            text = "";
            if (name.length > 0) submitted(name);
        }
        theme: page.theme
        implicitHeight: 24
        onAccepted: submit()
        onEscaped: { text = ""; page.typing = false; }
        MouseArea {
            anchors.fill: parent
            visible: !page.typing
            cursorShape: Qt.IBeamCursor
            onClicked: page.grab(nameField)
        }
    }

    component Chip: Rectangle {
        id: chip
        property string text
        signal removed()
        implicitWidth: chipLabel.width + 30
        implicitHeight: 20
        radius: 10
        color: page.theme.faint
        Text {
            id: chipLabel
            x: 9
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 170)
            text: chip.text
            color: page.theme.text
            font.pointSize: page.theme.fontSmall * 0.9
            elide: Text.ElideRight
        }
        IconButton {
            anchors.right: parent.right
            anchors.rightMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            iconName: "window-close-symbolic"
            iconSize: 8
            implicitWidth: 16; implicitHeight: 16
            color: page.theme.subText
            hoverColor: page.theme.faint
            onClicked: chip.removed()
        }
    }

    component Stepper: RowLayout {
        id: stepper
        property int value
        property int to: 59
        property int step: 1
        signal edited(int value)
        spacing: 2
        SmallButton { iconName: "go-down-symbolic"; color: page.theme.text; onClicked: stepper.edited(stepper.value - stepper.step < 0 ? stepper.to : stepper.value - stepper.step) }
        Text {
            Layout.preferredWidth: 30
            horizontalAlignment: Text.AlignHCenter
            text: page.two(stepper.value)
            color: page.theme.text
            font.pointSize: page.theme.fontTitle * 1.3
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
        SmallButton { iconName: "go-up-symbolic"; color: page.theme.text; onClicked: stepper.edited(stepper.value + stepper.step > stepper.to ? 0 : stepper.value + stepper.step) }
    }

    // One of the five shades, for the legend.
    component Shade: Rectangle {
        property int level: 0
        width: 9
        height: 9
        radius: 2
        color: page.shades[level]
    }
    component Legend: Row {
        spacing: 2
        Repeater {
            model: 5
            delegate: Shade { required property int index; level: index }
        }
    }

    // The list of a day: a click ticks an entry; under the pointer it can be
    // taken off that day's list or (today's list) the habit deleted for good.
    component Checklist: GridView {
        id: checklist
        property string day: ""
        property int columns: 2
        property bool deletable: false
        readonly property var entries: Habits.items(page.record, day)
        readonly property string dropHint: day === page.habits.today ? Lang.i18n("Off today's list only") : Lang.i18n("Off this day's list")
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        cellWidth: Math.floor(width / columns)
        cellHeight: 22
        // by number, so that ticking an entry does not rebuild the list (and lose its scroll position)
        model: entries.length
        onCountChanged: page.hint = ""
        // there is more than fits: where the list is
        Rectangle {
            parent: checklist
            visible: checklist.contentHeight > checklist.height + 1
            anchors.right: parent.right
            y: checklist.visibleArea.yPosition * checklist.height
            width: 2
            height: Math.max(8, checklist.visibleArea.heightRatio * checklist.height)
            radius: 1
            color: page.theme.track
        }

        delegate: Item {
            id: slot
            required property int index
            readonly property var entry: checklist.entries[index] ?? null
            readonly property int habitId: entry !== null && !entry.extra ? Number(entry.ref.slice(1)) : -1
            readonly property bool asking: checklist.deletable && habitId >= 0 && page.confirmDelete === habitId
            readonly property bool hovered: rowMouse.containsMouse || rowButtons.hovered
            width: checklist.cellWidth
            height: checklist.cellHeight

            Rectangle {
                anchors.fill: parent
                anchors.rightMargin: checklist.columns > 1 ? 4 : 0
                anchors.bottomMargin: 1
                radius: 7
                color: slot.asking ? page.theme.faint : rowMouse.pressed ? page.theme.pressedFill : slot.hovered ? page.theme.hoverFill : "transparent"

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: slot.asking ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: if (!slot.asking && slot.entry !== null) page.habits.setDone(checklist.day, slot.entry.ref, !slot.entry.done)
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 1
                    spacing: 6
                    visible: !slot.asking
                    Tick { on: slot.entry !== null && slot.entry.done }
                    Text {
                        Layout.fillWidth: true
                        text: slot.entry !== null ? slot.entry.name : ""
                        color: slot.entry !== null && slot.entry.done ? page.theme.subText : page.theme.text
                        font.pointSize: page.theme.fontSmall
                        elide: Text.ElideRight
                    }
                    // a one-time extra
                    Text {
                        visible: slot.entry !== null && slot.entry.extra && !slot.hovered
                        text: Lang.i18nc("@info a one-time item on the day's list", "once")
                        color: page.theme.subText
                        font.pointSize: page.theme.fontSmall * 0.8
                    }
                    Row {
                        visible: slot.hovered
                        HoverHandler { id: rowButtons }
                        SmallButton {
                            iconName: "dialog-cancel-symbolic"
                            hint: checklist.dropHint
                            onClicked: page.habits.dropFromDay(checklist.day, slot.entry.ref)
                        }
                        SmallButton {
                            visible: checklist.deletable && slot.habitId >= 0
                            iconName: "edit-delete-symbolic"
                            hint: Lang.i18n("Delete the habit for good")
                            onClicked: page.confirmDelete = slot.habitId
                        }
                    }
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 1
                    spacing: 3
                    visible: slot.asking
                    Text {
                        Layout.fillWidth: true
                        text: Lang.i18n("Delete for good?")
                        color: page.theme.text
                        font.pointSize: page.theme.fontSmall
                        elide: Text.ElideRight
                    }
                    PillButton {
                        theme: page.theme
                        implicitHeight: 18
                        primary: true
                        tint: page.theme.danger
                        text: Lang.i18n("Delete")
                        onClicked: { page.confirmDelete = -1; page.habits.deleteHabit(slot.habitId); }
                    }
                    PillButton {
                        theme: page.theme
                        implicitHeight: 18
                        text: Lang.i18n("Cancel")
                        onClicked: page.confirmDelete = -1
                    }
                }
            }
        }
    }

    // GitHub-style calendar: a column per week (Habits.weeks), Monday at the top.
    // A day that was not reviewed is an empty outlined box, not the shade of "nothing done".
    component Calendar: Item {
        id: calendar
        property var weeks: []
        property real cell: 9
        property real gap: 2
        property bool dayNames: false
        property string hoveredKey: ""
        signal picked(string key)
        readonly property real pitch: cell + gap
        readonly property real namesWidth: dayNames ? 26 : 0
        readonly property real monthsHeight: 12
        implicitWidth: namesWidth + weeks.length * pitch - gap
        implicitHeight: monthsHeight + 7 * pitch - gap

        // Monday, Wednesday, Friday
        Repeater {
            model: calendar.dayNames ? [1, 3, 5] : []
            delegate: Text {
                required property int modelData
                y: calendar.monthsHeight + (modelData - 1) * calendar.pitch + (calendar.cell - height) / 2
                text: Lang.locale.dayName(modelData, Locale.ShortFormat)
                color: page.theme.subText
                font.pointSize: page.theme.fontSmall * 0.75
            }
        }
        Repeater {
            model: calendar.weeks.length
            delegate: Item {
                id: week
                required property int index
                readonly property var days: calendar.weeks[index] ?? []
                // the month's name over the week its first day is in
                readonly property var first: days.find(d => d !== null && d.date.getDate() === 1) ?? null
                x: calendar.namesWidth + index * calendar.pitch
                Text {
                    visible: week.first !== null && week.index < calendar.weeks.length - 2
                    text: week.first !== null ? week.first.date.toLocaleDateString(Lang.locale, "MMM") : ""
                    color: page.theme.subText
                    font.pointSize: page.theme.fontSmall * 0.75
                }
                Repeater {
                    model: 7
                    delegate: Rectangle {
                        required property int index
                        readonly property var day: week.days[index] ?? null
                        readonly property bool today: day !== null && day.key === page.habits.today
                        readonly property bool hovered: day !== null && day.key === calendar.hoveredKey
                        visible: day !== null
                        y: calendar.monthsHeight + index * calendar.pitch
                        width: calendar.cell
                        height: calendar.cell
                        radius: Math.max(1.5, calendar.cell / 4.5)
                        color: day !== null && day.known ? page.shades[day.level] : "transparent"
                        border.width: day !== null && (today || hovered || !day.known) ? 1 : 0
                        border.color: today || hovered ? page.theme.text
                                    : Qt.rgba(page.theme.text.r, page.theme.text.g, page.theme.text.b, day !== null && day.listed ? 0.42 : 0.13)
                    }
                }
            }
        }
        MouseArea {
            x: calendar.namesWidth
            y: calendar.monthsHeight
            width: calendar.weeks.length * calendar.pitch
            height: 7 * calendar.pitch
            hoverEnabled: true
            cursorShape: calendar.hoveredKey !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
            function keyAt(x: real, y: real): string {
                const week = calendar.weeks[Math.floor(x / calendar.pitch)];
                const day = week ? week[Math.floor(y / calendar.pitch)] : null;
                return day ? day.key : "";
            }
            onPositionChanged: mouse => calendar.hoveredKey = keyAt(mouse.x, mouse.y)
            onExited: calendar.hoveredKey = ""
            onClicked: mouse => { const key = keyAt(mouse.x, mouse.y); if (key !== "") calendar.picked(key); }
        }
    }

    Item {
        id: block
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: page.usual
    }

    // ---- the first time: the habits, then the review time ----------------------------------
    Item {
        anchors.fill: block
        visible: page.mode === "setup"

        ColumnLayout {
            anchors.fill: parent
            visible: page.setupStep === 0
            spacing: 5
            Text {
                Layout.fillWidth: true
                text: Lang.i18n("Write down the habits you want to build.")
                color: page.theme.text
                font.pointSize: page.theme.fontSmall
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                NameField {
                    id: firstField
                    Layout.fillWidth: true
                    placeholder: Lang.i18n("New habit, every day…")
                    onSubmitted: name => page.habits.addHabit(name)
                }
                PillButton {
                    theme: page.theme
                    implicitHeight: 24
                    text: Lang.i18n("Add")
                    enabled: firstField.text.trim().length > 0
                    onClicked: firstField.submit()
                }
            }
            Flickable {
                id: firstScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: firstHabits.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                Flow {
                    id: firstHabits
                    width: firstScroll.width
                    spacing: 4
                    Repeater {
                        model: Habits.active(page.record)
                        delegate: Chip {
                            required property var modelData
                            text: modelData.name
                            onRemoved: page.habits.deleteHabit(modelData.id)
                        }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: Lang.i18n("They stay on every day's list until you delete them.")
                    color: page.theme.subText
                    font.pointSize: page.theme.fontSmall * 0.9
                    elide: Text.ElideRight
                }
                PillButton {
                    theme: page.theme
                    implicitHeight: 22
                    primary: true
                    tint: page.tone
                    enabled: Habits.active(page.record).length > 0
                    text: Lang.i18n("Continue")
                    onClicked: page.setupStep = 1
                }
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width
            visible: page.setupStep === 1
            spacing: 5
            onVisibleChanged: if (visible) page.typing = false
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: Lang.i18n("When shall I ask how the day went?")
                color: page.theme.text
                font.pointSize: page.theme.fontSmall
                font.weight: Font.DemiBold
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 4
                Stepper { value: page.setupHour; to: 23; onEdited: v => page.setupHour = v }
                Text { text: ":"; color: page.theme.text; font.pointSize: page.theme.fontTitle * 1.3; font.weight: Font.DemiBold }
                Stepper { value: page.setupMinute; to: 55; step: 5; onEdited: v => page.setupMinute = v }
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: Lang.i18n("The evening review; the time can be changed in the settings.")
                color: page.theme.subText
                font.pointSize: page.theme.fontSmall * 0.9
                elide: Text.ElideRight
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 6
                PillButton {
                    theme: page.theme
                    implicitHeight: 22
                    text: Lang.i18n("Back")
                    onClicked: page.setupStep = 0
                }
                PillButton {
                    theme: page.theme
                    implicitHeight: 22
                    primary: true
                    tint: page.tone
                    text: Lang.i18nc("@action:button the last of the questions is answered", "Finish")
                    onClicked: { page.habits.finishSetup(page.two(page.setupHour) + ":" + page.two(page.setupMinute)); page.setupStep = 0; }
                }
            }
        }
    }

    // ---- today: the list, and the last weeks ---------------------------------------------
    RowLayout {
        anchors.fill: block
        visible: page.mode === "today"
        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                visible: !page.adding
                spacing: 6
                Text {
                    text: Lang.i18n("Today")
                    color: page.theme.text
                    font.pointSize: page.theme.fontSmall
                    font.weight: Font.DemiBold
                }
                Text {
                    readonly property var counts: Habits.counts(page.record, page.habits.today)
                    visible: counts.total > 0
                    text: counts.done + "/" + counts.total
                    color: page.toneText
                    font.pointSize: page.theme.fontSmall
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: page.hint
                    color: page.theme.subText
                    font.pointSize: page.theme.fontSmall * 0.9
                    elide: Text.ElideRight
                }
                // an evening review is waiting
                PillButton {
                    visible: page.habits.pending !== "" && page.hint === ""
                    theme: page.theme
                    implicitHeight: 20
                    primary: true
                    tint: page.tone
                    text: page.habits.pending === page.habits.today ? Lang.i18nc("@action:button start the evening review of the habits", "Review")
                                                                    : Lang.i18n("Review yesterday")
                    onClicked: page.habits.startReview(page.habits.pending)
                }
                SmallButton {
                    iconName: "list-add-symbolic"
                    color: page.theme.text
                    hint: Lang.i18n("New habit")
                    onClicked: { page.hint = ""; page.adding = true; page.grab(newField); }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                visible: page.adding
                spacing: 2
                NameField {
                    id: newField
                    Layout.fillWidth: true
                    placeholder: Lang.i18n("New habit, every day…")
                    onSubmitted: name => page.habits.addHabit(name)
                    onEscaped: page.adding = false
                }
                SmallButton {
                    iconName: "window-close-symbolic"
                    onClicked: { page.adding = false; page.typing = false; }
                }
            }
            Checklist {
                id: todayList
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: count > 0
                day: page.habits.today
                columns: 1
                deletable: true
            }
            Text {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: todayList.count === 0
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.Wrap
                text: Lang.i18n("Nothing on today's list.")
                color: page.theme.subText
                font.pointSize: page.theme.fontSmall
            }
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: recent.implicitWidth
            Layout.maximumWidth: recent.implicitWidth
            spacing: 5
            // as many weeks as fit two fifths of the page
            Calendar {
                id: recent
                weeks: page.mode === "today" ? Habits.weeks(page.record, page.habits.moment, Math.max(6, Math.floor((page.usual * 0.41 + gap) / pitch))) : []
                onPicked: key => page.openDay(key, false)
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 20
                spacing: 4
                Legend { visible: recent.hoveredKey === "" }
                Text {
                    Layout.fillWidth: true
                    text: recent.hoveredKey !== "" ? page.caption(recent.hoveredKey) : ""
                    color: page.theme.text
                    font.pointSize: page.theme.fontSmall * 0.85
                    font.features: { "tnum": 1 }
                    elide: Text.ElideRight
                }
                PillButton {
                    visible: recent.hoveredKey === ""
                    theme: page.theme
                    implicitHeight: 20
                    text: Lang.i18n("All year")
                    onClicked: page.view = "year"
                }
            }
        }
    }

    // ---- the last 365 days ---------------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        visible: page.mode === "year"
        spacing: 3

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: page.usual
            Layout.maximumWidth: page.usual
            Layout.preferredHeight: 22
            spacing: 6
            SmallButton {
                iconName: "go-previous-symbolic"
                color: page.theme.text
                onClicked: page.view = "today"
            }
            Text {
                text: Lang.i18n("Last 365 days")
                color: page.theme.text
                font.pointSize: page.theme.fontSmall
                font.weight: Font.DemiBold
            }
            Text {
                readonly property var summary: page.mode === "year" ? Habits.summary(page.record, page.habits.moment, 365) : { days: 0, average: 0 }
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: year.hoveredKey !== "" ? page.caption(year.hoveredKey)
                    : summary.days > 0 ? Lang.i18np("%1 day recorded · %2 on average", "%1 days recorded · %2 on average", summary.days, Lang.percent(Math.round(summary.average * 100)))
                    : ""
                color: year.hoveredKey !== "" ? page.theme.text : page.theme.subText
                font.pointSize: page.theme.fontSmall * 0.9
                font.features: { "tnum": 1 }
                elide: Text.ElideRight
            }
        }
        Calendar {
            id: year
            Layout.alignment: Qt.AlignHCenter
            weeks: page.mode === "year" ? Habits.weeks(page.record, page.habits.moment, 53) : []
            dayNames: true
            // as large as 53 weeks fit the page
            cell: Math.max(4, Math.min(9, Math.floor((page.width - namesWidth + gap) / 53) - gap))
            onPicked: key => page.openDay(key, true)
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 5
            Text { text: Lang.i18nc("@label the low end of the calendar's shades", "Less"); color: page.theme.subText; font.pointSize: page.theme.fontSmall * 0.8 }
            Legend {}
            Text { text: Lang.i18nc("@label the high end of the calendar's shades", "More"); color: page.theme.subText; font.pointSize: page.theme.fontSmall * 0.8 }
            Item { Layout.preferredWidth: 8 }
            Rectangle {
                implicitWidth: 9; implicitHeight: 9; radius: 2
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(page.theme.text.r, page.theme.text.g, page.theme.text.b, 0.42)
            }
            Text { text: Lang.i18n("not reviewed"); color: page.theme.subText; font.pointSize: page.theme.fontSmall * 0.8 }
        }
        Item { Layout.fillHeight: true }
    }

    // ---- one day, opened from a calendar: what was done, to be corrected ---------------------
    ColumnLayout {
        anchors.fill: block
        visible: page.mode === "day"
        spacing: 2

        RowLayout {
            id: dayHeader
            readonly property var cell: Habits.cell(page.record, page.shownDay)
            readonly property bool waiting: page.shownDay !== "" && page.shownDay === page.habits.pending
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            spacing: 6
            SmallButton {
                iconName: "go-previous-symbolic"
                color: page.theme.text
                onClicked: page.view = page.fromYear ? "year" : "today"
            }
            Text {
                text: page.shownDay === "" ? "" : Habits.dateOf(page.shownDay).toLocaleDateString(Lang.locale, "d MMMM dddd")
                color: page.theme.text
                font.pointSize: page.theme.fontSmall
                font.weight: Font.DemiBold
            }
            Text {
                visible: dayHeader.cell.listed
                text: dayHeader.cell.done + "/" + dayHeader.cell.total
                color: page.toneText
                font.pointSize: page.theme.fontSmall
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: page.hint !== "" ? page.hint
                    : dayHeader.cell.listed && !dayHeader.cell.reviewed && page.shownDay < page.habits.today ? Lang.i18n("not reviewed") : ""
                color: page.theme.subText
                font.pointSize: page.theme.fontSmall * 0.9
                elide: Text.ElideRight
            }
            // the day whose review is waiting is asked in full; an earlier one is simply marked
            PillButton {
                visible: dayHeader.waiting && page.hint === ""
                theme: page.theme
                implicitHeight: 20
                primary: true
                tint: page.tone
                text: Lang.i18nc("@action:button start the evening review of the habits", "Review")
                onClicked: page.habits.startReview(page.shownDay)
            }
            PillButton {
                visible: !dayHeader.waiting && dayHeader.cell.listed && !dayHeader.cell.reviewed && page.shownDay < page.habits.today && page.hint === ""
                theme: page.theme
                implicitHeight: 20
                text: Lang.i18n("Mark as reviewed")
                onClicked: page.habits.markReviewed(page.shownDay)
            }
        }
        Checklist {
            id: dayList
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: count > 0
            day: page.mode === "day" ? page.shownDay : ""
        }
        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: dayList.count === 0
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: Lang.i18n("No list was made for this day.")
            color: page.theme.subText
            font.pointSize: page.theme.fontSmall
        }
    }

    // ---- the evening review: the day's list, its extras one by one, extras for the day after ----
    Item {
        id: reviewView
        anchors.fill: block
        visible: page.mode === "review"
        readonly property int step: page.habits.reviewStep
        // the extras the evening has not asked about yet; the first is the one in question
        readonly property var open: visible ? Habits.unasked(page.record, page.habits.reviewDay) : []
        // a late review plans for the day it is asked on
        readonly property bool forToday: page.habits.reviewTarget <= page.habits.today
        readonly property var planned: visible ? Habits.extrasOf(page.record, page.habits.reviewTarget) : []

        function answer(again: bool): void {
            if (open.length === 0) { page.habits.continueReview(); return; }
            const name = open[0].name;
            if (page.habits.answerExtra(open[0].index, again)) page.say(Lang.i18n("'%1' is a permanent habit now.", name));
        }
        function plan(name: string): void {
            if (page.habits.addExtra(name)) page.say(Lang.i18n("'%1' is a permanent habit now.", name));
        }

        ColumnLayout {
            anchors.fill: parent
            visible: reviewView.step === 1
            spacing: 2
            RowLayout {
                readonly property var counts: Habits.counts(page.record, page.habits.reviewDay)
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                spacing: 6
                Text {
                    text: page.habits.question(page.habits.reviewDay)
                    color: page.theme.text
                    font.pointSize: page.theme.fontSmall
                    font.weight: Font.DemiBold
                }
                Text {
                    text: Lang.i18n("%1/%2 checked", parent.counts.done, parent.counts.total)
                    color: page.toneText
                    font.pointSize: page.theme.fontSmall
                    font.features: { "tnum": 1 }
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: page.hint
                    color: page.theme.subText
                    font.pointSize: page.theme.fontSmall * 0.9
                    elide: Text.ElideRight
                }
                PillButton {
                    theme: page.theme
                    implicitHeight: 20
                    primary: true
                    tint: page.tone
                    text: Lang.i18n("Continue")
                    onClicked: page.habits.continueReview()
                }
                SmallButton {
                    iconName: "window-close-symbolic"
                    hint: Lang.i18n("Later")
                    onClicked: page.habits.leaveReview()
                }
            }
            Checklist {
                Layout.fillWidth: true
                Layout.fillHeight: true
                day: reviewView.visible ? page.habits.reviewDay : ""
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 24
            visible: reviewView.step === 2
            spacing: 8
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: reviewView.open.length === 0 ? ""
                    : reviewView.forToday ? Lang.i18n("Shall I add '%1' for today as well?", reviewView.open[0].name)
                                          : Lang.i18n("Shall I add '%1' for tomorrow as well?", reviewView.open[0].name)
                color: page.theme.text
                font.pointSize: page.theme.fontSmall
                font.weight: Font.DemiBold
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8
                PillButton {
                    theme: page.theme
                    primary: true
                    tint: page.tone
                    text: Lang.i18n("Yes")
                    onClicked: reviewView.answer(true)
                }
                PillButton {
                    theme: page.theme
                    text: Lang.i18n("No")
                    onClicked: reviewView.answer(false)
                }
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: page.notice !== "" ? page.notice : Lang.i18n("Yes makes it a habit of every day; no lets it go.")
                color: page.notice !== "" ? page.toneText : page.theme.subText
                font.pointSize: page.theme.fontSmall * 0.9
                elide: Text.ElideRight
            }
        }

        ColumnLayout {
            anchors.fill: parent
            visible: reviewView.step === 3
            spacing: 5
            Text {
                Layout.fillWidth: true
                text: reviewView.forToday ? Lang.i18n("Is there an extra activity you want to add for today?")
                                          : Lang.i18n("Is there an extra activity you want to add for tomorrow?")
                color: page.theme.text
                font.pointSize: page.theme.fontSmall
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                NameField {
                    id: extraField
                    Layout.fillWidth: true
                    placeholder: Lang.i18n("Extra activity…")
                    onSubmitted: name => reviewView.plan(name)
                }
                PillButton {
                    theme: page.theme
                    implicitHeight: 24
                    text: Lang.i18n("Add")
                    enabled: extraField.text.trim().length > 0
                    onClicked: extraField.submit()
                }
            }
            Flickable {
                id: plannedScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: plannedFlow.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                Flow {
                    id: plannedFlow
                    width: plannedScroll.width
                    spacing: 4
                    Repeater {
                        model: reviewView.planned
                        delegate: Chip {
                            required property string modelData
                            text: modelData
                            onRemoved: page.habits.dropExtra(modelData)
                        }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    Layout.fillWidth: true
                    text: page.notice !== "" ? page.notice : Lang.i18n("Only for that day; added two days in a row it becomes a habit.")
                    color: page.notice !== "" ? page.toneText : page.theme.subText
                    font.pointSize: page.theme.fontSmall * 0.9
                    elide: Text.ElideRight
                }
                PillButton {
                    theme: page.theme
                    implicitHeight: 22
                    primary: true
                    tint: page.tone
                    text: reviewView.planned.length > 0 || page.notice !== "" ? Lang.i18nc("@action:button the last of the questions is answered", "Finish")
                                                                              : Lang.i18nc("@action:button there is nothing to add", "None")
                    onClicked: { page.notice = ""; page.habits.finishReview(); }
                }
            }
        }
    }
}
