/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The settings pages, loaded as they are (outside a settings window there is
    no widget configuration to preview into: the pages work without it).
    Skipped where KDE's settings modules are not installed.
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"

Item {
    id: root
    width: 820
    height: 1400

    Loader { id: appearance; anchors.fill: parent; source: "../org.phobby.dynamicisland/contents/ui/configAppearance.qml" }

    TestCase {
        name: "Settings"
        when: windowShown

        function test_appearance_solid_and_gradient_looks() {
            if (appearance.status !== Loader.Ready) skip("KDE's settings modules are not installed");
            const page = appearance.item;
            page.cfg_appearanceMode = 1;
            page.cfg_customStyle = JSON.stringify(Styles.defaults("aurora"));
            compare([page.gradient, page.style.gradientStops.length], [true, 3]);
            // From a gradient look to a solid one and back, drawn in between: the row of
            // colour buttons hides and shows while its colours change (this used to crash).
            for (const preset of ["oxygen", "sunset", "glass", "ocean", "contrast", "midnight", "breezeLight", "aurora"]) {
                page.choosePreset(preset);
                wait(120);
                compare(page.style.preset, preset);
                compare(page.gradient, Styles.defaults(preset).fill === "gradient");
            }
            // two colours, three colours, each of them changed
            page.setThirdStop(false);
            compare(page.style.gradientStops, ["#047857", "#6d28d9"]);
            page.setThirdStop(true);
            compare(page.style.gradientStops, ["#047857", Styles.mixHex("#047857", "#6d28d9", 0.5), "#6d28d9"]);
            page.setStop(1, "#ffffff");
            page.setStop(2, "#000000");
            compare(page.style.gradientStops, ["#047857", "#ffffff", "#000000"]);
            page.set("gradientAngle", 45);
            page.set("gradientType", "radial");
            compare(JSON.parse(page.cfg_customStyle).gradientType, "radial", "what is edited is what would be stored");
            wait(120);
            // a gradient that was edited stays when the solid colour changes; an untouched one follows it
            page.set("fill", "solid");
            page.set("background", "#aa0000");
            compare(page.style.gradientStops[0], "#047857");
            page.choosePreset("oxygen");
            page.set("background", "#aa0000");
            compare(page.style.gradientStops[0], "#aa0000");
            wait(120);
        }
    }
}
