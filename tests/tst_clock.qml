/*
    SPDX-License-Identifier: GPL-2.0-or-later

    How the island writes the time (Lang.timeFormat, Settings → General): as
    the system's region does, also while the island speaks another language,
    or always in 24 or 12 hours, made from the region's own short format.
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"

Item {
    id: root
    width: 200
    height: 60

    Clock { id: clock; running: false }

    TestCase {
        name: "Clock"
        when: windowShown

        function cleanup() { Lang.clockSetting = 0; Lang.setting = "auto"; }

        function test_1_made_24_or_12_hours() {
            const cases = [
                // [the region's short format, 24-hour, 12-hour]
                ["h:mm Ap", "HH:mm", "h:mm Ap"],
                ["h:mm AP", "HH:mm", "h:mm AP"],
                ["HH:mm", "HH:mm", "h:mm AP"],
                ["H:mm", "HH:mm", "h:mm AP"],
                ["AP h:mm", "HH:mm", "AP h:mm"],
                ["HH.mm", "HH.mm", "h.mm AP"],
                ["HH:mm:ss", "HH:mm", "h:mm AP"],
                ["HH.mm.ss", "HH.mm", "h.mm AP"],
                ["h:mm:ss AP", "HH:mm", "h:mm AP"],
                ["HH:mm:ss.zzz", "HH:mm", "h:mm AP"]
            ];
            for (const [format, h24, h12] of cases) {
                compare(Lang.shortTime(format, 0), format, "as the system: unchanged");
                compare(Lang.shortTime(format, 1), h24, format + " in 24 hours");
                compare(Lang.shortTime(format, 2), h12, format + " in 12 hours");
            }
        }

        function test_2_the_clock_follows_it() {
            clock.now = new Date(2026, 0, 1, 19, 41);
            const system = Qt.formatTime(clock.now, Qt.locale().timeFormat(Locale.ShortFormat));
            compare(clock.text, system, "the system's own format");
            // another language than the system's: the time is still the region's
            Lang.setting = Lang.systemLanguage === "tr" ? "en" : "tr";
            compare(clock.text, system);
            Lang.clockSetting = 1;
            compare(clock.text, "19:41");
            Lang.clockSetting = 2;
            verify(clock.text.startsWith("7:41"), clock.text);
            verify(!clock.text.includes("19"), clock.text);
        }
    }
}
