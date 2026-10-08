#!/usr/bin/env node
// Weather (contents/ui/WeatherData.js): what is asked of Open-Meteo and how its
// answers are read. The fixtures are real answers of the service; the moment
// "now" is handed in, the clock is never read. Run by tools/run-tests.
"use strict";
const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "..");
function load(file) {
    const source = fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*$/m, "");
    const names = Array.from(source.matchAll(/^(?:function|const) (\w+)[ (=]/gm), m => m[1]);
    return new Function(source + "\nreturn { " + names.join(", ") + " };")();
}
const W = load(path.join(ROOT, "org.phobby.dynamicisland", "contents", "ui", "WeatherData.js"));
const fixture = name => fs.readFileSync(path.join(__dirname, "fixtures", name), "utf8");

let failed = 0, checked = 0;
function check(what, got, want) {
    ++checked;
    const g = JSON.stringify(got), w = JSON.stringify(want);
    if (g === w) return;
    ++failed;
    console.log("    FAILED: " + what + "\n      got  " + g + "\n      want " + w);
}
function test(name, body) {
    const before = failed;
    body();
    console.log((failed === before ? "  ok    " : "  FAIL  ") + name);
}

// The forecast fixture is made up for a place three hours ahead of UTC (its figures began as an answer of Open-Meteo): 4 October 2026, 03:30 there.
const FETCHED = Date.UTC(2026, 9, 4, 0, 30);
const FORECAST = fixture("open-meteo-forecast.json");

console.log("WeatherData.js");

test("the forecast: now, seven days, every hour of them", () => {
    const f = W.parse(FORECAST, FETCHED);
    check("read", [f.ok, f.today, f.offsetSeconds], [true, "2026-10-04", 10800]);
    check("now", [f.current.temperature, f.current.feelsLike, f.current.humidity, f.current.wind, f.current.windDirection, f.current.kind, f.current.day],
          [14.8, 14.1, 73, 4.7, 266, "partly", false]);
    check("days", f.days.map(d => [d.date, d.offset]), [["2026-10-04", 0], ["2026-10-05", 1], ["2026-10-06", 2], ["2026-10-07", 3], ["2026-10-08", 4], ["2026-10-09", 5], ["2026-10-10", 6]]);
    const today = f.days[0];
    check("today in short", [today.kind, today.high, today.low, today.chance, today.precipitation, today.sunrise, today.sunset], ["partly", 25.3, 13.9, 0, 0, "07:09", "18:49"]);
    check("24 hours a day", f.days.map(d => d.hours.length), [24, 24, 24, 24, 24, 24, 24]);
    check("the hour it is", today.hours.filter(h => h.now).map(h => h.time), ["03:00"]);
    check("only today has it", f.days.slice(1).some(d => d.hours.some(h => h.now)), false);
    check("an hour", today.hours[14], { time: "14:00", kind: "clear", alert: "", day: true, temperature: 25.1, feelsLike: 22.8, chance: 0, precipitation: 0,
                                         humidity: 28, wind: 14.2, windDirection: 27, now: false });
});

test("every hour has its humidity and its chance of precipitation", () => {
    const f = W.parse(FORECAST, FETCHED);
    const hours = f.days.reduce((all, d) => all.concat(d.hours), []);
    check("168 hours", hours.length, 168);
    for (const field of ["temperature", "feelsLike", "humidity", "chance", "precipitation", "wind", "windDirection"])
        check(field + " is a number in every hour", hours.filter(h => typeof h[field] !== "number" || isNaN(h[field])).length, 0);
    check("humidity is a percentage", hours.every(h => h.humidity >= 0 && h.humidity <= 100), true);
    check("the chance is a percentage", hours.every(h => h.chance >= 0 && h.chance <= 100), true);
});

