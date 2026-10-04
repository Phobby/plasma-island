/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Weather alert: rain, snow or a storm in the forecast is shown on the island
    once, as a transient event of its own (it has nothing to do with the
    System page's cards). The forecast is by the day, so the alert says today,
    tonight or tomorrow, not the minute it starts.

    `announced` remembers what was shown ("2026-10-04:rain,2026-10-05:storm"),
    so the same forecast is not announced again with every refresh or after a
    restart of the shell.
*/
import QtQuick
import ".."

Item {
    id: provider

    required property ActivityManager manager
    required property Theme theme
    property var weather: null              // backend/WeatherBackend.qml
    // Tests hand in the day; nothing else here reads the clock.
    property var clock: null
    function today(): var { return typeof clock === "function" ? clock() : new Date(); }
    property bool enabled: true
    property string announced: ""
    signal announcedEdited(string text)
    // Below this chance of rain the provider's icon alone is not worth an alert.
    property int minimumChance: 40

    function dayKey(offset: int, today: var): string {
        const d = new Date(today.getFullYear(), today.getMonth(), today.getDate() + offset, 12);
        const two = n => (n < 10 ? "0" : "") + n;
        return d.getFullYear() + "-" + two(d.getMonth() + 1) + "-" + two(d.getDate());
    }
    // What is worth announcing in `days` (the backend's list) that `already` does not
    // hold: [{ key, kind, offset, night, chance }], today and tomorrow only. `kind` is
    // what falls from the sky (a day's `alert`: rain, snow or storm); `night` says that
    // today's is left for the night.
    function pending(days: var, already: string, today: var, night: bool): var {
        const seen = already.split(",");
        const out = [];
        for (const day of days) {
            if (day.offset > 1 || day.alert.length === 0) continue;
            if (day.alert === "rain" && !isNaN(day.chance) && day.chance < minimumChance) continue;
            const key = dayKey(day.offset, today) + ":" + day.alert;
            if (seen.indexOf(key) < 0) out.push({ key: key, kind: day.alert, offset: day.offset, night: day.offset === 0 && night, chance: day.chance });
        }
        return out;
    }
    function title(kind: string, offset: int, night: bool): string {
        if (kind === "storm")
            return offset === 1 ? Lang.i18n("Storm tomorrow") : night ? Lang.i18n("Storm tonight") : Lang.i18n("Storm today");
        if (kind === "snow")
            return offset === 1 ? Lang.i18n("Snow tomorrow") : night ? Lang.i18n("Snow tonight") : Lang.i18n("Snow today");
        return offset === 1 ? Lang.i18n("Rain tomorrow") : night ? Lang.i18n("Rain tonight") : Lang.i18n("Rain today");
    }
    function check(): void {
        // Not while the island still drops events (its first moments): it would count as announced.
        if (!enabled || !weather || !weather.ready || manager.warm === false) return;
        const today = provider.today();
        const news = pending(weather.days, announced, today, weather.current !== null && !weather.current.day);
        if (news.length === 0) return;
        // The nearest and most serious one speaks; all of them count as announced.
        const rank = n => n.offset * 10 + (n.kind === "storm" ? 0 : n.kind === "snow" ? 1 : 2);
        const first = news.slice().sort((a, b) => rank(a) - rank(b))[0];
        manager.flash({
            key: "weather",
            shake: first.kind === "storm",
            // the widget's own pictures ("weather:" + name, see ActivityIcon)
            icon: "weather:" + (first.kind === "storm" ? "cloud-lightning" : first.kind === "snow" ? "cloud-snow" : "cloud-rain"),
            color: first.kind === "storm" ? theme.orange : theme.blue,
            title: title(first.kind, first.offset, first.night),
            subtitle: weather.placeName,
            trailing: !isNaN(first.chance) && first.chance > 0 ? { type: "text", text: Lang.percent(Math.round(first.chance)), color: theme.text } : undefined,
            duration: 6000
        });
        // Days that have passed are dropped.
        const kept = announced.split(",").filter(k => k.length > 0 && k.slice(0, 10) >= dayKey(0, today));
        announcedEdited(kept.concat(news.map(n => n.key)).join(","));
    }

    Connections {
        target: provider.weather
        function onDaysChanged() { provider.check(); }
    }
    onEnabledChanged: check()
    // The island does not show events in its first moments (ActivityManager.warm).
    Timer { interval: 20000; running: true; onTriggered: provider.check() }
}
