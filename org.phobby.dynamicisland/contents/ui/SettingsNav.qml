/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Going to a setting from anywhere in the settings window: from the search
    (SettingsSearch.qml), from a "see there" link, and from the island (a
    card's "Set the path by hand": the island writes settingsJump, the window
    goes there when it opens).

    `go(from, page, key)`: `from` is any item of the page shown (to find the
    window), `page` a page's file name without ".qml" (configDiagnostics),
    `key` the setting (or "" for the page). The page shown is applied first
    when it has changes, as Apply would (Plasma's own window would otherwise
    forget them). The page that opens finds `pending` (reveal()): it opens
    the folding part the setting is in and shows it.

    Plasma's settings window (AppletConfiguration.qml of the shell) has no
    interface for this: its `open(category)` and `saveConfig()` are used,
    found by walking up from the page; `configDialog.configModel` holds the
    pages of config.qml (handed in by each page's SettingsJump). Outside that
    window (tests) nothing happens.
*/
pragma Singleton
import QtQuick

QtObject {
    id: nav

    // The setting the next page is to show ("" = none), and which page it is on.
    property string pending: ""
    property string pendingPage: ""
    // Raised when a page is asked to show `pending` (the page may already be the one shown).
    signal revealRequested(string page, string key)
    // The window's pages (config.qml): handed in by SettingsJump, which every page has; the window's
    // `configDialog` is not seen from here.
    property var model: null

    function windowRoot(from: var): var {
        for (let item = from; item; item = item.parent)
            if (typeof item.open === "function" && typeof item.saveConfig === "function" && typeof item.isConfigurationChanged === "function") return item;
        return null;
    }
    function pages(): var {
        const out = [];
        if (!nav.model) return out;
        for (let i = 0; i < nav.model.count; ++i) out.push(nav.model.get(i));
        return out;
    }
    function category(page: string): var {
        return pages().find(c => String(c.source).replace(/^.*\//, "") === page + ".qml") || null;
    }
    function shownPage(from: var): string {
        const root = windowRoot(from);
        return root ? String(root.currentSource).replace(/^.*\//, "").replace(/\.qml$/, "") : "";
    }
    // Whether the window can go there (tests and other windows cannot).
    function canGo(from: var, page: string): bool { return windowRoot(from) !== null && category(page) !== null; }

    function go(from: var, page: string, key: string): bool {
        const root = windowRoot(from), target = category(page);
        pending = key;
        pendingPage = page;
        if (root === null || target === null) { revealRequested(page, key); return false; }
        if (shownPage(from) === page) { revealRequested(page, key); return true; }
        // (Plasma's window forgets what was changed on the page it leaves: it is applied, as Apply does)
        if (root.isConfigurationChanged()) root.saveConfig();
        root.open(target);
        return true;
    }
    // Called by a page when it is ready: whether it is the one asked for, and which setting.
    function take(page: string): string {
        if (pendingPage !== page) return "";
        const key = pending;
        pending = ""; pendingPage = "";
        return key.length > 0 ? key : " ";
    }
}