test("time moves on between two answers", () => {
    // the next morning at 10:20 there: the day that is over is gone, "now" is another hour
    const f = W.parse(FORECAST, Date.UTC(2026, 9, 5, 7, 20));
    check("today", [f.today, f.days.length, f.days[0].date, f.days[0].offset, f.days[1].offset], ["2026-10-05", 6, "2026-10-05", 0, 1]);
    check("the hour it is", f.days[0].hours.filter(h => h.now).map(h => h.time), ["10:00"]);
    // at the place's midnight, not the computer's
    check("23:59 there", W.parse(FORECAST, Date.UTC(2026, 9, 4, 20, 59)).today, "2026-10-04");
    check("00:00 there", W.parse(FORECAST, Date.UTC(2026, 9, 4, 21, 0)).today, "2026-10-05");
    check("a week later nothing is left", W.parse(FORECAST, Date.UTC(2026, 9, 20)).ok, false);
    check("the wall clock there", [W.localNow(Date.UTC(2026, 0, 1, 0, 5), -18000), W.localNow(Date.UTC(2026, 9, 4, 0, 30), 10800)], ["2025-12-31T19:05", "2026-10-04T03:30"]);
});

test("what is not a forecast", () => {
    for (const text of ["", "<html>", "{}", '{"daily":{"time":[]},"hourly":{"time":[]}}', '{"error":true,"reason":"x"}']) check(text.slice(0, 30), W.parse(text, FETCHED).ok, false);
    // an answer without the current weather: this hour of the forecast stands in
    const given = JSON.parse(FORECAST);
    delete given.current;
    const f = W.parse(JSON.stringify(given), FETCHED);
    check("no current weather", [f.ok, f.current.temperature, f.current.humidity], [true, given.hourly.temperature_2m[3], given.hourly.relative_humidity_2m[3]]);
    // a value the service leaves out is "not known", not zero
    given.hourly.precipitation_probability[5] = null;
    check("a missing value", isNaN(W.parse(JSON.stringify(given), FETCHED).days[0].hours[5].chance), true);
});

test("conditions and their pictures, by day and by night", () => {
    const kinds = { 0: "clear", 1: "mostly", 2: "partly", 3: "overcast", 45: "fog", 48: "fog", 51: "drizzle", 53: "drizzle", 55: "drizzle", 56: "sleet", 57: "sleet",
                    61: "rain", 63: "rain", 65: "rain", 66: "sleet", 67: "sleet", 71: "snow", 73: "snow", 75: "snow", 77: "snow", 80: "showers", 81: "showers",
                    82: "showers", 85: "snow", 86: "snow", 95: "storm", 96: "hail", 99: "hail" };
    for (const code in kinds) check("code " + code, W.condition(code).kind, kinds[code]);
    check("what falls", [0, 3, 45, 53, 63, 81, 67, 73, 86, 95, 99].map(c => W.condition(c).alert), ["", "", "", "rain", "rain", "rain", "snow", "snow", "snow", "storm", "storm"]);
    check("an unknown code", W.condition(1234), { kind: "overcast", alert: "" });
    check("day and night", ["clear", "mostly", "partly", "showers", "rain", "fog"].map(k => [W.icon(k, true), W.icon(k, false)]),
          [["sun", "moon"], ["cloud-sun", "cloud-moon"], ["cloud-sun", "cloud-moon"], ["cloud-sun-rain", "cloud-moon-rain"], ["cloud-rain", "cloud-rain"], ["cloud-fog", "cloud-fog"]]);
    const dir = path.join(ROOT, "org.phobby.dynamicisland", "contents", "icons", "weather");
    const used = new Set(["map-pin", "sunrise", "sunset", "cloud"]);
    for (const kind of new Set(Object.values(kinds))) for (const day of [true, false]) used.add(W.icon(kind, day));
    for (const name of used) {
        const file = path.join(dir, name + ".svg");
        check(name + ".svg is there", fs.existsSync(file), true);
        if (fs.existsSync(file)) check(name + ".svg takes the theme's colour", /currentColor/.test(fs.readFileSync(file, "utf8")), true);
    }
    check("with its licence", /ISC License/.test(fs.readFileSync(path.join(dir, "LICENSE"), "utf8")), true);
});

