/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The settings window's own pieces: the folding parts (SettingsFold: made
    only when opened, remembered, with the keyboard), the search (SettingsIndex:
    every setting, by its name and place, in both languages; SettingsSearch:
    a result opens its part and shows it, or the switch that shows it), General's
    Response choice, every setting of the index found on its page, and the first
    opening's tour on the island (IslandTour).
    Skipped where KDE's settings modules are not installed. tools/run-tests runs
    it with a configuration folder of its own (SettingsMemory writes there).
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"

Item {
    id: root
    width: 820
    height: 1200

    Loader { id: general; anchors.fill: parent; source: "../org.phobby.dynamicisland/contents/ui/configGeneral.qml" }
    Loader { id: other; anchors.fill: parent; visible: false }

    Theme { id: islandTheme; follow: false }
    // What the tour writes to (the widget's configuration).
    QtObject {
        id: config
        property int islandLayout: 0
        property bool tourShown: false
        property bool showMediaModule: true
        property bool showSystemModule: true
        property bool showNotificationModule: true
        property bool showQuickSettings: true
        property bool showTools: true
        property bool showCalendar: true
        property bool showNotes: true
        property bool showClipboard: true
        property bool showWeather: true
        property bool showApps: true
        property bool showHabits: true
        property bool showAi: false
        property bool showCloud: false
    }
    Component {
        id: tourComponent
        IslandTour { width: 420; height: 230; theme: islandTheme; cfg: config }
    }

    TestCase {
        name: "SettingsUi"
        when: windowShown

        function walk(item, test) {
            if (!item) return null;
            if (test(item)) return item;
            for (const c of item.children || []) { const f = walk(c, test); if (f) return f; }
            if (item.item && item.item !== item) { const f = walk(item.item, test); if (f) return f; }
            return null;
        }
        function named(item, name) { return walk(item, i => i.objectName === name); }
        function fold(item, id) { return walk(item, i => i.objectName === "foldingSection" && i.foldId === id); }

        // Lower case, no accents, the Turkish i's as one: what is typed finds what is shown.
        function test_index_finds_by_name_and_place() {
            compare(SettingsIndex.fold("Görünüm İçin ılık"), "gorunum icin ilik");
            compare(SettingsIndex.find("", 10), []);
            const dot = SettingsIndex.find("dot size", 10);
            verify(dot.length > 0);
            compare([dot[0].key, dot[0].page, dot[0].needs], ["dotSize", "configGeneral", "dotMode"]);
            verify(dot[0].where.indexOf("General") === 0 && dot[0].where.indexOf("Dot mode details") > 0, dot[0].where);
            // by the page's name too, and all the words
            verify(SettingsIndex.find("cat sulks", 5).some(r => r.key === "catSulkSeconds"));
            verify(SettingsIndex.find("weather units", 5).some(r => r.key === "weatherUnits"), "a tab's page, also while its tab is off");
            // a key that is set through a list is found by the list's name
            verify(SettingsIndex.find("tabs", 5).some(r => r.key === "pageOrder"));
            // in Turkish, by the Turkish names
            Lang.setting = "tr";
            const tr = SettingsIndex.find(SettingsIndex.fold(Lang.i18n("Dot size:")).replace(/:$/, ""), 5);
            verify(tr.some(r => r.key === "dotSize"), "found in Turkish");
            verify(tr[0].where.indexOf(Lang.i18n("General")) === 0, tr[0].where);
            Lang.setting = "en";
            // every entry is somewhere the window has: a page of config.qml
            for (const entry of SettingsIndex.entries) verify(SettingsIndex.pages[entry.page] !== undefined, entry.key + " on " + entry.page);
        }

        // A folding part: nothing of it is made until it is opened; opened and closed with the
        // mouse or the keyboard; remembered; what was typed survives closing it.
        function test_fold_is_made_when_opened_and_remembered() {
            if (general.status !== Loader.Ready) skip("KDE's settings modules are not installed");
            // (a page made anew, with the part left closed)
            SettingsMemory.setOpen("general.details", false);
            other.source = "../org.phobby.dynamicisland/contents/ui/configGeneral.qml";
            other.visible = true;
            tryVerify(() => other.status === Loader.Ready);
            const page = other.item;
            const part = fold(page, "general.details");
            verify(part !== null);
            compare([part.expanded, part.made, part.item], [false, false, null], "closed: not made");
            compare(named(page, "setting-preferredPlayer"), null);
            const header = named(part, "foldHeader");
            mouseClick(header);
            verify(part.expanded);
            tryVerify(() => part.item !== null);
            verify(SettingsMemory.isOpen("general.details"), "remembered");
            compare(part.item.wideMode, part.twin.wideMode, "laid out as the page is from the start: nothing jumps as it opens");
            const field = named(page, "setting-preferredPlayer");
            verify(field !== null);
            field.text = "elisa"; field.textEdited();
            compare(page.cfg_preferredPlayer, "elisa");
            // the keyboard: Space on the focused header closes it; it is kept, not thrown away
            header.forceActiveFocus(Qt.TabFocusReason);
            keyClick(Qt.Key_Space);
            verify(!part.expanded);
            verify(!SettingsMemory.isOpen("general.details"));
            verify(part.made && part.item !== null, "kept");
            compare(field.text, "elisa");
            compare(header.Accessible.name, part.title);
            // made anew, the page opens it as it was left
            SettingsMemory.setOpen("general.details", true);
            other.source = "";
            other.source = "../org.phobby.dynamicisland/contents/ui/configGeneral.qml";
            tryVerify(() => other.status === Loader.Ready);
            verify(fold(other.item, "general.details").expanded, "remembered");
            SettingsMemory.setOpen("general.details", false);
            other.source = ""; other.visible = false;
        }

        // General → Response: three settings in one choice; values that match none are "Custom".
        function test_response_presets() {
            if (general.status !== Loader.Ready) skip("KDE's settings modules are not installed");
            const page = general.item;
            const combo = named(page, "setting-response");
            page.useResponse(1);
            compare([page.cfg_hoverDelay, page.cfg_collapseDelay, page.cfg_eventDuration, page.cfg_notificationDuration], [120, 400, 3000, 4000], "Balanced: a new island's");
            tryCompare(combo, "currentIndex", 1);
            compare([page.response, combo.count], [1, 3]);
            page.useResponse(0);
            compare([page.cfg_hoverDelay, page.cfg_collapseDelay, page.response], [300, 800, 0]);
            combo.activated(2);
            compare([page.cfg_hoverDelay, page.cfg_eventDuration, page.response], [50, 2000, 2]);
            page.cfg_hoverDelay = 70;
            tryCompare(combo, "currentIndex", 3);
            compare([page.response, combo.count], [-1, 4], "Custom");
            compare(combo.currentText, "Custom");
            page.useResponse(1);
        }

        // The search shows a setting: it opens the part it is in; one shown only while a switch is
        // on is shown by that switch while it is off.
        function test_search_reveals_and_opens_its_part() {
            if (general.status !== Loader.Ready) skip("KDE's settings modules are not installed");
            const page = general.item;
            const search = named(page, "settingsSearch") || page.header;
            verify(search !== null && search.reveal !== undefined);
            const part = fold(page, "general.dot");
            part.expanded = false;
            page.cfg_dotMode = false;
            search.reveal("dotSize");
            compare(search.revealing, "dotMode", "off: the switch that shows it");
            page.cfg_dotMode = true;
            search.reveal("dotSize");
            compare(search.revealing, "dotSize");
            tryVerify(() => part.expanded && named(page, "setting-dotSize") !== null, 3000, "its part opened");
            // typing finds it, Enter goes there
            const field = named(page, "settingsSearchField");
            field.forceActiveFocus();
            field.text = "dot size";
            verify(search.results.length > 0 && search.results[0].key === "dotSize");
            // Down to the results, Enter goes there (on this page: shown here, the field emptied)
            keyClick(Qt.Key_Down);
            const list = search.resultList;
            verify(list !== null && list.activeFocus, "the results take the keyboard");
            compare(list.currentIndex, 0);
            keyClick(Qt.Key_Return);
            compare([field.text, search.revealing], ["", "dotSize"]);
            field.forceActiveFocus();
            field.text = "dot";
            keyClick(Qt.Key_Escape);
            compare(field.text, "", "Escape empties it");
            page.cfg_dotMode = false;
        }

        // Every setting of the index is on its page: with the switches that show it on and every
        // part opened, a control named for it is there.
        function test_every_setting_of_the_index_is_on_its_page() {
            if (general.status !== Loader.Ready) skip("KDE's settings modules are not installed");
            const byPage = {};
            for (const e of SettingsIndex.entries) (byPage[e.page] = byPage[e.page] || []).push(e);
            let checked = 0;
            other.visible = true;
            for (const name in byPage) {
                other.source = "";
                other.source = "../org.phobby.dynamicisland/contents/ui/" + name + ".qml";
                tryVerify(() => other.status === Loader.Ready, 5000, name);
                const page = other.item;
                // (the oval layout's, the notch's, peeking's, a gradient's, following the system's: each as it is shown)
                // (and the light at the edge in a colour of its own, which has its colour button then)
                const variants = name === "configAppearance" ? [{ cfg_islandLayout: 0, cfg_fullscreenMode: 2, cfg_appearanceMode: 1, cfg_peekGlowColor: 2 },
                                                                { cfg_islandLayout: 1, cfg_fullscreenMode: 2, cfg_appearanceMode: 1, cfg_customStyle: JSON.stringify(Styles.defaults("aurora")) },
                                                                { cfg_islandLayout: 0, cfg_fullscreenMode: 2, cfg_appearanceMode: 0, cfg_peekGlowColor: 1 }] : [{}];
                const found = {};
                for (const v of variants) {
                    for (const e of byPage[name]) if (e.needs.length > 0) page["cfg_" + e.needs] = true;
                    for (const k in v) page[k] = v[k];
                    wait(20);
                    let parts = [];
                    const collect = item => { if (!item) return; if (item.objectName === "foldingSection") parts.push(item); for (const c of item.children || []) collect(c); if (item.item && item.item !== item) collect(item.item); };
                    collect(page);
                    for (const p of parts) p.open();
                    // (a part inside a part: once more)
                    wait(50); parts = []; collect(page); for (const p of parts) p.open();
                    for (const e of byPage[name]) {
                        const control = named(page, "setting-" + e.key);
                        if (control !== null && control.visible) found[e.key] = true;
                    }
                }
                for (const e of byPage[name]) { verify(found[e.key] === true, e.key + " on " + name); ++checked; }
            }
            compare(checked, SettingsIndex.entries.length);
            other.source = ""; other.visible = false;
            SettingsMemory.store.open = "{}";
        }

        // The first opening's tour: three steps, each choice written at once, the last tab stays on,
        // skipped or done it is not shown again.
        function test_tour() {
            config.tourShown = false; config.islandLayout = 0;
            const tour = createTemporaryObject(tourComponent, root);
            let finished = 0;
            tour.finished.connect(() => ++finished);
            compare(tour.step, 0);
            mouseClick(named(tour, "tourLayout1"));
            compare(config.islandLayout, 1, "the oval layout chosen");
            mouseClick(named(tour, "tourNext"));
            compare(tour.step, 1);
            // the tabs, in a room smaller than they take: they scroll there and never reach the buttons below
            tour.height = 180;
            wait(50);
            const tabs = named(tour, "tourTabs"), skip = named(tour, "tourSkip");
            verify(tabs.mapToItem(tour, 0, tabs.height).y <= skip.mapToItem(tour, 0, 0).y, "the tabs end above the buttons");
            verify(tabs.clip);
            tour.height = 230;
            mouseClick(named(tour, "tourTab-weather"));
            compare(config.showWeather, false, "a tab switched off");
            mouseClick(named(tour, "tourTab-weather"));
            compare(config.showWeather, true, "and on again");
            // all but one off: that one stays
            for (const p of tour.tabs) if (p.key !== "media") config[p.config] = false;
            mouseClick(named(tour, "tourTab-media"));
            compare(config.showMediaModule, true, "the last tab stays on");
            for (const p of tour.tabs) config[p.config] = !(p.key === "ai" || p.key === "cloud");
            mouseClick(named(tour, "tourBack"));
            compare(tour.step, 0);
            mouseClick(named(tour, "tourNext")); mouseClick(named(tour, "tourNext"));
            compare(tour.step, 2);
            compare(named(tour, "tourNext").text, "Done");
            mouseClick(named(tour, "tourNext"));
            compare([config.tourShown, finished], [true, 1]);
            // skipped at once: the same
            config.tourShown = false;
            const again = createTemporaryObject(tourComponent, root);
            mouseClick(named(again, "tourSkip"));
            compare(config.tourShown, true);
            // named for a screen reader
            compare([named(again, "tourSkip").Accessible.role, named(again, "tourSkip").Accessible.name], [Accessible.Button, "Skip"]);
            config.islandLayout = 0;
        }
    }
}
