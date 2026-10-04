/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Weather from the same source as Plasma's own weather widget: the "weather"
    data engine (plasma-workspace) and its providers. BBC Weather (bbcukmet) is
    the one that covers the world without an account or key, so that is what
    is searched; a place is one of the engine's sources, e.g.
    "bbcukmet|weather|Elsewhere, Otherland, YY|1234567", and other providers'
    sources work as well if one is set by hand.

    What BBC gives: the current observation (temperature, conditions,
    humidity, wind) and a forecast of a few days (condition, high, low, chance
    of rain). It has no hourly forecast and no "feels like": that one is
    worked out here the way weather services do, from the observation: wind
    chill when it is cold and windy, the heat index when it is hot and humid,
    the temperature itself in between. Texts come in English from the
    provider, so the condition is named here from its icon.

    The place is chosen by name (search()). Plasma's own location service
    (the "geolocation" engine) asks Mozilla's location service, which was shut
    down, so there is nothing to locate with automatically.
*/
import QtQuick
import org.kde.plasma.plasma5support as P5
import ".."

Item {
    id: weather

    property bool enabled: true
    property string place: ""
    // Asking again more often than the provider measures is of no use.
    property int refreshMinutes: 30

    readonly property var raw: place.length > 0 && source.data[place] !== undefined ? source.data[place] : null
    readonly property bool ready: raw !== null && raw["Temperature"] !== undefined
    // The engine answers with a report without observation when the place is not known (any more).
    readonly property bool failed: place.length > 0 && raw !== null && !ready
    readonly property string placeName: ready ? String(raw["Place"] || "").replace(/, [A-Z]{2}$/, "") : ""
    readonly property real temperature: ready ? celsius(Number(raw["Temperature"]), raw["Temperature Unit"]) : NaN
    readonly property int humidity: ready && raw["Humidity"] !== undefined ? Math.round(Number(raw["Humidity"])) : -1
    readonly property real windKmh: ready && raw["Wind Speed"] !== undefined ? kmh(Number(raw["Wind Speed"]), raw["Wind Speed Unit"]) : NaN
    readonly property string windDirection: ready ? String(raw["Wind Direction"] || "") : ""
    readonly property string icon: ready ? String(raw["Condition Icon"] || "weather-none-available") : "weather-none-available"
    readonly property string condition: ready ? describe(icon, String(raw["Current Conditions"] || "")) : ""
    readonly property real feelsLike: ready ? apparent(temperature, humidity, windKmh) : NaN
    // °C, % (-1 = unknown), km/h (NaN = unknown)
    function apparent(t: real, rh: int, wind: real): real {
        // Wind chill (Environment Canada / US NWS, 2001), for 10 °C and below with wind.
        if (t <= 10 && !isNaN(wind) && wind > 4.8) {
            const v = Math.pow(wind, 0.16);
            return 13.12 + 0.6215 * t - 11.37 * v + 0.3965 * t * v;
        }
        // Heat index (Rothfusz, US NWS), for 27 °C and above with humid air.
        if (t >= 27 && rh >= 40) {
            const f = t * 9 / 5 + 32;
            const hi = -42.379 + 2.04901523 * f + 10.14333127 * rh - 0.22475541 * f * rh - 0.00683783 * f * f
                     - 0.05481717 * rh * rh + 0.00122874 * f * f * rh + 0.00085282 * f * rh * rh - 0.00000199 * f * f * rh * rh;
            return (hi - 32) * 5 / 9;
        }
        return t;
    }
    readonly property string credit: ready ? String(raw["Credit"] || "") : ""
    readonly property var observed: ready && raw["Observation Timestamp"] ? new Date(raw["Observation Timestamp"]) : null
    // [{ offset (days from today), night, icon, condition, kind, high, low, chance }]; high/low NaN = not given
    readonly property var days: {
        const out = [];
        if (!ready) return out;
        const total = Number(raw["Total Weather Days"]) || 0;
        for (let i = 0; i < total; ++i) {
            const parts = String(raw["Short Forecast Day " + i] || "").split("|");
            if (parts.length < 6) continue;
            const number = t => t.length > 0 && isFinite(Number(t)) ? Number(t) : NaN;
            out.push({
                offset: i, night: i === 0 && /night/i.test(parts[0]), icon: parts[1], condition: describe(parts[1], parts[2]),
                kind: kindOf(parts[1]), high: number(parts[3]), low: number(parts[4]), chance: number(parts[5])
            });
        }
        return out;
    }

    // KUnitConversion ids as the engine reports them.
    function celsius(value: real, unit: var): real {
        return unit === 6002 ? (value - 32) * 5 / 9 : unit === 6000 ? value - 273.15 : value;
    }
    function kmh(value: real, unit: var): real {
        return unit === 9002 ? value * 1.609344 : unit === 9000 ? value * 3.6 : unit === 9005 ? value * 1.852 : value;
    }
    // What falls from the sky, for the alert: "storm" | "snow" | "rain" | ""
    function kindOf(icon: string): string {
        return /storm/.test(icon) ? "storm" : /snow|hail|freezing/.test(icon) ? "snow" : /showers|rain/.test(icon) ? "rain" : "";
    }
    // The condition in the widget's language, by the icon the provider chose.
    function describe(icon: string, fallback: string): string {
        const i = icon.replace(/-(day|night)$/, "").replace(/-night$/, "");
        if (/storm/.test(i)) return Lang.i18n("Thunderstorm");
        if (/hail/.test(i)) return Lang.i18n("Hail");
        if (/snow-rain|freezing/.test(i)) return Lang.i18n("Sleet");
        if (/snow-scattered/.test(i)) return Lang.i18n("Light snow");
        if (/snow/.test(i)) return Lang.i18n("Snow");
        if (/showers-scattered/.test(i)) return Lang.i18n("Light rain");
        if (/showers|rain/.test(i)) return Lang.i18n("Rain");
        if (/fog|mist/.test(i)) return Lang.i18n("Fog");
        if (/many-clouds|overcast/.test(i)) return Lang.i18n("Overcast");
        if (/few-clouds/.test(i)) return Lang.i18n("Mostly clear");
        if (/clouds/.test(i)) return Lang.i18n("Partly cloudy");
        if (/clear/.test(i)) return /night/.test(icon) ? Lang.i18nc("@info the sky at night", "Clear") : Lang.i18n("Sunny");
        return fallback.length > 0 ? fallback.charAt(0).toUpperCase() + fallback.slice(1) : "";
    }

    P5.DataSource {
        id: source
        engine: "weather"
        connectedSources: weather.enabled && weather.place.length > 0 ? [weather.place] : []
        interval: Math.max(15, weather.refreshMinutes) * 60000
    }

    // ---- choosing a place ---------------------------------------------------------
    // done([{ name, place }]) with the places BBC knows by that name; [] = none (or no network).
    property var pending: ({})
    function search(query: string, done: var): void {
        const text = query.trim();
        if (text.length === 0) { done([]); return; }
        const key = "bbcukmet|validate|" + text;
        pending[key] = done;
        // An answer that is still held would not be announced again.
        finder.disconnectSource(key);
        finder.connectSource(key);
        giveUp.restart();
    }
    P5.DataSource {
        id: finder
        engine: "weather"
        onNewData: (key, data) => {
            const done = weather.pending[key];
            if (done === undefined || data["validate"] === undefined) return;
            delete weather.pending[key];
            finder.disconnectSource(key);
            // "bbcukmet|valid|single|place|NAME|extra|ID" or "…|multiple|place|…|extra|…|place|…"; "…|invalid|…" = none
            const parts = String(data["validate"]).split("|"), found = [];
            for (let i = 0; parts[1] === "valid" && i + 3 < parts.length; ++i) {
                if (parts[i] !== "place" || parts[i + 2] !== "extra") continue;
                found.push({ name: parts[i + 1].replace(/, [A-Z]{2}$/, ""), place: "bbcukmet|weather|" + parts[i + 1] + "|" + parts[i + 3] });
            }
            done(found);
        }
    }
    Timer {
        id: giveUp
        interval: 15000
        onTriggered: {
            const waiting = weather.pending;
            weather.pending = ({});
            for (const key in waiting) { finder.disconnectSource(key); waiting[key]([]); }
        }
    }
}
