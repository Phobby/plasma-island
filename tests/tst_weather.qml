/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The Weather page with its real backend, against answers of Open-Meteo
    served on 127.0.0.1 (tests/fixtures, tests/catalog-server.py), and the
    rain alert. The backend is handed its time (`clock`); the server's log
    shows what was asked and what was not. The parts that need the server are
    skipped when the native module is not built.
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"
import "../org.phobby.dynamicisland/contents/ui/backend"
import "../org.phobby.dynamicisland/contents/ui/providers"
import "../org.phobby.dynamicisland/contents/ui/WeatherData.js" as WeatherData

Item {
    id: root
    width: 400
    height: 135

    Loader { id: tools; source: "../org.phobby.dynamicisland/contents/ui/LocalBridge.qml" }
    readonly property var local: tools.status === Loader.Ready ? tools.item : null
    readonly property string here: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, ""))
    readonly property string logFile: here + "/.run/weather-" + Math.floor(Math.random() * 1e9).toString(36) + ".log"

    // The fixture is made up for a place three hours ahead of UTC (its figures began as an answer of Open-Meteo): 4 October 2026, 03:30 there.
    property real moment: Date.UTC(2026, 9, 4, 0, 30)
    Theme { id: islandTheme; follow: false }
    ActivityManager { id: activities }
    WeatherBackend {
        id: backend
        clock: () => root.moment
        forecastBase: "http://127.0.0.1:1/none"
        searchBase: "http://127.0.0.1:1/none"
    }
    WeatherPage {
        id: page
        anchors.fill: parent
        theme: islandTheme
        weather: backend
        earlierName: "Elsewhere, Otherland"
    }
    SignalSpy { id: picked; target: page; signalName: "locationPicked" }
    property string announced: ""
    WeatherProvider {
        id: alerts
        manager: activities
        theme: islandTheme
        weather: backend
        announced: root.announced
        onAnnouncedEdited: text => root.announced = text
        clock: () => new Date(2026, 9, 4, 9, 0)
    }

    TestCase {
        name: "Weather"
        when: windowShown
        property int port: 0

        function log() { return root.local.readTextFile(root.logFile).split("\n").filter(l => l.length > 0); }
        function quit() { if (port > 0) { const x = new XMLHttpRequest(); x.open("GET", "http://127.0.0.1:" + port + "/__quit"); x.send(); wait(300); port = 0; } }
        function initTestCase() {
            Lang.setting = "en";
            activities.warm = true;
        }
        function cleanupTestCase() {
            quit();
            if (root.local !== null) root.local.removeFile(root.logFile);
        }
        function needServer() {
            if (root.local === null || typeof root.local.writeTextFile !== "function") skip("the native module is not built: ./install.sh");
            if (port > 0) return;
            let answer = null;
            root.local.writeTextFile(root.logFile, "");
            root.local.run("python3", [root.here + "/catalog-server.py", "--dir", root.here + "/fixtures", "--log", root.logFile, "--lifetime", "40"],
                           (code, out, err) => { answer = { code: code, out: out, err: err }; });
            tryVerify(() => answer !== null, 10000);
            compare(answer.code, 0, answer.err);
            port = Number(answer.out.trim());
            backend.forecastBase = "http://127.0.0.1:" + port + "/open-meteo-forecast.json";
            backend.searchBase = "http://127.0.0.1:" + port + "/open-meteo-search.json";
        }

        function test_1_starts_empty_and_asks_nothing() {
            needServer();
            wait(400);
            compare([backend.hasPlace, backend.ready, page.view, page.hasPlace], [false, false, "now", false]);
            backend.refresh();
            backend.refreshIfStale();
            wait(300);
            compare(backend.requests, 0, "no place, no request: the place is never detected");
            compare(log(), []);
        }

        function test_2_search_by_name_and_choose() {
            needServer();
            page.openSearch();
            compare([page.view, page.typing, page.interacting], ["search", true, true]);
            const field = findChild(page, "") ;
            // the earlier source's place only starts the search; nothing is asked for it
            wait(500);
            compare(log(), []);
            // typed: asked once the typing pauses
            let input = null;
            const walk = item => { if (item.placeholder !== undefined && item.visible && item.input) input = item; for (const c of item.children) walk(c); };
            walk(page);
            verify(input !== null);
            compare(input.text, "Elsewhere");
            input.text = "Tes";
            input.edited();
            input.text = "Testwick";
            input.edited();
            tryVerify(() => page.found.length > 0, 10000);
            compare(log().length, 1, "one request for what was typed, not one per letter");
            const asked = new RegExp("^GET /open-meteo-search\\.json\\?name=Testwick&count=8&language=en&format=json$");
            verify(asked.test(log()[0]), log()[0]);
            compare(page.found.length, 6);
            compare([page.found[0].name, page.found[0].admin, page.found[0].country], ["Tëstwick", "Tëstwick", "Republic of Exampleland"]);

            page.pick(page.found[0]);
            compare(picked.count, 1);
            compare([page.view, page.typing], ["now", false]);
            const stored = JSON.parse(picked.signalArguments[0][0]);
            compare(Object.keys(stored).sort(), ["admin", "country", "latitude", "longitude", "name"]);
            // main.qml stores it; the backend reads it
            backend.location = picked.signalArguments[0][0];
            tryCompare(backend, "ready", true, 10000);
            compare(log().length, 2);
            verify(/^GET \/open-meteo-forecast\.json\?latitude=12\.3457&longitude=45\.6789&current=/.test(log()[1]), log()[1]);
            verify(log()[1].indexOf("stwick") < 0, "the name is not sent with the coordinates");
            compare([backend.placeName, backend.placeLabel], ["Tëstwick", "Tëstwick, Republic of Exampleland"]);
        }

        function test_3_now_and_the_days() {
            needServer();
            verify(backend.ready);
            compare([backend.current.temperature, backend.degrees(backend.current.temperature), backend.current.day], [14.8, "15°", false]);
            compare(backend.icon, "cloud-moon");
            compare(backend.describe(backend.current.kind, backend.current.day), "Partly cloudy");
            compare(backend.days.length, 7);
            compare(backend.windName(backend.current.windDirection), "W");
            // units and language are the settings'
            backend.imperial = true;
            compare([backend.degrees(14.8), backend.degrees(0), backend.speed(100), backend.amount(25.4), backend.degreeUnit, backend.speedUnit, backend.amountUnit],
                    ["59°", "32°", "62", "1.00", "°F", "mph", "in"]);
            backend.imperial = false;
            compare([backend.degrees(14.8), backend.speed(100), backend.amount(2.5), backend.degreeUnit, backend.speedUnit], ["15°", "100", "2.5", "°C", "km/h"]);
            Lang.setting = "tr";
            compare([backend.describe("showers", true), backend.windName(45), backend.speedUnit, page.dayName(backend.days[1], true)], ["Sağanak", "KD", "km/sa", "Pazartesi, 5 Ekim"]);
            Lang.setting = "en";
            compare(page.dayName(backend.days[0], false), "Tonight");
            compare(page.dayName(backend.days[1], false), "Mon");
        }

        function test_4_a_day_hour_by_hour_and_back() {
            needServer();
            compare(page.day, null);
            page.shownDay = 0;
            compare(page.day.date, "2026-10-04");
            compare(page.day.hours.length, 24);
            compare(page.day.hours.filter(h => h.now).map(h => h.time), ["03:00"], "the hour it is");
            const noon = page.day.hours[12];
            verify(!isNaN(noon.humidity) && !isNaN(noon.chance) && !isNaN(noon.feelsLike) && !isNaN(noon.wind), "humidity, chance, feels like, wind");
            compare([page.day.sunrise, page.day.sunset, backend.degrees(page.day.high), backend.degrees(page.day.low)], ["07:09", "18:49", "25°", "14°"]);
            wait(400);
            page.shownDay = 3;
            compare(page.day.date, "2026-10-07");
            compare(page.day.hours.some(h => h.now), false);
            // back
            page.shownDay = -1;
            compare(page.day, null);
            wait(400);
            // the place can be changed at any time
            page.openSearch();
            compare(page.view, "search");
            page.closeSearch();
            compare(page.view, "now");
        }

        function test_5_time_moves_on_without_asking() {
            needServer();
            const asked = backend.requests;
            root.moment = Date.UTC(2026, 9, 4, 9, 10);          // 12:10 there
            backend.retime();
            compare(backend.days[0].hours.filter(h => h.now).map(h => h.time), ["12:00"]);
            compare(backend.requests, asked);
            // half an hour is not over: opening the page asks nothing
            root.moment = Date.UTC(2026, 9, 4, 0, 50);
            backend.refreshIfStale();
            compare(backend.requests, asked);
            root.moment = Date.UTC(2026, 9, 4, 1, 5);
            backend.refreshIfStale();
            compare(backend.requests, asked + 1);
            tryCompare(backend, "loading", false, 10000);
        }

        function test_6_offline_keeps_what_is_known() {
            needServer();
            quit();
            backend.refresh();
            tryCompare(backend, "loading", false, 10000);
            compare([backend.problem, backend.ready, backend.days.length], ["offline", true, 7]);
            let answer = null;
            backend.search("Otherton", (results, problem) => { answer = [results.length, problem]; });
            tryVerify(() => answer !== null, 10000);
            compare(answer, [0, "offline"]);
            // another place while offline: nothing to show, and it says why
            backend.location = JSON.stringify({ name: "Otherton", admin: "", country: "Exampleland", latitude: 23.45, longitude: 56.78 });
            tryCompare(backend, "problem", "offline", 10000);
            compare(backend.ready, false);
        }

        function test_7_rain_alert_once() {
            const day = (offset, alert, chance) => ({ offset: offset, alert: alert, chance: chance });
            const today = new Date(2026, 9, 4, 9, 0);
            compare(alerts.pending([day(0, "", 0), day(1, "rain", 70), day(2, "storm", 90)], "", today, false),
                    [{ key: "2026-10-05:rain", kind: "rain", offset: 1, night: false, chance: 70 }]);
            compare(alerts.pending([day(0, "rain", 30)], "", today, false), [], "a small chance of rain is no alert");
            compare(alerts.pending([day(0, "storm", 10)], "", today, true), [{ key: "2026-10-04:storm", kind: "storm", offset: 0, night: true, chance: 10 }]);
            compare(alerts.pending([day(1, "rain", 70)], "2026-10-05:rain", today, false), [], "already announced");
            compare([alerts.title("rain", 1, false), alerts.title("storm", 0, true), alerts.title("snow", 0, false)], ["Rain tomorrow", "Storm tonight", "Snow today"]);

            // through the backend: tomorrow's rain is announced once, with the widget's own picture
            activities.dismissEvent();
            const given = JSON.parse(root.local !== null ? root.local.readTextFile(root.here + "/fixtures/open-meteo-forecast.json", 200000) : "{}");
            if (given.daily === undefined) skip("the native module is not built: ./install.sh");
            given.daily.weather_code[1] = 63;
            given.daily.precipitation_probability_max[1] = 80;
            backend.raw = JSON.stringify(given);
            backend.location = JSON.stringify({ name: "Tëstwick", admin: "Tëstwick", country: "Exampleland", latitude: 12.34567, longitude: 45.67891 });
            backend.raw = JSON.stringify(given);
            root.moment = Date.UTC(2026, 9, 4, 6, 0);
            backend.retime();
            verify(backend.ready);
            compare(backend.days[1].alert, "rain");
            alerts.check();
            tryVerify(() => activities.currentEvent !== null && activities.currentEvent.key === "weather");
            compare([activities.currentEvent.title, activities.currentEvent.subtitle, activities.currentEvent.trailing.text], ["Rain tomorrow", "Tëstwick", "80%"]);
            compare(activities.currentEvent.icon, "weather:cloud-rain");
            compare(root.announced, "2026-10-05:rain");
            activities.dismissEvent();
            alerts.check();
            wait(100);
            compare(activities.currentEvent, null, "once");
        }
    }
}
