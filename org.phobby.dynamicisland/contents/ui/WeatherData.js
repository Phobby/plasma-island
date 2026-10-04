/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Weather from Open-Meteo (open-meteo.com): what is asked and how the answer
    is read. No key, no account. The forecast gives the current weather, seven
    days and every hour of them (temperature, what it feels like, humidity,
    chance and amount of precipitation, wind), the geocoding service finds a
    place by its name.

    What is sent: to the geocoding service the text typed into the search
    (and the language for the names it answers with); to the forecast service
    the coordinates of the place that was chosen. Nothing else.

    Values are kept in °C, km/h and mm as the service gives them; the page
    converts for showing (temperature(), speed(), amount()). Times are the
    place's own wall-clock times ("2026-10-04T14:00"): "now" there is
    localNow(), from a moment that is handed in, so nothing here reads the
    clock. Runs under node as well: tests/weather.test.js.
*/
.pragma library

const FORECAST_URL = "https://api.open-meteo.com/v1/forecast";
const SEARCH_URL = "https://geocoding-api.open-meteo.com/v1/search";

function forecastUrl(base, latitude, longitude) {
    return base + "?latitude=" + encodeURIComponent(Number(latitude).toFixed(4)) + "&longitude=" + encodeURIComponent(Number(longitude).toFixed(4))
        + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m,wind_direction_10m"
        + "&hourly=temperature_2m,apparent_temperature,relative_humidity_2m,precipitation_probability,precipitation,weather_code,wind_speed_10m,wind_direction_10m,is_day"
        + "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max,precipitation_sum"
        + "&timezone=auto&forecast_days=7";
}
function searchUrl(base, query, language) {
    return base + "?name=" + encodeURIComponent(String(query).trim()) + "&count=8&language=" + encodeURIComponent(language) + "&format=json";
}

// The places a search found: [{ name, admin (region), country, latitude, longitude }].
function parseSearch(text) {
    let given;
    try { given = JSON.parse(text); } catch (e) { return []; }
    const out = [];
    for (const r of (given && Array.isArray(given.results)) ? given.results : []) {
        const latitude = Number(r.latitude), longitude = Number(r.longitude);
        if (typeof r.name !== "string" || r.name.length === 0 || !isFinite(latitude) || !isFinite(longitude)) continue;
        if (Math.abs(latitude) > 90 || Math.abs(longitude) > 180) continue;
        out.push({ name: r.name, admin: typeof r.admin1 === "string" ? r.admin1 : "", country: typeof r.country === "string" ? r.country : "",
                   latitude: latitude, longitude: longitude });
    }
    return out;
}
// The stored place: { name, admin, country, latitude, longitude }, or null when there is none.
function parsePlace(json) {
    let p;
    try { p = JSON.parse(json || ""); } catch (e) { return null; }
    if (!p || typeof p !== "object" || typeof p.name !== "string" || p.name.length === 0) return null;
    const latitude = Number(p.latitude), longitude = Number(p.longitude);
    if (!isFinite(latitude) || !isFinite(longitude) || Math.abs(latitude) > 90 || Math.abs(longitude) > 180) return null;
    return { name: p.name, admin: String(p.admin || ""), country: String(p.country || ""), latitude: latitude, longitude: longitude };
}
// "Name, Region, Country" (the region only when it is not the place's own name)
function placeLabel(place) {
    const parts = [place.name];
    if (place.admin && place.admin !== place.name) parts.push(place.admin);
    if (place.country) parts.push(place.country);
    return parts.join(", ");
}

// ---- conditions --------------------------------------------------------------------
// What a WMO weather code is: `kind` names the picture and the text,
// `alert` what falls from the sky ("rain" | "snow" | "storm" | "").
//   clear, mostly (mainly clear), partly, overcast, fog, drizzle, rain, showers, sleet, snow, storm, hail
function condition(code) {
    const c = Number(code);
    if (c === 0) return { kind: "clear", alert: "" };
    if (c === 1) return { kind: "mostly", alert: "" };
    if (c === 2) return { kind: "partly", alert: "" };
    if (c === 3) return { kind: "overcast", alert: "" };
    if (c === 45 || c === 48) return { kind: "fog", alert: "" };
    if (c >= 51 && c <= 55) return { kind: "drizzle", alert: "rain" };
    if (c === 56 || c === 57 || c === 66 || c === 67) return { kind: "sleet", alert: "snow" };
    if (c >= 61 && c <= 65) return { kind: "rain", alert: "rain" };
    if ((c >= 71 && c <= 77) || c === 85 || c === 86) return { kind: "snow", alert: "snow" };
    if (c >= 80 && c <= 82) return { kind: "showers", alert: "rain" };
    if (c === 95) return { kind: "storm", alert: "storm" };
    if (c === 96 || c === 99) return { kind: "hail", alert: "storm" };
    return { kind: "overcast", alert: "" };
}
// The picture for a kind by day and by night: a file of contents/icons/weather (without ".svg").
function icon(kind, day) {
    switch (kind) {
    case "clear": return day ? "sun" : "moon";
    case "mostly":
    case "partly": return day ? "cloud-sun" : "cloud-moon";
    case "overcast": return "cloudy";
    case "fog": return "cloud-fog";
    case "drizzle": return "cloud-drizzle";
    case "rain": return "cloud-rain";
    case "showers": return day ? "cloud-sun-rain" : "cloud-moon-rain";
    case "sleet": return "cloud-hail";
    case "snow": return "cloud-snow";
    case "storm": return "cloud-lightning";
    case "hail": return "cloud-hail";
    }
    return "cloud";
}

