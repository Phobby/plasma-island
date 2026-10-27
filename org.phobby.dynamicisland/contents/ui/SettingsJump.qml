/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The island asked for a page of the settings (a card's "Set the path by
    hand", a message's click): it wrote settingsJump ("<page>:<key>") before
    it opened this window. The first page to load reads it, empties it and
    goes there (SettingsNav). Each settings page has one (SettingsSearch); it
    also hands SettingsNav the window's pages.
*/
import QtQuick
import org.kde.plasma.plasmoid

Item {
    id: jump
    function widget(): var { try { return Plasmoid.configuration; } catch (e) { return null; } }
    // (the window's pages, for SettingsNav: seen from a page, not from a singleton)
    Component.onCompleted: {
        if (typeof configDialog !== "undefined" && configDialog && configDialog.configModel) SettingsNav.model = configDialog.configModel;
    }
    // (a moment after the page is made; a page closed at once takes nothing: the timer goes with it)
    Timer { interval: 0; running: true; onTriggered: jump.take() }
    function take(): void {
        const c = widget();
        const target = c ? String(c.settingsJump || "") : "";
        if (target.length === 0) return;
        c.settingsJump = "";
        const at = target.indexOf(":");
        SettingsNav.go(jump, at < 0 ? target : target.slice(0, at), at < 0 ? "" : target.slice(at + 1));
    }
}
