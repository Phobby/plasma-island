/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Minute-aligned clock: wakes up once per minute, only while running.
*/
import QtQuick

Text {
    id: clock

    property bool running: true
    property date now: new Date()

    text: Qt.formatTime(now, Lang.locale.timeFormat(Locale.ShortFormat))
    font.features: { "tnum": 1 }

    function tick(): void {
        now = new Date();
        timer.interval = 60000 - (now.getSeconds() * 1000 + now.getMilliseconds()) + 50;
    }

    onRunningChanged: if (running) tick()
    Component.onCompleted: tick()

    Timer {
        id: timer
        running: clock.running
        repeat: true
        onTriggered: clock.tick()
    }
}