// ---- units -------------------------------------------------------------------------
function temperature(celsius, imperial) { return imperial ? celsius * 9 / 5 + 32 : celsius; }
function speed(kmh, imperial) { return imperial ? kmh / 1.609344 : kmh; }
function amount(mm, imperial) { return imperial ? mm / 25.4 : mm; }
// 0 = north, 1 = north-east … 7 = north-west: where the wind comes from.
function compass(degrees) { return ((Math.round(Number(degrees) / 45) % 8) + 8) % 8; }

// ---- the forecast --------------------------------------------------------------------
// The wall-clock time at the place, "YYYY-MM-DDTHH:MM", at the moment `nowMs` (epoch ms).
function localNow(nowMs, offsetSeconds) {
    const d = new Date(nowMs + offsetSeconds * 1000), two = n => (n < 10 ? "0" : "") + n;
    return d.getUTCFullYear() + "-" + two(d.getUTCMonth() + 1) + "-" + two(d.getUTCDate()) + "T" + two(d.getUTCHours()) + ":" + two(d.getUTCMinutes());
}
function number(v) { return v === null || v === undefined || !isFinite(Number(v)) ? NaN : Number(v); }
// Days between two "YYYY-MM-DD".
function dayOffset(date, today) {
    const ms = key => Date.UTC(Number(key.slice(0, 4)), Number(key.slice(5, 7)) - 1, Number(key.slice(8, 10)));
    return Math.round((ms(date) - ms(today)) / 86400000);
}

// The forecast as the page shows it, at the moment `nowMs`:
// { ok, offsetSeconds, today ("YYYY-MM-DD" at the place),
//   current: { time, temperature, feelsLike, humidity, precipitation, wind, windDirection, kind, alert, day },
//   days: [{ date, offset (0 = today), kind, alert, high, low, chance, precipitation, sunrise, sunset ("HH:MM"),
//            hours: [{ time ("HH:MM"), kind, alert, day, temperature, feelsLike, chance, precipitation, humidity,
//                      wind, windDirection, now (the hour it is at the place) }] }] }
// Days that are over are left out. NaN = the service did not say.
function parse(text, nowMs) {
    let given;
    try { given = JSON.parse(text); } catch (e) { return { ok: false }; }
    if (!given || typeof given !== "object" || !given.daily || !given.hourly || !Array.isArray(given.daily.time) || !Array.isArray(given.hourly.time)) return { ok: false };
    const offsetSeconds = Number(given.utc_offset_seconds) || 0;
    const now = localNow(nowMs, offsetSeconds), today = now.slice(0, 10), hourNow = now.slice(0, 13);
    const h = given.hourly, d = given.daily, c = given.current || {};
    const at = (list, i) => Array.isArray(list) ? number(list[i]) : NaN;

    const hoursOf = {};
    for (let i = 0; i < h.time.length; ++i) {
        const stamp = String(h.time[i]), what = condition(at(h.weather_code, i));
        (hoursOf[stamp.slice(0, 10)] = hoursOf[stamp.slice(0, 10)] || []).push({
            time: stamp.slice(11, 16), kind: what.kind, alert: what.alert, day: at(h.is_day, i) !== 0,
            temperature: at(h.temperature_2m, i), feelsLike: at(h.apparent_temperature, i), chance: at(h.precipitation_probability, i),
            precipitation: at(h.precipitation, i), humidity: at(h.relative_humidity_2m, i), wind: at(h.wind_speed_10m, i),
            windDirection: at(h.wind_direction_10m, i), now: stamp.slice(0, 13) === hourNow
        });
    }
    const days = [];
    for (let i = 0; i < d.time.length; ++i) {
        const date = String(d.time[i]), offset = dayOffset(date, today);
        if (offset < 0) continue;
        const what = condition(at(d.weather_code, i));
        const clock = list => Array.isArray(list) && typeof list[i] === "string" ? list[i].slice(11, 16) : "";
        days.push({ date: date, offset: offset, kind: what.kind, alert: what.alert, high: at(d.temperature_2m_max, i), low: at(d.temperature_2m_min, i),
                    chance: at(d.precipitation_probability_max, i), precipitation: at(d.precipitation_sum, i),
                    sunrise: clock(d.sunrise), sunset: clock(d.sunset), hours: hoursOf[date] || [] });
    }
    if (days.length === 0) return { ok: false };
    const what = condition(number(c.weather_code));
    const current = { time: String(c.time || ""), temperature: number(c.temperature_2m), feelsLike: number(c.apparent_temperature),
                      humidity: number(c.relative_humidity_2m), precipitation: number(c.precipitation), wind: number(c.wind_speed_10m),
                      windDirection: number(c.wind_direction_10m), kind: what.kind, alert: what.alert, day: number(c.is_day) !== 0 };
    // An answer without the current weather: this hour of the forecast.
    if (isNaN(current.temperature)) {
        const hour = (days[0].hours || []).find(x => x.now);
        if (!hour) return { ok: false };
        Object.assign(current, { temperature: hour.temperature, feelsLike: hour.feelsLike, humidity: hour.humidity, precipitation: hour.precipitation,
                                 wind: hour.wind, windDirection: hour.windDirection, kind: hour.kind, alert: hour.alert, day: hour.day });
    }
    return { ok: true, offsetSeconds: offsetSeconds, today: today, current: current, days: days };
}
