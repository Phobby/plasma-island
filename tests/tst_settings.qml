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

        // Export the look, reset the settings, bring the file back with "Add New…".
        function test_theme_file_through_the_page() {
            if (appearance.status !== Loader.Ready) skip("KDE's settings modules are not installed");
            const page = appearance.item, library = page.themeLibrary, dialog = page.themeDialog;
            if (!library.available) skip("the native module is not built: ./install.sh");
            const run = decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "")) + ".run/" + Math.floor(Math.random() * 1e9).toString(36);
            library.directory = run + "/themes";
            compare(library.themes.length, 0);
            page.cfg_appearanceMode = 1;
            const mine = Styles.normalize(Object.assign(Styles.defaults("glass"), { fill: "gradient", gradientStops: ["#7c2d12", "#134e4a"], gradientAngle: 60, radius: 55, scale: 108 }));
            page.use(mine);
            const path = library.exportTo(run + "/out/Copper", "Copper", "Me", "", page.style);
            verify(path.length > 0);

            page.choosePreset("oxygen");
            dialog.open();
            dialog.take(path);
            compare(library.themes.map(t => t.name), ["Copper"], "in the list under its own name");
            compare(dialog.added.name, "Copper");
            verify(Styles.same(dialog.added.style, mine), "with its settings");
            verify(!Styles.same(page.style, mine), "added, not applied");
            compare(page.activeTheme, null);
            // "Apply"
            dialog.chosen(dialog.added);
            verify(Styles.same(page.style, mine));
            compare([page.activeTheme.name, page.style.scale], ["Copper", 108]);
            wait(100);
            // a theme that says nothing about place and size (as the store's do) leaves them
            const look = { name: "Look", author: "", description: "", style: Styles.defaults("ocean"), keeps: ["top", "offsetX", "scale"] };
            compare(library.add(look, false).ok, true);
            compare(JSON.parse(library.local.readTextFile(library.directory + "/look.islandtheme.json")).style.scale, undefined);
            page.applyTheme(library.find("Look"));
            compare([page.style.preset, page.style.scale, page.activeTheme.name], ["ocean", 108, "Look"]);
            verify(library.remove(library.find("Look").file));
            page.applyTheme(library.find("Copper"));

            // the same file again: asked first, nothing overwritten meanwhile
            dialog.take(path);
            compare([dialog.pending.name, dialog.added, library.themes.length], ["Copper", null, 1]);
            dialog.overwrite();
            compare([dialog.pending, dialog.added.name, library.themes.length], [null, "Copper", 1]);
            // what is no theme says why and adds nothing
            library.local.writeTextFile(run + "/out/broken.islandtheme.json", "{ nope");
            dialog.take(run + "/out/broken.islandtheme.json");
            verify(dialog.problem.length > 0);
            compare([dialog.added, library.themes.length], [null, 1]);

            // the store's tab with the placeholder address: nothing is asked
            compare(page.themeStore.requests, 0);
            dialog.section = 1;
            compare([page.themeStore.configured, page.themeStore.state, page.themeStore.requests], [false, "error", 0]);
            dialog.close();

            // an own theme can be deleted, a ready-made look has nothing to delete
            verify(library.remove(library.find("Copper").file));
            compare([library.themes.length, page.activeTheme], [0, null]);
            for (const file of ["Copper.islandtheme.json", "broken.islandtheme.json"]) library.local.removeFile(run + "/out/" + file);
            wait(100);
        }
    }
}
