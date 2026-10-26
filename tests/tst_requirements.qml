/*
    SPDX-License-Identifier: GPL-2.0-or-later

    What a feature needs and says when it is missing (RequirementCatalog,
    Requirements, RequirementCard, RequirementNotice, Settings → Diagnostics):
    every entry says what is missing, why, and how to get it; what was looked
    for is kept until "Check again" and not looked for at every question;
    without the native module nothing is looked for, a connected BetterNotes
    is not forgotten and the buttons that would start a program are dimmed;
    the diagnostics copied for a bug report hold neither the user's name nor
    the computer's nor the home folder (checked against this computer's real
    ones, which are never printed).
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"
import "../org.phobby.dynamicisland/contents/ui/backend"

Item {
    id: root
    width: 520
    height: 700

    // A stand-in for the native module's LocalTools: counts how often it is asked.
    QtObject {
        id: fakeLocal
        property int asked: 0
        property var onPath: ({})
        function findExecutable(name) { ++asked; return onPath[name] || ""; }
        function locate(name, given, useGiven) { ++asked; return { path: onPath[name] || "", via: onPath[name] ? "path" : "", given: "", givenUsable: false }; }
    }
    Loader { id: tools; source: "../org.phobby.dynamicisland/contents/ui/LocalBridge.qml" }
    readonly property var realLocal: tools.status === Loader.Ready ? tools.item : null

    Theme { id: islandTheme; follow: false }
    RequirementCard { id: card; width: 480; height: 260; theme: islandTheme; property int rechecked: 0; onRecheck: ++rechecked }
    RequirementNotice { id: notice; width: 480; visible: false }
    NotesBackend { id: bare; core: null; enabled: false }
    Loader { id: diagnostics; active: false; width: 820; height: 1600; source: "../org.phobby.dynamicisland/contents/ui/configDiagnostics.qml" }
    PlasmaBackend { id: plasma }
    Component { id: controls; QuickSettingsPage { theme: islandTheme; core: null; backend: plasma } }

    TestCase {
        name: "Requirements"
        when: windowShown

        function init() { Requirements.recheck(); fakeLocal.asked = 0; fakeLocal.onPath = {}; }
        function texts(item) {
            const out = [];
            (function walk(i) { if (i.visible !== false && typeof i.text === "string" && i.text.length > 0) out.push(i.text); for (const c of i.children) walk(c); })(item);
            return out.join(" | ");
        }

        function test_every_entry_says_what_why_and_how() {
            for (const id of RequirementCatalog.order) {
                const it = RequirementCatalog.item(id);
                verify(it !== null, id);
                verify(it.name.length > 0 && it.what.length > 0 && it.why.length > 0 && String(it.features).length > 0, id + ": what, why, for what");
                verify(String(it.link).indexOf("https://") === 0, id + ": its page");
                // (one sentence, as asked: no paragraph)
                verify(it.why.split(". ").length <= 2, id + ": why is one sentence");
                const installs = RequirementCatalog.installs(id);
                if (id !== "agy" && id !== "dropbox") verify(installs.length > 0, id + ": a command to copy");
                for (const i of installs) verify(i.command.length > 0, id + ": " + i.distro);
            }
            // the native module: built by install.sh from the island's own page, packages per distribution
            const distros = RequirementCatalog.buildPackages.map(p => p.distro).join(",");
            compare(distros, "Kubuntu / Debian,Fedora,Arch");
            verify(RequirementCatalog.installCommand.indexOf(RequirementCatalog.repoUrl + ".git") >= 0, "cloned from Project.js's address");
            verify(RequirementCatalog.item("native").link.indexOf(RequirementCatalog.repoUrl) === 0);
        }

        function test_looked_for_once_until_check_again() {
            fakeLocal.onPath = { rclone: "/usr/bin/rclone" };
            compare(Requirements.find(fakeLocal, "rclone").path, "/usr/bin/rclone");
            const asked = fakeLocal.asked;
            for (let i = 0; i < 5; ++i) Requirements.find(fakeLocal, "rclone");
            compare(fakeLocal.asked, asked, "not asked again");
            // missing is kept too: a poll does not look again
            compare(Requirements.find(fakeLocal, "dropbox").found, false);
            const missing = fakeLocal.asked;
            Requirements.find(fakeLocal, "dropbox");
            compare(fakeLocal.asked, missing);
            // installed meanwhile: "Check again"
            fakeLocal.onPath = { rclone: "/usr/bin/rclone", dropbox: "/usr/bin/dropbox" };
            compare(Requirements.find(fakeLocal, "dropbox").found, false, "kept until asked to look again");
            Requirements.recheck();
            compare(Requirements.find(fakeLocal, "dropbox").found, true);
        }
        function test_without_the_native_module_nothing_is_looked_for() {
            const r = Requirements.find(null, "claude");
            compare([r.found, r.native], [false, false]);
            compare(Requirements.find(null, "native").found, false);
            compare(Requirements.find(fakeLocal, "native").found, true);
        }

        function test_the_card() {
            for (const id of RequirementCatalog.order) {
                card.requirement = id;
                wait(10);
                const shown = texts(card);
                verify(shown.indexOf(RequirementCatalog.item(id).what) >= 0, id + ": what");
                verify(shown.indexOf(RequirementCatalog.item(id).why) >= 0, id + ": why");
                const first = RequirementCatalog.installs(id)[0];
                if (first) verify(shown.indexOf(first.command) >= 0, id + ": the command");
            }
            card.requirement = "native";
            wait(10);
            const shown = texts(card);
            verify(shown.indexOf("sudo apt install") >= 0 && shown.indexOf("install.sh") >= 0, "packages, then install.sh");
            verify(shown.indexOf("Everything else of the island works without it.") >= 0);
            // "Set the path by hand" only where the island can open the settings
            compare(findChild(card, "requirementPath").visible, false);
            const generation = Requirements.generation;
            mouseClick(findChild(card, "requirementRecheck"));
            compare([card.rechecked, Requirements.generation], [1, generation + 1]);
            // a case of the page's own
            card.requirement = "ollama"; card.title = "Ollama is not running"; card.command = "ollama serve";
            wait(10);
            verify(texts(card).indexOf("ollama serve") >= 0 && texts(card).indexOf("Ollama is not running") >= 0);
            card.title = ""; card.command = "";
        }
        function test_the_notice() {
            for (const id of RequirementCatalog.order) {
                notice.requirement = id;
                verify(notice.item !== null, id);
            }
        }

        function test_without_the_native_module_a_connected_betternotes_stays() {
            let said = null;
            bare.localDrivers.betternotes.list({ id: "bn-1", type: "betternotes" }, "local", (error, found) => said = error);
            verify(said !== null && said !== "missing" && said.length > 0, "a message, not \"uninstalled\" (which would forget the source)");
        }
        function test_without_the_native_module_buttons_that_start_a_program_are_dimmed() {
            const page = createTemporaryObject(controls, root);
            compare(page.has("spectacle"), false);
            verify(findChild(page, "nativeMissingLine") !== null);
        }

        function test_diagnostics_copied_without_who_or_where() {
            if (root.realLocal === null || typeof root.realLocal.systemInfo !== "function") skip("needs the native module built from this checkout");
            diagnostics.active = true;
            tryCompare(diagnostics, "status", Loader.Ready);
            const page = diagnostics.item;
            page.look();
            tryVerify(() => Object.keys(page.rows).length === RequirementCatalog.order.length, 5000);
            wait(500);
            const text = page.reportText();
            const real = root.realLocal.systemInfo();
            verify(text.indexOf("Dynamic Island diagnostics") === 0);
            // (the real values are compared here and never printed)
            const has = value => String(value).length >= 3 && text.toLowerCase().indexOf(String(value).toLowerCase()) >= 0;
            verify(!has(real.home), "the home folder is left out");
            verify(!has(real.user), "the user's name is left out");
            verify(!has(real.host), "the computer's name is left out");
            verify(text.indexOf("native module: loaded") >= 0);
            diagnostics.active = false;
        }
    }
}
