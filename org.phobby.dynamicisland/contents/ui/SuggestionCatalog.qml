/*
    SPDX-License-Identifier: GPL-2.0-or-later
    The suggestions the island can make (Suggestions.RULES), with their names:
    for the settings and for the island's own questions about a rule.
*/
import QtQuick

QtObject {
    readonly property var rules: [
        { id: "meeting", icon: "view-calendar", title: Lang.i18n("Do Not Disturb before an event"),
          hint: Lang.i18n("A calendar event is about to start: Do Not Disturb until it ends") },
        { id: "recording", icon: "media-record", title: Lang.i18n("Hide notifications while the screen is recorded"),
          hint: Lang.i18n("A screen recording or screen sharing starts: Do Not Disturb while it lasts") },
        { id: "call", icon: "audio-input-microphone", title: Lang.i18n("Pause media when the microphone is used"),
          hint: Lang.i18n("An application starts using the microphone (a call) while something plays") },
        { id: "battery", icon: "battery-low", title: Lang.i18n("Save power when the battery is low"),
          hint: Lang.i18n("The battery reaches the low threshold of Alerts: the power saving profile") },
        { id: "pomodoro", icon: "view-task", title: Lang.i18n("Do Not Disturb in a focus round"),
          hint: Lang.i18n("A Pomodoro focus round starts: Do Not Disturb until its break") },
        { id: "headphones", icon: "audio-headphones", title: Lang.i18n("Carry on playing with headphones"),
          hint: Lang.i18n("Headphones are connected while the media is paused") }
    ]
    function title(id: string): string { const r = rules.find(x => x.id === id); return r ? r.title : id; }
}
