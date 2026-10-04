/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Weather from Open-Meteo (open-meteo.com; see WeatherData.js for what is
    asked and how the answer is read): the current weather, seven days and
    every hour of them, for a place the user chose by name. No key and no
    account; the data is under CC BY 4.0, so the page and the README credit
    it.

    There is no locating: nothing is known about where the computer is until
    a place is chosen (search()), and then only that place's coordinates are
    sent, every half hour while the Weather page is switched on.

    Values are °C, km/h and mm; degrees(), speed() and amount() give them in
    the units of `imperial`. Nothing but now() reads the clock.
*/
import QtQuick
import ".."
import "../WeatherData.js" as WeatherData

Item {
    id: weather

    property bool enabled: true
    // The chosen place: JSON { name, admin, country, latitude, longitude }; "" = none yet.
    property string location: ""
    // °F, mph and inches instead of °C, km/h and mm.
    property bool imperial: false
    // Asking again more often than the forecast changes is of no use.
    property int refreshMinutes: 30
    // Tests hand in other addresses and the moment.
    property string forecastBase: WeatherData.FORECAST_URL
    property string searchBase: WeatherData.SEARCH_URL
    property var clock: null
    function now(): real { return typeof clock === "function" ? clock() : Date.now(); }

    readonly property var place: WeatherData.parsePlace(location)
    readonly property bool hasPlace: place !== null
    readonly property string placeName: place !== null ? place.name : ""
    readonly property string placeLabel: place !== null ? WeatherData.placeLabel(place) : ""

    // What the service last answered, and that as of now (WeatherData.parse).
    property string raw: ""
    property var forecast: null
    property real fetchedAt: 0
    property bool loading: false
    // Why there is no (new) weather: "" | "offline" | "service"
    property string problem: ""
    readonly property bool ready: hasPlace && forecast !== null
    readonly property var current: ready ? forecast.current : null
    readonly property var days: ready ? forecast.days : []
    readonly property real temperature: current !== null ? current.temperature : NaN
    // The picture of the weather now: a name of the embedded set (WeatherIcon.qml).
    readonly property string icon: iconFor(current !== null ? current.kind : "partly", current === null || current.day)
    // Every request that was made (tests look at this).
    property int requests: 0

    // ---- showing ------------------------------------------------------------------
    // The embedded pictures (contents/icons/weather, Lucide), by name: WeatherIcon.qml
    // draws them in the theme's colour.
    function iconFor(kind: string, day: bool): string { return WeatherData.icon(kind, day); }
    function describe(kind: string, day: bool): string {
        switch (kind) {
        case "clear": return day ? Lang.i18n("Sunny") : Lang.i18nc("@info the sky at night", "Clear");
        case "mostly": return Lang.i18n("Mostly clear");
        case "partly": return Lang.i18n("Partly cloudy");
        case "overcast": return Lang.i18n("Overcast");
        case "fog": return Lang.i18n("Fog");
        case "drizzle": return Lang.i18n("Light rain");
        case "rain": return Lang.i18n("Rain");
        case "showers": return Lang.i18n("Showers");
        case "sleet": return Lang.i18n("Sleet");
        case "snow": return Lang.i18n("Snow");
        case "storm": return Lang.i18n("Thunderstorm");
        case "hail": return Lang.i18n("Hail");
        }
        return "";
    }
    function degrees(celsius: real): string { return isNaN(celsius) ? "–" : Math.round(WeatherData.temperature(celsius, imperial)) + "°"; }
    readonly property string degreeUnit: imperial ? "°F" : "°C"
    readonly property string speedUnit: imperial ? Lang.i18nc("@info unit of wind speed", "mph") : Lang.i18nc("@info unit of wind speed", "km/h")
    readonly property string amountUnit: imperial ? Lang.i18nc("@info unit of rainfall, inches", "in") : Lang.i18nc("@info unit of rainfall", "mm")
    function speed(kmh: real): string { return isNaN(kmh) ? "–" : String(Math.round(WeatherData.speed(kmh, imperial))); }
    function amount(mm: real): string {
        if (isNaN(mm)) return "–";
        const v = WeatherData.amount(mm, imperial);
        return v <= 0 ? "0" : v.toLocaleString(Lang.locale, "f", imperial ? 2 : 1);
    }
    // Where the wind comes from: "N", "NE"…
    readonly property var windNames: [Lang.i18nc("@info wind from the north", "N"), Lang.i18nc("@info wind from the north-east", "NE"),
        Lang.i18nc("@info wind from the east", "E"), Lang.i18nc("@info wind from the south-east", "SE"), Lang.i18nc("@info wind from the south", "S"),
        Lang.i18nc("@info wind from the south-west", "SW"), Lang.i18nc("@info wind from the west", "W"), Lang.i18nc("@info wind from the north-west", "NW")]
    function windName(degrees: real): string { return isNaN(degrees) ? "" : windNames[WeatherData.compass(degrees)]; }

    // ---- asking ---------------------------------------------------------------------
    // done(status, text); status 0 = no connection
    function get(url: string, done: var): void {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => { if (xhr.readyState === XMLHttpRequest.DONE) done(xhr.status, xhr.responseText || ""); };
        ++requests;
        xhr.open("GET", url);
        xhr.send();
    }
    property int seq: 0
    function refresh(): void {
        if (!enabled || !hasPlace) return;
        const run = ++seq;
        loading = true;
        get(WeatherData.forecastUrl(forecastBase, place.latitude, place.longitude), (status, text) => {
            if (run !== seq) return;
            loading = false;
            const read = status === 200 ? WeatherData.parse(text, now()) : { ok: false };
            if (!read.ok) { problem = status === 0 ? "offline" : "service"; return; }
            raw = text; forecast = read; fetchedAt = now(); problem = "";
        });
    }
    // For the moment the page opens: ask now unless that just happened; the hour it is moves on either way.
    function refreshIfStale(): void {
        retime();
        if (enabled && hasPlace && !loading && now() - fetchedAt > refreshMinutes * 60000) refresh();
    }
    function retime(): void {
        if (raw.length === 0) return;
        const read = WeatherData.parse(raw, now());
        if (read.ok) forecast = read;
    }
    // Another place: what was known is of the old one.
    readonly property string placeKey: place !== null ? place.latitude + "," + place.longitude : ""
    onPlaceKeyChanged: { ++seq; raw = ""; forecast = null; fetchedAt = 0; problem = ""; loading = false; refresh(); }
    onEnabledChanged: refreshIfStale()
    Timer {
        interval: Math.max(15, weather.refreshMinutes) * 60000
        repeat: true
        running: weather.enabled && weather.hasPlace
        onTriggered: weather.refresh()
    }
    // "Now" and "today" move on between two answers.
    Timer {
        interval: 5 * 60000
        repeat: true
        running: weather.enabled && weather.ready
        onTriggered: weather.retime()
    }

    // The places called like `query`: done(results, problem); see WeatherData.parseSearch.
    // Only the last search answers.
    property int searchSeq: 0
    function search(query: string, done: var): void {
        const run = ++searchSeq, text = query.trim();
        if (text.length < 2) { done([], ""); return; }
        get(WeatherData.searchUrl(searchBase, text, Lang.language), (status, answer) => {
            if (run !== searchSeq) return;
            if (status !== 200) done([], status === 0 ? "offline" : "service"); else done(WeatherData.parseSearch(answer), "");
        });
    }
}
