/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The top of every settings page: a search over every setting of every
    page (SettingsIndex), also those inside a folded "Details" part and on
    the pages of tabs that are switched off. A result goes to its page
    (SettingsNav), opens the part it is in and shows it (`reveal`, also
    when the page is opened from the island: SettingsJump is part of it).

    Keyboard: type, Down to the results, Enter to go; Escape empties it.

        header: SettingsSearch { page: page; pageName: "configGeneral" }
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: search
    objectName: "settingsSearch"

    // The page it is the top of (a KCM.SimpleKCM) and its file name without ".qml".
    required property var page
    required property string pageName
    // Whether a setting asked for is shown by this (false: the page shows it itself, by its own
    // SettingsNav.take and reveal: Diagnostics' rows).
    property bool revealHere: true

    spacing: 0

    // (the list of results, in the popup: for tests, which do not find it among the page's items)
    readonly property alias resultList: list
    readonly property var results: field.text.trim().length === 0 ? [] : SettingsIndex.find(field.text, 12)

    function go(entry: var): void {
        field.text = "";
        popup.close();
        if (entry.page !== search.pageName) SettingsNav.go(search, entry.page, entry.key);
        else if (revealHere) reveal(entry.key);
        else SettingsNav.go(search, entry.page, entry.key);
    }

    // ---- showing a setting on this page ------------------------------------------------
    function findNamed(item: var, name: string): var {
        if (!item) return null;
        if (item.objectName === name && item.visible !== false) return item;
        const kids = item.children || [];
        for (let i = 0; i < kids.length; ++i) { const f = findNamed(kids[i], name); if (f) return f; }
        // (a Loader's item, a Flickable's content)
        if (item.item && item.item !== item) { const f = findNamed(item.item, name); if (f) return f; }
        return null;
    }
    function foldWith(item: var, key: string): var {
        if (!item) return null;
        if (item.objectName === "foldingSection" && Array.isArray(item.keys) && item.keys.indexOf(key) >= 0) return item;
        const kids = item.children || [];
        for (let i = 0; i < kids.length; ++i) { const f = foldWith(kids[i], key); if (f) return f; }
        if (item.item && item.item !== item) { const f = foldWith(item.item, key); if (f) return f; }
        return null;
    }
    property string revealing: ""
    property int tries: 0
    function reveal(key: string): void {
        if (key.trim().length === 0) return;
        // (a setting shown only while a switch is on: that switch, while it is off)
        const entry = SettingsIndex.entries.find(e => e.page === search.pageName && e.key === key);
        if (entry && entry.needs.length > 0 && search.page["cfg_" + entry.needs] !== undefined && !search.page["cfg_" + entry.needs]) key = entry.needs;
        revealing = key;
        tries = 0;
        revealTimer.restart();
    }
    Timer {
        id: revealTimer
        interval: 60
        onTriggered: {
            const key = search.revealing, root = search.page.flickable ? search.page.flickable.contentItem : search.page;
            const fold = search.foldWith(root, key);
            if (fold !== null && !fold.expanded) fold.open();
            const target = search.findNamed(root, "setting-" + key);
            if (target === null || target.width === 0) {
                if (++search.tries < 30) restart();
                return;
            }
            const f = search.page.flickable;
            if (f) {
                const y = target.mapToItem(f.contentItem, 0, 0).y;
                f.contentY = Math.max(0, Math.min(f.contentHeight - f.height, y - f.height / 3));
            }
            const at = target.mapToItem(f ? f.contentItem : search.page, 0, 0);
            glow.parent = f ? f.contentItem : search.page;
            glow.x = at.x - Kirigami.Units.smallSpacing; glow.y = at.y - Kirigami.Units.smallSpacing;
            glow.width = target.width + 2 * Kirigami.Units.smallSpacing; glow.height = target.height + 2 * Kirigami.Units.smallSpacing;
            glow.opacity = 1;
            fade.restart();
            if (target.activeFocusOnTab !== false && typeof target.forceActiveFocus === "function") target.forceActiveFocus(Qt.OtherFocusReason);
        }
    }
    // (where the setting is: lit for a moment)
    Rectangle {
        id: glow
        z: 100
        radius: Kirigami.Units.cornerRadius
        color: Qt.alpha(Kirigami.Theme.highlightColor, 0.18)
        border.width: 1
        border.color: Kirigami.Theme.highlightColor
        opacity: 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
        Timer { id: fade; interval: 2200; onTriggered: glow.opacity = 0 }
    }
    Connections {
        target: SettingsNav
        enabled: search.revealHere
        function onRevealRequested(page, key) { if (page === search.pageName) { SettingsNav.take(page); search.reveal(key); } }
    }
    Component.onCompleted: if (revealHere) Qt.callLater(() => { const key = SettingsNav.take(search.pageName); if (key.trim().length > 0) search.reveal(key); })

    // ---- the field ------------------------------------------------------------------
    SettingsJump {}
    Kirigami.SearchField {
        id: field
        objectName: "settingsSearchField"
        Layout.fillWidth: true
        Layout.margins: Kirigami.Units.smallSpacing
        Layout.bottomMargin: 0
        placeholderText: Lang.i18n("Search all settings…")
        Accessible.name: Lang.i18n("Search all settings")
        onTextChanged: if (text.trim().length > 0) popup.open(); else popup.close()
        // (the list takes the keyboard: the popup has to take it first, and gives it back when it closes)
        Keys.onDownPressed: if (search.results.length > 0) { popup.focus = true; popup.open(); list.forceActiveFocus(); list.currentIndex = 0; }
        Keys.onReturnPressed: if (search.results.length > 0) search.go(search.results[0])
        Keys.onEnterPressed: if (search.results.length > 0) search.go(search.results[0])
        Keys.onEscapePressed: event => { if (text.length > 0) { text = ""; event.accepted = true; } else event.accepted = false; }
    }
    Kirigami.Separator { Layout.fillWidth: true; Layout.topMargin: Kirigami.Units.smallSpacing }

    QQC2.Popup {
        id: popup
        y: field.y + field.height + Kirigami.Units.smallSpacing
        x: field.x
        width: field.width
        height: Math.max(Kirigami.Units.gridUnit * 2, Math.min(list.contentHeight + 2 * padding, Kirigami.Units.gridUnit * 18))
        padding: 1
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutsideParent
        focus: false
        onClosed: focus = false
        contentItem: ListView {
            id: list
            objectName: "settingsSearchResults"
            clip: true
            model: search.results
            keyNavigationEnabled: true
            Keys.onReturnPressed: if (currentIndex >= 0) search.go(search.results[currentIndex])
            Keys.onEnterPressed: if (currentIndex >= 0) search.go(search.results[currentIndex])
            Keys.onUpPressed: event => { if (currentIndex <= 0) field.forceActiveFocus(); else event.accepted = false; }
            Keys.onEscapePressed: { field.text = ""; field.forceActiveFocus(); }
            delegate: QQC2.ItemDelegate {
                id: row
                required property var modelData
                required property int index
                width: ListView.view.width
                highlighted: ListView.isCurrentItem
                Accessible.name: modelData.label + ", " + modelData.where
                onClicked: search.go(modelData)
                contentItem: ColumnLayout {
                    spacing: 0
                    QQC2.Label { textFormat: Text.PlainText; Layout.fillWidth: true; text: row.modelData.label; elide: Text.ElideRight }
                    QQC2.Label {
                        textFormat: Text.PlainText
                        Layout.fillWidth: true
                        text: row.modelData.where
                        elide: Text.ElideRight
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                    }
                }
            }
            QQC2.Label {
                textFormat: Text.PlainText
                anchors.centerIn: parent
                visible: list.count === 0
                text: Lang.i18n("No setting matches.")
                opacity: 0.7
            }
        }
    }
}
