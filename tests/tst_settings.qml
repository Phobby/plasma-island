/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The settings pages, loaded as they are (outside a settings window there is
    no widget configuration to preview into: the pages work without it).
    Skipped where KDE's settings modules are not installed.
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"
import "../org.phobby.dynamicisland/contents/ui/Suggestions.js" as Suggestions

Item {
    id: root
    width: 820
    height: 1400

    Loader { id: appearance; anchors.fill: parent; source: "../org.phobby.dynamicisland/contents/ui/configAppearance.qml" }
    Loader { id: weather; anchors.fill: parent; visible: false; source: "../org.phobby.dynamicisland/contents/ui/configWeather.qml" }
    Loader { id: suggestions; anchors.fill: parent; visible: false; source: "../org.phobby.dynamicisland/contents/ui/configSuggestions.qml" }
    Loader { id: notes; anchors.fill: parent; visible: false; source: "../org.phobby.dynamicisland/contents/ui/configNotes.qml" }
    Loader { id: layout; anchors.fill: parent; visible: false; source: "../org.phobby.dynamicisland/contents/ui/configLayout.qml" }
    PageCatalog { id: pages }
    QtObject { id: stored; property string suggestionsData: ""; property string suggestionsAvailable: "" }

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

        function test_weather_place_and_units() {
            if (weather.status !== Loader.Ready) skip("KDE's settings modules are not installed");
            const page = weather.item;
            compare(page.place, null, "no place until one is chosen");
            verify(page.weather !== null);
            compare([page.weather.enabled, page.weather.requests], [false, 0], "the settings page fetches no weather and searches nothing by itself");
            page.pick({ name: "Tëstwick", admin: "Tëstwick", country: "Exampleland", latitude: 12.34567, longitude: 45.67891 });
            compare(JSON.parse(page.cfg_weatherLocation), { name: "Tëstwick", admin: "Tëstwick", country: "Exampleland", latitude: 12.34567, longitude: 45.67891 });
            compare(page.place.name, "Tëstwick");
            page.cfg_weatherLocation = "";
            compare(page.place, null);
            page.cfg_weatherUnits = 1;
            compare(page.cfg_weatherUnits, 1);
            compare(page.weather.requests, 0);
        }

        function test_suggestions_rules_modes_and_forgetting() {
            if (suggestions.status !== Loader.Ready) skip("KDE's settings modules are not installed");
            const page = suggestions.item, store = page.learnedStore;
            // not the user's own file: what is learned goes to a stand-in for the settings here
            store.local = null;
            store.cfg = stored;
            page.reload();
            compare(page.learned, Suggestions.empty());
            compare(page.status("meeting"), "Asks");
            // what the island learned meanwhile
            let s = Suggestions.empty();
            const at = new Date(2026, 9, 5, 9, 0).getTime();
            for (let i = 0; i < 3; ++i) s = Suggestions.answer(Suggestions.shown(s, "call", at + i * 600000), "call", "later").state;
            s = Suggestions.answer(Suggestions.shown(s, "battery", at), "battery", "never").state;
            for (let i = 0; i < 5; ++i) s = Suggestions.answer(Suggestions.shown(s, "headphones", at), "headphones", "timeout").state;
            stored.suggestionsData = Suggestions.text(s);
            page.reload();
            compare(page.status("call"), "Asks, at most once in 1 hour · Yes: 0 · Not now or no answer: 3");
            compare(page.status("battery"), "Off: you chose “Never suggest this”");
            compare(page.status("headphones"), "Off: not answered five times in a row · Yes: 0 · Not now or no answer: 5");
            // the rule's switch and mode
            page.change(Suggestions.setMode(page.learned, "battery", "suggest"));
            compare([page.status("battery"), Suggestions.parse(stored.suggestionsData).rules.battery.mode], ["Asks", "suggest"], "written at once");
            page.change(Suggestions.setMode(page.learned, "meeting", "auto"));
            compare(page.status("meeting"), "Automatic: done without asking, with an Undo");
            page.change(Suggestions.setMode(page.learned, "meeting", "off"));
            compare(page.status("meeting"), "Off");
            // one rule forgotten, then all of them
            page.change(Suggestions.reset(page.learned, "call"));
            compare([page.status("call"), page.learned.rules.headphones.mode], ["Asks", "off"]);
            page.change(Suggestions.empty());
            compare(stored.suggestionsData, Suggestions.text(Suggestions.empty()));
            for (const id of Suggestions.RULES) compare(page.status(id), "Asks", id);
            // a rule this system cannot make says so
            stored.suggestionsAvailable = "";
            compare(page.available, Suggestions.RULES, "not known yet: all are offered");
            compare([page.cfg_suggestionsEnabled !== undefined, page.cfg_suggestionGapMinutes !== undefined], [true, true]);
            wait(100);
        }

        function test_notes_carry_on_switch() {
            if (notes.status !== Loader.Ready) skip("KDE's settings modules are not installed");
            const page = notes.item;
            page.cfg_notesResume = true;
            compare(page.cfg_notesResume, true);
            page.cfg_notesResume = false;
            compare(page.cfg_notesResume, false);
        }

        // The AI tab among the tabs: off until switched on, in its place, movable like the others.
        function test_layout_the_ai_tab() {
            compare(pages.pages.find(p => p.key === "ai").config, "showAi");
            // an order saved before the tab existed: it takes its place after Notes
            compare(pages.normalize("media,control,notes,clipboard,devices").join(","),
                    "activities,media,control,weather,notifications,quicksettings,apps,tools,habits,calendar,notes,ai,clipboard,devices");
            // and where the user put it, it stays
            const moved = pages.normalize("ai,media,notes");
            verify(moved.indexOf("ai") < moved.indexOf("media") && moved.indexOf("media") < moved.indexOf("notes"), moved.join(","));
            if (layout.status !== Loader.Ready) skip("KDE's settings modules are not installed");
            const page = layout.item;
            compare(page.cfg_showAi, false, "off until the user switches it on");
            page.cfg_showMediaModule = true;
            const before = page.shownTabs;
            page.cfg_showAi = true;
            compare(page.shownTabs, before + 1);
            page.cfg_pageOrder = "ai,media,control";
            compare(page.cfg_pageOrder, "ai,media,control");
            compare(page.info("ai").title, "AI");
            page.cfg_showAi = false;
            compare(page.shownTabs, before);
            wait(100);
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