test("units", () => {
    check("°C stays", [W.temperature(21.4, false), W.speed(18, false), W.amount(2.5, false)], [21.4, 18, 2.5]);
    check("°F", [W.temperature(0, true), W.temperature(100, true), W.temperature(-40, true)], [32, 212, -40]);
    check("mph", Math.round(W.speed(100, true) * 100) / 100, 62.14);
    check("inches", Math.round(W.amount(25.4, true) * 100) / 100, 1);
    check("the wind's quarter", [0, 22, 23, 45, 90, 180, 266, 315, 338, 360, -45].map(W.compass), [0, 0, 1, 1, 2, 4, 6, 7, 0, 0, 7]);
});

test("searching a place", () => {
    const found = W.parseSearch(fixture("open-meteo-search.json"));
    check("results", found.length, 6);
    check("the first", found[0], { name: "Tëstwick", admin: "Tëstwick", country: "Commonwealth of Exampleland", latitude: 12.34567, longitude: 45.67891 });
    check("its label", [W.placeLabel(found[0]), W.placeLabel(found[1])], ["Tëstwick, Commonwealth of Exampleland", "Tëstwickham, Northshire, Commonwealth of Exampleland"]);
    check("nothing found", W.parseSearch('{"generationtime_ms":0.06}'), []);
    check("not an answer", [W.parseSearch("<html>"), W.parseSearch("")], [[], []]);
    check("results without a name or coordinates are left out",
          W.parseSearch(JSON.stringify({ results: [{ name: "A" }, { latitude: 1, longitude: 2 }, { name: "B", latitude: 91, longitude: 0 }, { name: "C", latitude: 1.5, longitude: 2.5 }] })),
          [{ name: "C", admin: "", country: "", latitude: 1.5, longitude: 2.5 }]);
});

test("the stored place", () => {
    const place = { name: "Tëstwick", admin: "Tëstwick", country: "Exampleland", latitude: 12.34567, longitude: 45.67891 };
    check("read back", W.parsePlace(JSON.stringify(place)), place);
    for (const bad of ["", "{}", "[]", "x", JSON.stringify({ name: "A" }), JSON.stringify({ name: "A", latitude: "north", longitude: 1 }),
                       JSON.stringify({ name: "", latitude: 1, longitude: 1 }), JSON.stringify({ name: "A", latitude: 95, longitude: 1 }),
                       "bbcukmet|weather|Elsewhere, Otherland, YY|1234567"])
        check("no place: " + bad.slice(0, 30), W.parsePlace(bad), null);
});

test("what is sent: the text searched for, and the place's coordinates", () => {
    const search = new URL(W.searchUrl(W.SEARCH_URL, "  Gün Batımı & Co ", "tr"));
    check("the search", [search.origin + search.pathname, Array.from(search.searchParams.keys()).sort()], ["https://geocoding-api.open-meteo.com/v1/search", ["count", "format", "language", "name"]]);
    check("its text and language", [search.searchParams.get("name"), search.searchParams.get("language")], ["Gün Batımı & Co", "tr"]);
    const forecast = new URL(W.forecastUrl(W.FORECAST_URL, 12.34567, 45.67891));
    check("the forecast", [forecast.origin + forecast.pathname, Array.from(forecast.searchParams.keys()).sort()],
          ["https://api.open-meteo.com/v1/forecast", ["current", "daily", "forecast_days", "hourly", "latitude", "longitude", "timezone"]]);
    check("its coordinates (about 11 m)", [forecast.searchParams.get("latitude"), forecast.searchParams.get("longitude")], ["12.3457", "45.6789"]);
    check("no place name, no key", /name=|key=|token=|Tëstwick|Testwick/i.test(forecast.search), false);
    check("the hours asked for", forecast.searchParams.get("hourly").split(",").sort(),
          ["apparent_temperature", "is_day", "precipitation", "precipitation_probability", "relative_humidity_2m", "temperature_2m", "weather_code", "wind_direction_10m", "wind_speed_10m"]);
});

console.log(failed === 0 ? `${checked} checks passed` : `${failed} of ${checked} checks FAILED`);
process.exit(failed > 0 ? 1 : 0);
