/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Styles and Theme: the gradient fill, its presets and what it does to the
    automatic text colour. Run by tools/run-tests:

      QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/tst_appearance.qml
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"

Item {
    id: root
    width: 200
    height: 100

    Theme { id: theme; follow: false }

    TestCase {
        name: "Appearance"

        function styled(preset, changes) { return Styles.normalize(Object.assign(Styles.defaults(preset), changes || {})); }
        function use(preset, changes) { theme.style = styled(preset, changes); }
        function gradient(stops, changes) { use("oxygen", Object.assign({ fill: "gradient", gradientStops: stops }, changes || {})); }

        function test_where_it_sits() {
            const placed = Qt.createQmlObject('import "../org.phobby.dynamicisland/contents/ui"; Theme { systemTop: 20; systemOffsetX: -30 }', root);
            placed.style = styled("oxygen", { top: 9, offsetX: 70 });
            compare([placed.topOffset, placed.offsetX], [20, -30], "following the system: its own place");
            placed.follow = false;
            compare([placed.topOffset, placed.offsetX], [9, 70], "a custom style: the style's");
            placed.destroy();
        }

        function test_following_the_system_as_it_comes_and_tuned() {
            const t = Qt.createQmlObject('import "../org.phobby.dynamicisland/contents/ui"; Theme {}', root);
            // as it always was
            compare([t.scale, t.roundness, t.borderWidth, t.shadowLevel, t.blurWanted, t.blurLevel], [1, 1, 1, 1, true, 1]);
            fuzzyCompare(t.alpha, 0.92, 0.001);
            t.blurActive = true;
            fuzzyCompare(t.alpha, 0.82, 0.001);
            t.systemStyle = Styles.parseFollow(JSON.stringify({ opacity: 40, blur: false, scale: 110, radius: 50, border: false, shadow: 0, background: "#ff0000", top: 30 }));
            compare([t.scale, t.roundness, t.borderWidth, t.shadowLevel, t.blurWanted], [1.1, 0.5, 0, 0, false]);
            fuzzyCompare(t.alpha, 0.4, 0.001);
            compare(t.material, "flat", "the look itself stays the system's");
            // what cannot be read is as it comes; what is out of range is brought into it
            compare(Styles.parseFollow("nonsense"), Styles.followDefaults());
            compare(Styles.parseFollow("[1]"), Styles.followDefaults());
            const odd = Styles.parseFollow(JSON.stringify({ scale: 500, radius: -3, shadow: "x", blur: "yes", opacity: -20 }));
            compare([odd.scale, odd.radius, odd.shadow, odd.blur, odd.opacity], [120, 0, 1, true, -1]);
            t.destroy();
        }

        function test_solid_presets_are_what_they_were() {
            for (const preset of ["oxygen", "breezeDark", "breezeLight", "glass", "contrast"]) {
                const s = Styles.defaults(preset);
                compare(s.fill, "solid", preset);
                compare(s.gradientStops.length, 2, preset);
                use(preset);
                compare(theme.gradientFill, false, preset);
                verify(Qt.colorEqual(theme.base, s.background), preset + ": the base is the background");
            }
        }

        function test_gradient_fields_are_normalized() {
            const s = styled("oxygen", { fill: "gradient", gradientType: "radial", gradientAngle: 500, gradientStops: ["#102030", "#405060", "#708090"] });
            compare([s.fill, s.gradientType, s.gradientAngle, s.gradientStops], ["gradient", "radial", 360, ["#102030", "#405060", "#708090"]]);
            // what cannot be a gradient keeps the style's own
            const bad = styled("oxygen", { fill: "stripes", gradientType: "conic", gradientAngle: "x", gradientStops: ["#102030", "red"] });
            compare([bad.fill, bad.gradientType, bad.gradientAngle], ["solid", "linear", 135]);
            compare(bad.gradientStops, Styles.stopsFor(bad));
            compare(styled("oxygen", { gradientStops: ["#102030"] }).gradientStops.length, 2, "one colour is no gradient");
            compare(styled("oxygen", { gradientStops: ["#111111", "#222222", "#333333", "#444444"] }).gradientStops.length, 2, "four are too many");
            // an untouched gradient starts from the solid colours
            compare(styled("oxygen", { background: "#ff0000", control: "#0000ff", gradientStops: undefined }).gradientStops, ["#ff0000", Styles.mixHex("#ff0000", "#0000ff", 0.45)]);
            compare(Styles.mixHex("#000000", "#ffffff", 0.5), "#808080");
            // stored and read back
            compare(Styles.parse(JSON.stringify(s), null), s);
            verify(Styles.same(s, JSON.parse(JSON.stringify(s))));
        }

        function test_gradient_presets() {
            const presets = ["aurora", "sunset", "ocean", "midnight"];
            verify(presets.every(p => Styles.order.indexOf(p) >= 0));
            for (const preset of presets) {
                const s = Styles.defaults(preset);
                compare(s.fill, "gradient", preset);
                verify(s.gradientStops.length >= 2 && s.gradientStops.every(Styles.isColor), preset);
                verify(Styles.title(preset).length > 0 && Styles.title(preset) !== preset, preset + " has a name");
                use(preset);
                verify(theme.gradientFill);
                verify(theme.dark, preset + ": light text");
                verify(theme.gradientContrast >= 4.5, preset + ": the text reads on every colour, " + theme.gradientContrast.toFixed(2));
                compare(theme.gradientUneven, false);
                compare(theme.gradientBody.length, 3);
            }
        }

        function test_text_follows_the_average_brightness() {
            // dark: light text
            gradient(["#101827", "#3b1d60"]);
            verify(theme.dark);
            verify(theme.luminance(theme.text) > 0.8);
            // light: dark text
            gradient(["#fde68a", "#fbcfe8", "#bae6fd"]);
            verify(!theme.dark);
            verify(theme.luminance(theme.text) < 0.05);
            verify(theme.gradientContrast >= 4.5);
            // the average is the mean luminance of the gradient, not of its ends alone
            gradient(["#000000", "#ffffff"]);
            let sum = 0;
            for (let i = 0; i < 200; ++i) sum += theme.luminance(theme.gradientAt((i + 0.5) / 200));
            fuzzyCompare(theme.luminance(theme.gradientAverage), sum / 200, 0.01);
            verify(Qt.colorEqual(theme.base, theme.gradientAverage));
            // three colours: the middle one counts
            gradient(["#000000", "#ffffff", "#000000"]);
            const three = theme.luminance(theme.base);
            gradient(["#000000", "#000000", "#000000"]);
            verify(three > theme.luminance(theme.base) + 0.1);
            // a text colour of one's own is kept
            gradient(["#101827", "#3b1d60"], { text: "#ffcc00" });
            verify(Qt.colorEqual(theme.text, "#ffcc00"));
        }

        function test_very_light_and_very_dark_parts_warn() {
            gradient(["#ffffff", "#000000"]);
            verify(theme.gradientUneven, "white to black: " + theme.gradientContrast.toFixed(2));
            gradient(["#fef3c7", "#111827", "#fef3c7"]);
            verify(theme.gradientUneven);
            gradient(["#1e3a8a", "#0b1026"]);
            verify(!theme.gradientUneven);
            // a solid fill never does
            use("breezeLight");
            compare([theme.gradientUneven, theme.gradientContrast], [false, 21]);
        }

        function test_readability_correction_works_on_the_average() {
            for (const stops of [["#047857", "#0e7490", "#6d28d9"], ["#fde68a", "#fbcfe8"], ["#7f1d1d", "#1e3a8a"]]) {
                gradient(stops);
                for (const c of [theme.red, theme.orange, theme.live, theme.blue, theme.purple]) {
                    const fixed = theme.readable(c, theme.surface);
                    verify(theme.contrast(fixed, theme.surface) >= 4.5 || theme.luminance(fixed) > 0.98 || theme.luminance(fixed) < 0.005,
                           stops.join(" ") + ": " + theme.contrast(fixed, theme.surface).toFixed(2));
                }
                verify(theme.contrast(theme.text, theme.surface) >= 4.5);
                verify(theme.contrast(theme.control, theme.surface) >= 3);
            }
        }

        function test_opacity_applies_to_the_gradient() {
            gradient(["#047857", "#6d28d9"], { opacity: 40 });
            for (const c of theme.gradientBody) fuzzyCompare(c.a, 0.4, 0.01);
            verify(Qt.colorEqual(Qt.rgba(theme.gradientBody[0].r, theme.gradientBody[0].g, theme.gradientBody[0].b, 1), "#047857"));
            verify(Qt.colorEqual(Qt.rgba(theme.gradientBody[2].r, theme.gradientBody[2].g, theme.gradientBody[2].b, 1), "#6d28d9"));
            // following the system: no gradient, whatever the stored style says
            theme.follow = true;
            compare(theme.gradientFill, false);
            theme.follow = false;
        }
    }
}
