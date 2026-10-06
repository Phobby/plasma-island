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
    Loader { id: ai; anchors.fill: parent; visible: false; source: "../org.phobby.dynamicisland/contents/ui/configAi.qml" }
    Loader { id: cloud; anchors.fill: parent; visible: false; source: "../org.phobby.dynamicisland/contents/ui/configCloud.qml" }
    Loader { id: cat; anchors.fill: parent; visible: false; source: "../org.phobby.dynamicisland/contents/ui/configCat.qml" }
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
            const at = new Date(2026, 9, 5, 9, 0).getTime(), day = 86400000;
            page.clock = () => at + 6 * day;
            page.reload();
            compare(page.learned, Suggestions.empty());
            compare([page.status("meeting"), page.status("headphones")], ["Asks; nothing learned yet", "Off: experimental, its trigger is a guess"]);
            // what the island learned meanwhile
            let s = Suggestions.empty();
            for (let i = 0; i < 5; ++i) s = Suggestions.record(s, "meeting", "wd|am|cal:Work|video", "yes", at + i * day).state;
            s = Suggestions.automatic(s, "meeting", "wd|am|cal:Work|video", true, at + 5 * day);
            s = Suggestions.record(s, "meeting", "wd|am|cal:Work|video", "auto", at + 5 * day).state;
            for (let i = 0; i < 2; ++i) s = Suggestions.record(s, "meeting", "we|eve", "no", at + i * day).state;
            s = Suggestions.never(Suggestions.record(s, "call", "wd|am|out:hp", "shown", at).state, "call");
            stored.suggestionsData = Suggestions.text(s);
            page.reload();
            compare(page.status("call"), "Off: you turned this rule off");
            verify(page.status("meeting").indexOf("Learning: welcome ") === 0);
            const contexts = Suggestions.contexts(page.learned, "meeting", page.now(), page.tuning);
            compare(contexts.map(c => page.contextLine("meeting", c).replace(/ \(.*$/, "")),
                    ["Weekdays · morning · Work · with a video link: automatic", "Weekend · evening: does not ask"]);
            compare(page.weekText(), "Last 7 days: 1 shown · 5 accepted · 1 done automatically");
            verify(page.logLine(page.learned.log[0]).indexOf(" · Do Not Disturb before an event · Weekdays · morning · Work · with a video link") > 0);
            // a rule's mode
            page.change(Suggestions.setMode(page.learned, "call", "learn"));
            compare([page.status("call"), Suggestions.parse(stored.suggestionsData).rules.call.mode], ["Asks; nothing learned yet", "learn"], "written at once");
            page.change(Suggestions.setMode(page.learned, "recording", "auto"));
            compare(page.status("recording"), "Automatic: done without asking, with an Undo");
            page.change(Suggestions.setMode(page.learned, "recording", "ask"));
            compare(page.status("recording"), "Always asks");
            // one context forgotten, one rule, then all of them
            page.change(Suggestions.forget(page.learned, "meeting", "we|eve"));
            compare(Suggestions.contexts(page.learned, "meeting", page.now(), page.tuning).length, 1);
            page.change(Suggestions.reset(page.learned, "meeting"));
            compare([page.status("meeting"), page.learned.rules.recording.mode], ["Asks; nothing learned yet", "ask"]);
            page.exportAll();
            verify(page.exported.indexOf('"v": 2') >= 0, "without the native module the export is shown");
            page.change(Suggestions.empty());
            compare(stored.suggestionsData, Suggestions.text(Suggestions.empty()));
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
                    "activities,media,control,weather,notifications,quicksettings,apps,tools,habits,calendar,notes,ai,cloud,clipboard");
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

        function test_ai_sources_models_and_limits() {
            if (ai.status !== Loader.Ready) skip("KDE's settings modules are not installed");
            const page = ai.item;
            compare([page.cfg_showAi, page.cfg_aiKeepHistory, page.sources.length], [false, false, 0], "off, nothing kept, nothing connected");
            page.cfg_aiSources = JSON.stringify([
                { id: "claude-cli-1", kind: "claude-cli", server: "", model: "" },
                { id: "local-1", kind: "local", server: "http://192.168.1.20:8080/v1", model: "llama" },
                { id: "anthropic-1", kind: "anthropic", server: "", model: "claude-test" },
                { id: "gone-1", kind: "a-kind-of-another-version", server: "", model: "" }]);
            compare(page.sources.map(s => page.label(s)), ["Claude Code", "Local model server · 192.168.1.20", "Anthropic API"], "a kind this version does not know is left out");
            compare(page.hasClaudeCode, true);
            // the model of a source, typed
            page.setModel("claude-cli-1", " sonnet ");
            compare(JSON.parse(page.cfg_aiSources).map(s => s.model), ["sonnet", "llama", "claude-test"]);
            page.setModel("claude-cli-1", "");
            compare(JSON.parse(page.cfg_aiSources)[0], { id: "claude-cli-1", kind: "claude-cli", server: "", model: "" });
            // the default, and disconnecting it
            page.cfg_aiDefault = "anthropic-1";
            page.remove("anthropic-1");
            compare([JSON.parse(page.cfg_aiSources).map(s => s.id), page.cfg_aiDefault], [["claude-cli-1", "local-1"], ""]);
            verify(page.cfg_aiSources.indexOf("key") < 0, "nothing of a key is ever in the settings");
            // the limits are numbers within their bounds
            page.cfg_aiMaxTokens = 999999;
            page.cfg_aiMaxChars = 1;
            compare([page.cfg_aiMaxTokens, page.cfg_aiMaxChars], [8192, 200]);
            page.cfg_aiMaxTokens = 2048; page.cfg_aiMaxChars = 4000;
            page.cfg_aiNotify = false; page.cfg_aiKeepHistory = true; page.cfg_showAi = true;
            compare([page.cfg_aiNotify, page.cfg_aiKeepHistory, page.cfg_showAi], [false, true, true]);
            // what Claude Code is run with is said and cannot be set
            let note = null;
            (function walk(item) { if (item.objectName === "claudeCodeNote") note = item; for (const c of item.children) walk(c); })(page);
            verify(note !== null && note.text.indexOf("tools are off, text answers only") > 0 && note.text.indexOf("cannot be changed") > 0);
            wait(100);
        }

        function test_cloud_tab_clouds_and_limits() {
            compare(pages.pages.find(p => p.key === "cloud").config, "showCloud");
            verify(pages.normalize("media,notes,clipboard").join(",").indexOf("notes,ai,cloud,clipboard") > 0, "its place among the tabs");
            if (cloud.status !== Loader.Ready) skip("KDE's settings modules are not installed");
            const page = cloud.item;
            compare([page.cfg_showCloud, layout.status === Loader.Ready ? layout.item.cfg_showCloud : false], [false, false], "off until the user switches it on");
            // a cloud hidden, and given a name of one's own
            page.remotes = [{ name: "drive", type: "drive" }, { name: "db", type: "dropbox" }];
            page.setHidden("drive", true); page.setHidden("db", true); page.setHidden("drive", false);
            compare(JSON.parse(page.cfg_cloudHidden), ["db"]);
            page.setAlias("drive", "  Work  "); page.setAlias("db", "db");
            compare(JSON.parse(page.cfg_cloudAliases), { drive: "Work" });
            page.setAlias("drive", "");
            compare(page.cfg_cloudAliases, "{}");
            // where sync state comes from is said, and that it is unknown when nothing says it
            page.clients = { dropbox: false, syncthing: false };
            compare([page.syncSource(page.remotes[0]), page.syncSource(page.remotes[1])], ["", ""]);
            page.clients = { dropbox: true, syncthing: false };
            compare([page.syncSource(page.remotes[0]), page.syncSource(page.remotes[1])], ["", "Dropbox"]);
            // the limits stay within their bounds
            page.cfg_cloudWarnPercent = 5; page.cfg_cloudCacheMB = 1; page.cfg_cloudAlertPauseHours = 9999;
            compare([page.cfg_cloudWarnPercent, page.cfg_cloudCacheMB, page.cfg_cloudAlertPauseHours], [50, 50, 168]);
            let how = null;
            (function walk(item) { if (item.objectName === "howTo") how = item; for (const c of item.children) walk(c); })(page);
            verify(how !== null && how.text.indexOf("rclone config reconnect NAME:") > 0 && how.text.indexOf("https://rclone.org/install.sh") > 0);
            wait(100);
        }

        // Export the look, reset the settings, bring the file back with "Add New…".
        // The Cat page: its preview is the cat itself, with what is set before it is applied.
        function test_cat_preview_coats_and_the_gallery() {
            if (cat.status !== Loader.Ready) skip("KDE's settings modules are not installed");
            const page = cat.item;
            const find = name => { let found = null; const walk = i => { if (found === null && i.objectName === name) found = i; for (const c of i.children) walk(c); if (i.contentItem) walk(i.contentItem); }; walk(page); return found; };
            // as the settings window hands them in
            page.cfg_catEnabled = true; page.cfg_catSide = 0; page.cfg_catSize = 130; page.cfg_catFur = "grey"; page.cfg_catFurColor = "#c9a27c";
            page.cfg_catMusic = true; page.cfg_catThoughts = true; page.cfg_catEvents = true; page.cfg_catPetting = true; page.cfg_catClicks = true;
            page.cfg_catNoAnger = false; page.cfg_catSulkSeconds = 10; page.cfg_catSleepSeconds = 20; page.cfg_catDot = 0; page.cfg_catReduceMotion = false;
            cat.visible = true;
            wait(150);
            const figure = find("catPreview"), mind = page.previewMind, stage = find("catStage");
            verify(figure !== null && mind !== null && stage !== null);
            compare([figure.visible, figure.fur, figure.mirrored, mind.body, mind.active], [true, "grey", false, "sit", true]);
            // size and side show at once
            const small = figure.height;
            page.cfg_catSize = 180;
            verify(figure.height > small * 1.3);
            page.cfg_catSide = 2;
            compare(figure.mirrored, true);
            page.cfg_catSide = 0;
            // each coat, and a colour of one's own
            for (const coat of ["orange", "black", "white", "tuxedo"]) {
                const button = find("coat-" + coat);
                mouseClick(button, button.width / 2, button.height / 2);
                compare([page.cfg_catFur, figure.fur], [coat, coat]);
                wait(40);
            }
            page.cfg_catFur = "custom"; page.cfg_catFurColor = "#3366aa";
            compare(Qt.colorEqual(figure.furFill, "#3366aa"), true);
            // what the island would tell it, tried here
            stage.playing = true;
            compare([mind.body, mind.accessory], ["listen", "headphones"]);
            stage.thinking = true;
            compare([mind.bubble, mind.tilt], ["dots", true]);
            stage.playing = false; stage.thinking = false;
            page.cfg_catMusic = false; stage.playing = true;
            compare(mind.accessory, "", "a reaction switched off here is off in the preview");
            stage.playing = false; page.cfg_catMusic = true;
            // it can be clicked
            mouseClick(figure, figure.width * 0.6, figure.height * 0.75);
            compare(mind.body, "curious");
            // reduced motion
            page.cfg_catReduceMotion = true;
            compare([mind.still, figure.still], [true, true]);
            page.cfg_catReduceMotion = false;
            // switched off: no cat, and nothing of it runs
            page.cfg_catEnabled = false;
            compare([figure.visible, mind.active, mind.timer.running], [false, false, false]);
            page.cfg_catEnabled = true;
            // the gallery in the preview's place, and back
            const button = find("catGalleryButton");
            mouseClick(button, button.width / 2, button.height / 2);
            compare([page.gallery, mind.active, figure.running], [true, false, false]);
            wait(300);
            verify(stage.height > small * 3, "the gallery has room");
            mouseClick(button, button.width / 2, button.height / 2);
            compare([page.gallery, mind.active], [false, true]);
            cat.visible = false;
        }

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
