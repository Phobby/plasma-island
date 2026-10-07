/*
    SPDX-License-Identifier: GPL-2.0-or-later

    A calendar link is downloaded with an end to it (IcsDownload): no more
    than its limit, no longer than its time. Against links served on
    127.0.0.1 (tests/ics-server.py): a whole calendar, one that is too large
    by its own account, one that never ends and gives no length, a server
    that says nothing and one that stops in the middle; then the two places
    that download a link, the check when one is connected (CalendarLinks) and
    the backend. Skipped when the native module is not built (it starts the
    server).
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"
import "../org.phobby.dynamicisland/contents/ui/backend"

Item {
    id: root
    width: 100
    height: 100

    Loader { id: tools; source: "../org.phobby.dynamicisland/contents/ui/LocalBridge.qml" }
    readonly property var local: tools.status === Loader.Ready ? tools.item : null
    readonly property string here: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, ""))

    // One megabyte and a second and a half, so that the test is over soon.
    IcsDownload { id: fetcher; limit: 1048576; timeout: 1500 }
    CalendarLinks { id: links }
    IcsCalendarBackend { id: calendar; downloadLimit: 1048576; downloadTimeout: 1500 }

    TestCase {
        name: "CalendarDownload"
        when: windowShown
        property int port: 0

        function url(name) { return "http://127.0.0.1:" + port + "/" + name; }
        function get(address) {
            let result = null;
            const began = Date.now();
            fetcher.get(address, (status, text) => { result = { status: status, text: text, ms: Date.now() - began }; });
            tryVerify(() => result !== null, 10000);
            return result;
        }

        function initTestCase() {
            Lang.setting = "en";
            if (root.local === null || typeof root.local.run !== "function") skip("the native module is not built: ./install.sh");
            let answer = null;
            root.local.run("python3", [root.here + "/ics-server.py", "--lifetime", "40"], (code, out, err) => { answer = { code: code, out: out, err: err }; });
            tryVerify(() => answer !== null, 10000);
            compare(answer.code, 0, answer.err);
            port = Number(answer.out.trim());
            verify(port > 0);
        }
        function cleanupTestCase() {
            if (port > 0) { const x = new XMLHttpRequest(); x.open("GET", url("__quit")); x.send(); wait(200); }
        }

        function test_1_a_whole_calendar() {
            const r = get(url("ok.ics"));
            compare(r.status, 200);
            verify(r.text.indexOf("BEGIN:VCALENDAR") === 0 && r.text.indexOf("END:VCALENDAR") > 0, "all of it");
        }
        function test_2_too_large_by_its_own_account() {
            const r = get(url("large.ics"));
            compare(r.status, fetcher.tooLarge);
            compare(r.text, "", "nothing of it is handed on");
            verify(r.ms < 1000, "refused when its length was read, not after the download: " + r.ms + " ms");
        }
        function test_3_endless_without_a_length() {
            const r = get(url("endless.ics"));
            compare(r.status, fetcher.tooLarge);
            compare(r.text, "");
            verify(r.ms < 1400, "cut off for its size, before its time was up: " + r.ms + " ms");
        }
        function test_4_a_server_that_says_nothing() {
            const r = get(url("silent.ics"));
            compare(r.status, fetcher.tooLate);
            verify(r.ms >= 1400 && r.ms < 4000, "after its time: " + r.ms + " ms");
        }
        function test_5_a_download_that_stops_in_the_middle() {
            const r = get(url("stalls.ics"));
            compare(r.status, fetcher.tooLate);
            compare(r.text, "", "half a calendar is not handed on");
        }
        function test_6_nobody_there() {
            compare(get("http://127.0.0.1:1/none.ics").status, 0);
        }

        function test_7_the_check_when_a_link_is_connected() {
            links.fetcher.limit = 1048576;
            links.fetcher.timeout = 1500;
            const check = name => { let r = null; links.check(url(name), answer => { r = answer; }); tryVerify(() => r !== null, 10000); return r; };
            const good = check("ok.ics");
            compare([good.ok, good.name, good.count], [true, "Test", 3]);
            const large = check("large.ics");
            compare(large.ok, false);
            compare(large.error, "This calendar file is larger than 1 MB; the island does not read files of that size.");
            const late = check("silent.ics");
            compare(late.ok, false);
            verify(late.error.indexOf("was not downloaded within 2 seconds") > 0, late.error);
        }

        function test_8_the_backend_says_which_link_failed_and_why() {
            calendar.sourcesJson = JSON.stringify([
                { id: "good", url: url("ok.ics"), name: "Good" }, { id: "large", url: url("large.ics"), name: "Large" },
                { id: "endless", url: url("endless.ics"), name: "Endless" }, { id: "late", url: url("stalls.ics"), name: "Late" }]);
            tryVerify(() => calendar.loaded, 15000);
            const status = JSON.parse(calendar.statusJson);
            compare(status.good.error, "");
            compare(status.large.error, "The file is larger than 1 MB");
            compare(status.endless.error, "The file is larger than 1 MB");
            compare(status.late.error, "Not downloaded within 2 seconds");
            compare(Object.keys(calendar.cache), [url("ok.ics")], "only the whole calendar is kept and parsed");
        }
    }
}
