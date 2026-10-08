/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Theme files on disk (ThemeLibrary) and the store (ThemeStore), with the
    native module's LocalTools and a catalog served on 127.0.0.1
    (tests/catalog-server.py). Everything is written under tests/.run/.
    Skipped when the native module is not built (./install.sh builds it).
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"
import "../org.phobby.dynamicisland/contents/ui/ThemeFile.js" as ThemeFile

Item {
    id: root
    width: 200
    height: 100

    Loader { id: tools; source: "../org.phobby.dynamicisland/contents/ui/LocalBridge.qml" }
    readonly property var local: tools.status === Loader.Ready ? tools.item : null
    readonly property string here: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, ""))
    readonly property string run: here + "/.run/" + Math.floor(Math.random() * 1e9).toString(36)

    ThemeLibrary { id: library; local: root.local; directory: root.run + "/themes" }
    ThemeStore { id: store; catalogUrl: "" }

    TestCase {
        name: "Themes"
        when: windowShown

        readonly property var look: Styles.normalize(Object.assign(Styles.defaults("oxygen"), {
            fill: "gradient", gradientType: "linear", gradientAngle: 45, gradientStops: ["#102030", "#405060", "#708090"],
            opacity: 61, radius: 40, scale: 110, top: 12, control: "#ff8800", text: "#fefefe", shadow: 0, borderWidth: 3 }))
        property int port: 0
        property var written: []

        function write(path, text) { verify(root.local.writeTextFile(path, text), path); written.push(path); }
        function log() { return root.local.readTextFile(root.run + "/requests.log").split("\n").filter(l => l.length > 0); }
        function serve() {
            let answer = null;
            root.local.run("python3", [root.here + "/catalog-server.py", "--dir", root.run + "/catalog", "--log", root.run + "/requests.log", "--lifetime", "40"],
                           (code, out, err) => { answer = { code: code, out: out, err: err }; });
            tryVerify(() => answer !== null, 10000);
            compare(answer.code, 0, answer.err);
            port = Number(answer.out.trim());
            verify(port > 0);
        }
        function browse() {
            store.browse();
            tryVerify(() => store.state === "ready" || store.state === "error", 25000);
        }
        function download(entry) {
            let result = null;
            store.download(entry, r => { result = r; });
            tryVerify(() => result !== null, 25000);
            return result;
        }
        function entry(id) { return store.entries.find(e => e.id === id); }

        function initTestCase() {
            if (root.local === null || !library.available) skip("the native module is not built: ./install.sh");
        }
        function cleanupTestCase() {
            if (root.local === null) return;
            if (port > 0) { const x = new XMLHttpRequest(); x.open("GET", "http://127.0.0.1:" + port + "/__quit"); x.send(); wait(200); }
            for (const file of root.local.listFiles(library.directory)) root.local.removeFile(library.directory + "/" + file);
            for (const path of written) root.local.removeFile(path);
            root.local.removeFile(root.run + "/requests.log");
        }

        function test_1_export_then_add_back() {
            compare(library.themes.length, 0);
            // exported under a name, to where the user chose
            const path = library.exportTo(root.run + "/out/My Look", "My Look", "Me", "What I like.", look);
            compare(path, root.run + "/out/My Look.islandtheme.json");
            written.push(path);
            verify(root.local.fileSize(path) > 300);
            const text = root.local.readTextFile(path);
            compare(JSON.parse(text).schema, 1);
            compare(Object.keys(JSON.parse(text)), ["schema", "name", "author", "description", "style"]);
            compare(library.themes.length, 0, "exporting adds nothing to the list");

            // …the settings are reset; the file is added again
            const read = library.readFile(path);
            compare([read.ok, read.error], [true, ""]);
            const added = library.add(read.theme, false);
            compare(added.ok, true);
            compare(library.themes.length, 1);
            const theme = library.themes[0];
            compare([theme.name, theme.author, theme.description], ["My Look", "Me", "What I like."]);
            compare(theme.style, look, "every setting came back");
            compare(theme.file, "my-look.islandtheme.json");
            compare(root.local.listFiles(library.directory), ["my-look.islandtheme.json"]);
        }

        function test_2_same_name_asks_first() {
            const again = { name: " my look ", author: "", description: "", style: Styles.defaults("ocean") };
            const refused = library.add(again, false);
            compare([refused.ok, refused.error], [false, "exists"]);
            compare(library.themes[0].style, look, "nothing was overwritten");
            // rename
            compare(library.freeName("My Look"), "My Look 2");
            compare(library.add(Object.assign({}, again, { name: library.freeName("My Look") }), false).ok, true);
            compare(library.themes.map(t => t.name), ["My Look", "My Look 2"]);
            compare(library.freeName("My Look 2"), "My Look 3");
            // overwrite
            compare(library.add(again, true).ok, true);
            compare(library.themes.length, 2);
            compare(library.find("MY LOOK").style, Styles.defaults("ocean"));
            compare(library.find("My Look").file, "my-look.islandtheme.json", "the same file");
            // two names that would be the same file
            compare(library.add({ name: "A!", author: "", description: "", style: look }, false).ok, true);
            compare(library.add({ name: "a?", author: "", description: "", style: look }, false).ok, true);
            compare([library.find("A!").file, library.find("a?").file], ["a.islandtheme.json", "a-2.islandtheme.json"]);
        }

        function test_3_own_themes_can_be_deleted() {
            const before = library.themes.length;
            verify(library.remove(library.find("a?").file));
            compare(library.themes.length, before - 1);
            compare(library.find("a?"), null);
            compare(library.remove("../../etc/passwd"), false);
            compare(library.remove("nothing-here.islandtheme.json"), false);
        }

        function test_4_files_that_are_no_themes_are_refused() {
            const bad = root.run + "/bad/";
            write(bad + "broken.islandtheme.json", '{ "schema": 1, "name": "Broken", "style": {');
            write(bad + "huge.islandtheme.json", ThemeFile.stringify("Huge", "", "", look) + " ".repeat(70000));
            write(bad + "wrong.islandtheme.json", JSON.stringify({ schema: 1, name: "Wrong", style: { opacity: 500 } }));
            write(bad + "script.islandtheme.json", "import QtQuick\nItem { Component.onCompleted: Qt.quit() }");
            write(bad + "newer.islandtheme.json", JSON.stringify({ schema: 2, name: "Newer", style: {} }));
            const before = library.themes.length;
            const verdict = name => { const r = library.readFile(bad + name + ".islandtheme.json"); return [r.ok, r.error, r.field]; };
            compare(verdict("broken"), [false, "json", ""]);
            compare(verdict("huge"), [false, "size", ""]);
            compare(verdict("wrong"), [false, "field", "style.opacity"]);
            compare(verdict("script"), [false, "json", ""]);
            compare(verdict("newer"), [false, "newer", ""]);
            compare(verdict("not-there"), [false, "missing", ""]);
            compare(library.themes.length, before);
            for (const e of ["size", "json", "schema", "newer", "name", "missing", "write", "native", "checksum"]) verify(library.explain(e, "").length > 20, e);
            verify(library.explain("field", "style.opacity").indexOf("style.opacity") > 0);
            // a broken file dropped into the themes folder by hand is simply not listed
            write(library.directory + "/zzz-broken.islandtheme.json", "{");
            library.reload();
            compare(library.themes.length, before);
        }

        function test_5_store_asks_nothing_until_it_is_opened() {
            const catalog = root.run + "/catalog/";
            const good = ThemeFile.stringify("Dusk", "Someone", "From the store.", Styles.defaults("sunset"));
            const sum = text => ThemeFile.sha256(ThemeFile.utf8Encode(text));
            const invalid = JSON.stringify({ schema: 1, name: "Invalid", style: { scale: 900 } });
            write(catalog + "themes/dusk.islandtheme.json", good);
            write(catalog + "themes/tampered.islandtheme.json", good.replace("Someone", "Someone else"));
            write(catalog + "themes/huge.islandtheme.json", good + " ".repeat(70000));
            write(catalog + "themes/invalid.islandtheme.json", invalid);
            write(catalog + "index.json", JSON.stringify({ schema: 1, themes: [
                { id: "dusk", name: "Dusk", author: "Someone", description: "From the store.", path: "themes/dusk.islandtheme.json", sha256: sum(good),
                  preview: { fill: "gradient", gradientStops: ["#c2410c", "#6b21a8"] } },
                { id: "tampered", name: "Tampered", path: "themes/tampered.islandtheme.json", sha256: sum(good) },
                { id: "huge", name: "Huge", path: "themes/huge.islandtheme.json", sha256: sum(good + " ".repeat(70000)) },
                { id: "invalid", name: "Invalid", path: "themes/invalid.islandtheme.json", sha256: sum(invalid) },
                { id: "gone", name: "Gone", path: "themes/gone.islandtheme.json", sha256: sum(good) },
                { id: "outside", name: "Outside", path: "../requests.log", sha256: sum(good) }
            ] }));
            serve();
            store.catalogUrl = "http://127.0.0.1:" + port;
            verify(store.configured);
            // the library was read, themes were added and listed: the store was never asked
            library.reload();
            wait(400);
            compare(log(), []);
            compare([store.requests, store.state], [0, ""]);

            browse();
            compare([store.state, store.error], ["ready", ""]);
            compare(log(), ["GET /index.json"]);
            compare(store.entries.map(e => e.id), ["dusk", "tampered", "huge", "invalid", "gone"], "an entry that points outside the catalog is left out");
            compare(entry("dusk").preview, { fill: "gradient", gradientStops: ["#c2410c", "#6b21a8"] });
            wait(300);
            compare(log().length, 1, "listing downloads no theme");
        }

        function test_6_download_checks_size_checksum_and_format() {
            const before = library.themes.length;
            // the checksum matches: the theme is handed over, not added and not applied
            const dusk = download(entry("dusk"));
            compare([dusk.ok, dusk.error], [true, ""]);
            compare([dusk.theme.name, dusk.theme.author, dusk.theme.keeps], ["Dusk", "Someone", []]);
            compare(dusk.theme.style, Styles.defaults("sunset"));
            compare(library.themes.length, before, "downloading alone adds nothing");
            compare(log()[log().length - 1], "GET /themes/dusk.islandtheme.json");
            compare(library.add(dusk.theme, false).ok, true);
            compare(library.find("Dusk").style, Styles.defaults("sunset"));

            // not what the catalog promised
            const tampered = download(entry("tampered"));
            compare([tampered.ok, tampered.error, tampered.theme], [false, "checksum", null]);
            const huge = download(entry("huge"));
            compare([huge.ok, huge.error], [false, "size"]);
            const invalid = download(entry("invalid"));
            compare([invalid.ok, invalid.error, invalid.field], [false, "field", "style.scale"]);
            const gone = download(entry("gone"));
            compare(gone.ok, false);
            verify(gone.error.indexOf("404") > 0, gone.error);
            compare(library.themes.length, before + 1);
            compare(Object.keys(store.busy).length, 0);
            compare(store.requests, log().length, "every request is in the server's log");
        }

        function test_7_offline_says_so() {
            const requests = log().length;
            const x = new XMLHttpRequest(); x.open("GET", "http://127.0.0.1:" + port + "/__quit"); x.send();
            wait(500);
            browse();
            compare(store.state, "error");
            verify(store.error.indexOf("No connection") === 0, store.error);
            const dusk = download({ id: "dusk", path: "themes/dusk.islandtheme.json", sha256: "0".repeat(64) });
            compare(dusk.ok, false);
            verify(dusk.error.indexOf("No connection") === 0, dusk.error);
            port = 0;
            // the placeholder address: nothing is asked at all
            const made = store.requests;
            store.catalogUrl = "https://raw.githubusercontent.com/OWNER/REPOSITORY/BRANCH/catalog";
            compare(store.configured, false);
            store.browse();
            compare([store.state, store.requests], ["error", made]);
            verify(store.error.length > 0);
        }
    }
}
