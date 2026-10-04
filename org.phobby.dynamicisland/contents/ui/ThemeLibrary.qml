/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The user's own looks: theme files (ThemeFile.js, *.islandtheme.json) kept
    under ~/.local/share/dynamicisland/themes, one file per theme. They are
    read, written and deleted through the native core's LocalTools; without
    it (or with an older one) `available` is false and there are none.

    A file is only ever read as data: its size is checked before it is read,
    then ThemeFile.parse() takes the known fields and refuses the rest.
    Adding a theme never applies it.
*/
import QtQuick
import "ThemeFile.js" as ThemeFile

QtObject {
    id: library

    property var local: null                // LocalTools (LocalBridge.qml), or null
    readonly property bool available: local !== null && typeof local.writeTextFile === "function"
    // Where the themes are kept (tests point this somewhere else).
    property string directory: local !== null ? local.dataHome() + "/dynamicisland/themes" : ""
    // [{ file, name, author, description, style, keeps }] by name. `style` is a whole
    // style; `keeps` names what the file leaves to the user (see whole()).
    property var themes: []
    // Where the island sits and how large it is: a theme that does not say keeps the user's.
    readonly property var placement: ["top", "offsetX", "scale"]
    onAvailableChanged: reload()
    onDirectoryChanged: reload()

    function reload(): void {
        const found = [];
        if (available && directory.length > 0) {
            for (const file of local.listFiles(directory, ThemeFile.SUFFIX)) {
                const read = readFile(directory + "/" + file);
                if (read.ok) found.push(Object.assign({ file: file }, read.theme));
            }
        }
        found.sort((a, b) => a.name.localeCompare(b.name));
        themes = found;
    }
    function result(error: string, field: string): var { return { ok: false, theme: null, error: error, field: field }; }
    // The theme in a file anywhere: { ok, theme, error, field }; see explain().
    function readFile(path: string): var {
        if (!available) return result("native", "");
        const size = local.fileSize(path);
        if (size < 0) return result("missing", "");
        if (size > ThemeFile.MAX_BYTES) return result("size", "");
        return whole(ThemeFile.parse(local.readTextFile(path, ThemeFile.MAX_BYTES)));
    }
    // What ThemeFile.parse() read, its style made complete.
    function whole(read: var): var {
        if (!read.ok) return read;
        read.theme.keeps = placement.filter(key => read.theme.style[key] === undefined);
        read.theme.style = Styles.normalize(read.theme.style);
        return read;
    }
    // The style a theme gives an island that looks like `current` now.
    function applied(theme: var, current: var): var {
        const next = Object.assign({}, theme.style);
        for (const key of theme.keeps || []) next[key] = current[key];
        return Styles.normalize(next);
    }
    function find(name: string): var { return themes.find(t => ThemeFile.sameName(t.name, name)) ?? null; }
    // A name like `name` that no theme has yet: "Aurora", "Aurora 2", "Aurora 3"…
    function freeName(name: string): string {
        const base = String(name).trim().replace(/ \d+$/, "");
        for (let n = 2; ; ++n) if (find(base + " " + n) === null) return (base + " " + n).slice(0, 60);
    }
    // Adds a theme to the list (a file is written); it is not applied.
    // One of that name is only replaced when `replace` says so: else error "exists".
    function add(theme: var, replace: bool): var {
        if (!available) return result("native", "");
        const same = find(theme.name);
        if (same !== null && !replace) return result("exists", "");
        let file = same !== null ? same.file : "";
        if (file.length === 0) {
            const taken = local.listFiles(directory, ThemeFile.SUFFIX), base = ThemeFile.slug(theme.name);
            file = base + ThemeFile.SUFFIX;
            for (let n = 2; taken.indexOf(file) >= 0; ++n) file = base + "-" + n + ThemeFile.SUFFIX;
        }
        const style = Styles.normalize(theme.style);
        for (const key of theme.keeps || []) delete style[key];
        if (!local.writeTextFile(directory + "/" + file, ThemeFile.stringify(theme.name, theme.author, theme.description, style))) return result("write", "");
        reload();
        return { ok: true, theme: find(theme.name), error: "", field: "" };
    }
    function remove(file: string): bool {
        if (!available || !/^[a-z0-9-]+\.islandtheme\.json$/.test(file)) return false;
        const done = local.removeFile(directory + "/" + file);
        reload();
        return done;
    }
    // Writes a look as a theme file where the user chose; the name it was written under ("" = it could not be).
    function exportTo(path: string, name: string, author: string, description: string, style: var): string {
        if (!available || path.length === 0) return "";
        const target = path.slice(-ThemeFile.SUFFIX.length) === ThemeFile.SUFFIX ? path : path.replace(/(\.islandtheme)?(\.json)?$/, "") + ThemeFile.SUFFIX;
        return local.writeTextFile(target, ThemeFile.stringify(name, author, description, Styles.normalize(style))) ? target : "";
    }
    // "file:///home/…/a%20b.json" → "/home/…/a b.json"
    function pathOf(url: var): string {
        const text = String(url);
        return text.indexOf("file://") === 0 ? decodeURIComponent(text.slice(7)) : text;
    }
    // Why a file was not taken, in words.
    function explain(error: string, field: string): string {
        return error === "size" ? Lang.i18n("The file is larger than 64 kB: a theme is never that large.")
             : error === "json" ? Lang.i18n("The file is not a theme: it is not valid JSON.")
             : error === "object" || error === "schema" ? Lang.i18n("The file is not a theme of the island (no \"schema\" version).")
             : error === "newer" ? Lang.i18n("The theme was made for a newer version of the island.")
             : error === "name" ? Lang.i18n("The theme has no usable name (1 to 60 characters).")
             : error === "field" ? Lang.i18n("The theme does not fit the format: \"%1\" is not what it may be.", field)
             : error === "missing" ? Lang.i18n("The file could not be read.")
             : error === "write" ? Lang.i18n("The theme could not be saved.")
             : error === "native" ? Lang.i18n("Theme files need the native helper (install.sh builds it).")
             : error === "checksum" ? Lang.i18n("The download does not match the catalog's checksum; it was thrown away.")
             : error;
    }
}
