/*
    SPDX-License-Identifier: GPL-2.0-or-later
    "Tools": timer (1/5/10/25 min + custom), stopwatch with laps, Pomodoro and
    a simple alarm. All controls are buttons, so the island never needs
    keyboard focus.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "TimeFormat.js" as TimeFormat
import "PomodoroStats.js" as Stats

Item {
    id: tools

    required property Theme theme
    required property var timer
    required property var stopwatch
    required property var pomodoro
    required property var alarm
    property bool active: false

    // Chosen once when the page opens (not a binding: starting/stopping a tool
    // must never switch the section under the user's cursor).
    property int section: -1
    Component.onCompleted: if (section < 0) section = timer.running || timer.paused ? 0 : stopwatch.running ? 1 : pomodoro.running ? 2 : 0
    property int customMinutes: 15
    // Pomodoro statistics: the day they are counted for is taken when the page
    // opens and when a round is counted (a page left open over midnight catches up then).
    property bool pomodoroChart: false
    property var today: new Date()
    onActiveChanged: if (active) today = new Date(); else pomodoroChart = false
    Connections { target: tools.pomodoro; function onStatsChanged() { tools.today = new Date(); } }
    property int alarmHour: Number(String(alarm.alarmTime).split(":")[0]) || 7
    property int alarmMinute: Number(String(alarm.alarmTime).split(":")[1]) || 0

    Binding { target: tools.stopwatch; property: "precise"; value: tools.active && tools.section === 1 }

    component Chip: Rectangle {
        property string text
        property bool current
        property color tint: tools.theme.text
        signal clicked()
        implicitWidth: label.implicitWidth + 18
        implicitHeight: 22
        radius: 11
        color: chipMouse.pressed ? tools.theme.pressedFill : current ? tools.theme.faint : chipMouse.containsMouse ? tools.theme.hoverFill : "transparent"
        scale: chipMouse.pressed ? 0.95 : chipMouse.containsMouse ? 1.05 : 1
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Text {
            id: label
            anchors.centerIn: parent
            text: parent.text
            color: parent.current ? tools.theme.readable(parent.tint, tools.theme.faint) : tools.theme.subText
            font.pointSize: tools.theme.fontSmall
            font.weight: Font.DemiBold
        }
        MouseArea { id: chipMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
    }
    component RoundButton: Rectangle {
        property string text
        property string icon
        property color tint: tools.theme.text
        property color fill: tools.theme.faint
        // Foreground guaranteed ≥ 4.5:1 against this button's own fill.
        readonly property color ink: tools.theme.readable(tint, fill)
        signal clicked()
        implicitWidth: 40
        implicitHeight: 40
        radius: width / 2
        color: rbMouse.pressed ? tools.theme.over(tools.theme.pressedFill, tools.theme.over(fill, tools.theme.surface))
             : rbMouse.containsMouse ? tools.theme.over(tools.theme.hoverFill, tools.theme.over(fill, tools.theme.surface))
             : fill
        border.width: rbMouse.containsMouse ? 1 : 0
        border.color: ink
        opacity: enabled ? 1 : 0.4
        // Hover: grows slightly and fades to the hover fill; press: shrinks.
        scale: rbMouse.pressed ? 0.92 : rbMouse.containsMouse ? 1.08 : 1
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Text {
            anchors.centerIn: parent
            visible: parent.icon.length === 0
            text: parent.text
            color: parent.ink
            font.pointSize: tools.theme.fontSmall
            font.weight: Font.DemiBold
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            visible: parent.icon.length > 0
            width: 16
            height: 16
            source: parent.icon
            color: parent.ink
            isMask: true
        }
        MouseArea { id: rbMouse; anchors.fill: parent; enabled: parent.enabled; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
    }
    component Stepper: RowLayout {
        property int value
        property int from: 0
        property int to: 59
        property int step: 1
        property bool wrap: false
        property string suffix: ""
        signal edited(int value)
        spacing: 2
        RoundButton {
            implicitWidth: 24; implicitHeight: 24; icon: "list-remove-symbolic"
            onClicked: parent.edited(parent.value - parent.step < parent.from ? (parent.wrap ? parent.to : parent.from) : parent.value - parent.step)
        }
        Text {
            Layout.preferredWidth: 34
            horizontalAlignment: Text.AlignHCenter
            text: (parent.value < 10 && parent.suffix === "" ? "0" : "") + parent.value + parent.suffix
            color: tools.theme.text
            font.pointSize: tools.theme.fontTitle
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
        RoundButton {
            implicitWidth: 24; implicitHeight: 24; icon: "list-add-symbolic"
            onClicked: parent.edited(parent.value + parent.step > parent.to ? (parent.wrap ? parent.from : parent.to) : parent.value + parent.step)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        RowLayout {
            spacing: 2
            Chip { text: Lang.i18n("Timer"); current: tools.section === 0; tint: tools.theme.orange; onClicked: tools.section = 0 }
            Chip { text: Lang.i18n("Stopwatch"); current: tools.section === 1; onClicked: tools.section = 1 }
            Chip { text: Lang.i18n("Pomodoro"); current: tools.section === 2; tint: tools.theme.red; onClicked: tools.section = 2 }
            Chip { text: Lang.i18n("Alarm"); current: tools.section === 3; tint: tools.theme.orange; onClicked: tools.section = 3 }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tools.section

            // ---- timer ----
            Item {
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: !tools.timer.running && !tools.timer.paused
                    Repeater {
                        model: [1, 5, 10, 25]
                        delegate: RoundButton {
                            required property int modelData
                            text: Lang.i18nc("@action minutes, short", "%1m", modelData)
                            tint: tools.theme.orange
                            onClicked: tools.timer.start(modelData * 60)
                        }
                    }
                    Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 28; color: tools.theme.track }
                    Stepper {
                        value: tools.customMinutes
                        from: 1; to: 180
                        suffix: "m"
                        onEdited: v => tools.customMinutes = v
                    }
                    RoundButton {
                        icon: "media-playback-start-symbolic"
                        tint: tools.theme.orange
                        onClicked: tools.timer.start(tools.customMinutes * 60)
                    }
                }
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 16
                    visible: tools.timer.running || tools.timer.paused
                    MiniRing {
                        Layout.preferredWidth: 56
                        Layout.preferredHeight: 56
                        lineWidth: 4
                        value: tools.timer.remaining / tools.timer.total
                        color: tools.theme.orange
                        trackColor: tools.theme.track
                        icon: "chronometer"
                    }
                    Text {
                        text: TimeFormat.clock(tools.timer.remaining)
                        color: tools.theme.readable(tools.theme.orange, tools.theme.surface)
                        font.pointSize: tools.theme.fontNormal * 2
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }
                    RoundButton {
                        icon: tools.timer.paused ? "media-playback-start-symbolic" : "media-playback-pause-symbolic"
                        tint: tools.theme.orange
                        onClicked: tools.timer.paused ? tools.timer.resume() : tools.timer.pause()
                    }
                    RoundButton { icon: "dialog-cancel-symbolic"; onClicked: tools.timer.cancel() }
                }
            }

            // ---- stopwatch ----
            RowLayout {
                spacing: 12
                Text {
                    Layout.preferredWidth: 130
                    text: TimeFormat.stopwatch(tools.stopwatch.elapsed)
                    color: tools.theme.text
                    font.pointSize: tools.theme.fontNormal * 1.9
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
                RoundButton {
                    text: tools.stopwatch.running ? Lang.i18n("Lap") : Lang.i18n("Reset")
                    enabled: tools.stopwatch.running || tools.stopwatch.elapsed > 0
                    onClicked: tools.stopwatch.running ? tools.stopwatch.lap() : tools.stopwatch.reset()
                }
                RoundButton {
                    text: tools.stopwatch.running ? Lang.i18n("Stop") : Lang.i18n("Start")
                    tint: tools.stopwatch.running ? tools.theme.red : tools.theme.live
                    fill: Qt.rgba(tint.r, tint.g, tint.b, 0.18)
                    onClicked: tools.stopwatch.running ? tools.stopwatch.stop() : tools.stopwatch.start()
                }
                Column {
                    Layout.fillWidth: true
                    spacing: 1
                    Repeater {
                        model: tools.stopwatch.laps.slice(0, 4)
                        delegate: Text {
                            required property int index
                            required property var modelData
                            text: Lang.i18nc("@info lap number and time", "Lap %1  %2", tools.stopwatch.laps.length - index, TimeFormat.stopwatch(modelData))
                            color: tools.theme.subText
                            font.pointSize: tools.theme.fontSmall
                            font.features: { "tnum": 1 }
                        }
                    }
                }
            }

            // ---- pomodoro ----
            // The clock and, under it, the statistics in one line; a click on that
            // line turns the section into the last seven days as bars, and back.
            Item {
                ColumnLayout {
                    anchors.fill: parent
                    visible: !tools.pomodoroChart
                    spacing: 2
                    Item { Layout.fillHeight: true }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        MiniRing {
                            Layout.preferredWidth: 56
                            Layout.preferredHeight: 56
                            lineWidth: 4
                            readonly property real phaseSeconds: (tools.pomodoro.phase === "work" ? tools.pomodoro.cfg.pomodoroWork
                                                                  : tools.pomodoro.phase === "long" ? tools.pomodoro.cfg.pomodoroLongBreak
                                                                  : tools.pomodoro.cfg.pomodoroShortBreak) * 60
                            value: tools.pomodoro.running ? 1 - tools.pomodoro.remaining / phaseSeconds : 0
                            color: tools.pomodoro.phase === "work" || !tools.pomodoro.running ? tools.theme.red : tools.theme.live
                            trackColor: tools.theme.track
                            icon: tools.pomodoro.phase === "work" || !tools.pomodoro.running ? "view-task" : "kteatime"
                        }
                        ColumnLayout {
                            spacing: 0
                            Text {
                                text: tools.pomodoro.running ? tools.pomodoro.phaseName(tools.pomodoro.phase) : Lang.i18n("Pomodoro")
                                color: tools.theme.subText
                                font.pointSize: tools.theme.fontSmall
                            }
                            Text {
                                text: TimeFormat.clock(tools.pomodoro.remaining)
                                color: tools.theme.text
                                font.pointSize: tools.theme.fontNormal * 1.7
                                font.weight: Font.DemiBold
                                font.features: { "tnum": 1 }
                            }
                            Row {
                                spacing: 4
                                Repeater {
                                    model: tools.pomodoro.rounds
                                    delegate: Rectangle {
                                        required property int index
                                        width: 7; height: 7; radius: 3.5
                                        color: index < tools.pomodoro.round ? tools.theme.red : tools.theme.track
                                    }
                                }
                            }
                        }
                        Item { Layout.fillWidth: true }
                        RoundButton {
                            visible: tools.pomodoro.running
                            icon: "media-skip-forward-symbolic"
                            onClicked: tools.pomodoro.skip()
                        }
                        RoundButton {
                            icon: tools.pomodoro.running ? "media-playback-stop-symbolic" : "media-playback-start-symbolic"
                            tint: tools.theme.red
                            fill: Qt.rgba(tint.r, tint.g, tint.b, 0.18)
                            onClicked: tools.pomodoro.running ? tools.pomodoro.stop() : tools.pomodoro.start()
                        }
                    }
                    Item { Layout.fillHeight: true }
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: Lang.i18n("Today: %1 · This week: %2 · Streak: %3", Stats.count(tools.pomodoro.stats, tools.today),
                                        Stats.week(tools.pomodoro.stats, tools.today), Lang.i18np("%1 day", "%1 days", Stats.streak(tools.pomodoro.stats, tools.today)))
                        color: statsMouse.containsMouse ? tools.theme.text : tools.theme.subText
                        font.pointSize: tools.theme.fontSmall * 0.9
                        font.features: { "tnum": 1 }
                        elide: Text.ElideRight
                        MouseArea { id: statsMouse; anchors.fill: parent; anchors.margins: -3; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tools.pomodoroChart = true }
                    }
                }
                // The last seven days
                ColumnLayout {
                    anchors.fill: parent
                    visible: tools.pomodoroChart
                    spacing: 3
                    RowLayout {
                        id: bars
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 6
                        readonly property var week: Stats.lastSeven(tools.pomodoro.stats, tools.today)
                        readonly property int peak: Math.max(1, ...week.map(d => d.count))
                        Repeater {
                            model: bars.week
                            delegate: ColumnLayout {
                                id: bar
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredWidth: 10
                                spacing: 1
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: bar.modelData.count
                                    color: bar.modelData.count > 0 ? tools.theme.text : tools.theme.subText
                                    font.pointSize: tools.theme.fontSmall * 0.85
                                    font.features: { "tnum": 1 }
                                }
                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: Math.min(22, parent.width)
                                        height: Math.max(3, parent.height * bar.modelData.count / bars.peak)
                                        radius: 3
                                        // today stands out
                                        color: bar.modelData.count === 0 ? tools.theme.track : bar.index === 6 ? tools.theme.red : Qt.rgba(tools.theme.red.r, tools.theme.red.g, tools.theme.red.b, 0.55)
                                    }
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: bar.modelData.date.toLocaleDateString(Lang.locale, "ddd")
                                    color: bar.index === 6 ? tools.theme.text : tools.theme.subText
                                    font.pointSize: tools.theme.fontSmall * 0.85
                                }
                            }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: Lang.i18n("Total: %1 · Longest streak: %2", tools.pomodoro.stats.total, Lang.i18np("%1 day", "%1 days", Stats.bestStreak(tools.pomodoro.stats, tools.today)))
                        color: tools.theme.subText
                        font.pointSize: tools.theme.fontSmall * 0.9
                        font.features: { "tnum": 1 }
                    }
                }
                MouseArea { anchors.fill: parent; visible: tools.pomodoroChart; cursorShape: Qt.PointingHandCursor; onClicked: tools.pomodoroChart = false }
            }

            // ---- alarm ----
            RowLayout {
                spacing: 10
                Kirigami.Icon {
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    source: "alarm-symbolic"
                    color: tools.alarm.armed ? tools.theme.orange : tools.theme.subText
                    isMask: true
                }
                Stepper {
                    value: tools.alarmHour
                    from: 0; to: 23; wrap: true
                    onEdited: v => tools.alarmHour = v
                }
                Text { text: ":"; color: tools.theme.text; font.pointSize: tools.theme.fontTitle; font.weight: Font.DemiBold }
                Stepper {
                    value: tools.alarmMinute
                    from: 0; to: 55; step: 5; wrap: true
                    onEdited: v => tools.alarmMinute = v
                }
                Item { Layout.fillWidth: true }
                ColumnLayout {
                    spacing: 2
                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: tools.alarm.armed ? Lang.i18n("Rings at %1", tools.alarm.alarmTime) : Lang.i18n("Off")
                        color: tools.alarm.armed ? tools.theme.readable(tools.theme.orange, tools.theme.surface) : tools.theme.subText
                        font.pointSize: tools.theme.fontSmall
                    }
                    RoundButton {
                        Layout.alignment: Qt.AlignRight
                        implicitWidth: 64
                        implicitHeight: 28
                        radius: 14
                        text: tools.alarm.armed ? Lang.i18n("Clear") : Lang.i18n("Set")
                        tint: tools.alarm.armed ? tools.theme.text : tools.theme.orange
                        onClicked: {
                            const two = n => (n < 10 ? "0" : "") + n;
                            tools.alarm.armed ? tools.alarm.clear() : tools.alarm.set(two(tools.alarmHour) + ":" + two(tools.alarmMinute));
                        }
                    }
                }
            }
        }
    }
}
