/*
    SPDX-License-Identifier: GPL-2.0-or-later
    The suggestions the island can make (Suggestions.RULES), with their names:
    for the settings and for the island's own questions about a rule.
*/
import QtQuick
import "Suggestions.js" as Suggestions

QtObject {
    readonly property var rules: [
        { id: "meeting", icon: "view-calendar", title: Lang.i18n("Do Not Disturb before an event"),
          hint: Lang.i18n("A calendar event is about to start: Do Not Disturb until it ends") },
        { id: "meeting-media", icon: "media-playback-pause", title: Lang.i18n("Pause media before a video meeting"),
          hint: Lang.i18n("An event with a video link is about to start while something plays") },
        { id: "recording", icon: "media-record", title: Lang.i18n("Hide notifications while the screen is recorded"),
          hint: Lang.i18n("A screen recording or screen sharing starts: Do Not Disturb while it lasts") },
        { id: "call", icon: "audio-input-microphone", title: Lang.i18n("Pause media when the microphone is used"),
          hint: Lang.i18n("An application starts using the microphone (a call) while something plays") },
        { id: "pomodoro", icon: "view-task", title: Lang.i18n("Do Not Disturb in a focus round"),
          hint: Lang.i18n("A Pomodoro focus round starts: Do Not Disturb until its break") },
        { id: "battery", icon: "battery-low", title: Lang.i18n("Save power when the battery is low"),
          hint: Lang.i18n("The battery reaches the low threshold of Alerts: the power saving profile") },
        { id: "disconnect", icon: "audio-headphones", title: Lang.i18n("Pause media when the headphones go away"),
          hint: Lang.i18n("The headphones are disconnected while something plays") },
        { id: "headphones", icon: "audio-headphones", title: Lang.i18n("Carry on playing with headphones"), experimental: true,
          hint: Lang.i18n("Experimental: headphones are told from a device's name, which can be wrong. Headphones are connected while the media is paused") }
    ]
    function title(id: string): string { const r = rules.find(x => x.id === id); return r ? r.title : id; }
    // A context (Suggestions.context) in words: "Weekdays · evening · Work".
    function contextText(ctx: string): string {
        const f = Suggestions.features(ctx), parts = [];
        if (f.day) parts.push(f.day === "we" ? Lang.i18n("Weekend") : Lang.i18n("Weekdays"));
        if (f.part) parts.push(f.part === "am" ? Lang.i18n("morning") : f.part === "noon" ? Lang.i18n("midday") : f.part === "eve" ? Lang.i18n("evening") : Lang.i18n("night"));
        if (f.calendar) parts.push(f.calendar);
        if (f.duration) parts.push(f.duration === "short" ? Lang.i18n("short events") : f.duration === "mid" ? Lang.i18n("events up to 90 min") : Lang.i18n("long events"));
        if (f.video) parts.push(Lang.i18n("with a video link"));
        if (f.output) parts.push(f.output === "hp" ? Lang.i18n("headphones") : Lang.i18n("speakers"));
        return parts.length > 0 ? parts.join(" · ") : Lang.i18n("Always");
    }
    // What a rule does in a context (Suggestions.status), in a word.
    function statusText(status: string): string {
        return status === "auto" ? Lang.i18n("automatic") : status === "silent" ? Lang.i18n("does not ask")
             : status === "off" ? Lang.i18n("closed") : status === "offer" ? Lang.i18n("asks; about to offer doing it by itself") : Lang.i18n("asks");
    }
}
