/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Notes: the connected notes apps, where quick notes go, how often the
    notes are fetched, and whether the page carries on in the note that was
    open. Apps are connected on the island's Notes page; their tokens are
    kept in KDE Wallet and removed when an app is disconnected.
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property string cfg_language
    Binding { target: Lang; property: "setting"; value: cfg_language; restoreMode: Binding.RestoreNone }

    property alias cfg_showNotes: enableCheck.checked
    property alias cfg_notesRefreshMinutes: refreshSpin.value
    property alias cfg_notesResume: resumeCheck.checked
    property string cfg_notesSources: "[]"
    property string cfg_notesDefault: ""

    readonly property var typeNames: ({ joplin: "Joplin", simplenote: "Simplenote", memos: "Memos", betternotes: "BetterNotes" })
    readonly property var sources: {
        try {
            const list = JSON.parse(cfg_notesSources || "[]");
            return Array.isArray(list) ? list.filter(s => s && typeof s.id === "string") : [];
        } catch (e) { return []; }
    }
    function label(s: var): string {
        return (s.name || typeNames[s.type] || s.type) + (s.user ? " · " + s.user : s.server ? " · " + s.server : s.type === "betternotes" ? " · " + Lang.i18n("this computer only") : "");
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.FormLayout {
            Layout.fillWidth: true
            QQC2.CheckBox {
                id: enableCheck
                Kirigami.FormData.label: Lang.i18n("Notes:")
                text: Lang.i18n("Show the Notes page in the island")
            }
            QQC2.ComboBox {
                id: defaultCombo
                Kirigami.FormData.label: Lang.i18n("Quick notes go to:")
                enabled: enableCheck.checked && page.sources.length > 0
                Layout.preferredWidth: Kirigami.Units.gridUnit * 16
                model: page.sources.map(s => page.label(s))
                currentIndex: Math.max(0, page.sources.findIndex(s => s.id === page.cfg_notesDefault))
                onActivated: index => page.cfg_notesDefault = page.sources[index].id
            }
            QQC2.SpinBox {
                id: refreshSpin
                Kirigami.FormData.label: Lang.i18n("Fetch notes:")
                enabled: enableCheck.checked
                from: 1
                to: 60
                textFromValue: value => Lang.i18np("every minute", "every %1 minutes", value)
                valueFromText: text => parseInt(text.replace(/\D+/g, "")) || 1
            }
            QQC2.CheckBox {
                id: resumeCheck
                Kirigami.FormData.label: Lang.i18n("When the page opens:")
                enabled: enableCheck.checked
                text: Lang.i18n("Carry on in the note that was being edited")
            }
            QQC2.Label {
                textFormat: Text.PlainText
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                wrapMode: Text.Wrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                text: Lang.i18n("Also after the island closed or the shell restarted, with the unsaved draft. Only which note it was is remembered, never its text. A locked note asks for its password each time; the password is never kept.")
            }
        }

        Kirigami.Heading {
            textFormat: Text.PlainText
            level: 4
            text: Lang.i18n("Connected notes apps")
        }
        QQC2.Label {
            textFormat: Text.PlainText
            Layout.fillWidth: true
            visible: page.sources.length === 0
            wrapMode: Text.Wrap
            opacity: 0.7
            text: Lang.i18n("No notes app is connected yet. Open the Notes page in the island to connect Joplin, Simplenote, Memos or BetterNotes.")
        }
        Repeater {
            model: page.sources
            delegate: RowLayout {
                id: row
                required property var modelData
                Layout.fillWidth: true
                QQC2.Label {
                    textFormat: Text.PlainText
                    Layout.fillWidth: true
                    text: page.label(row.modelData)
                    elide: Text.ElideMiddle
                }
                QQC2.Button {
                    icon.name: "list-remove"
                    text: Lang.i18n("Disconnect")
                    onClicked: {
                        page.cfg_notesSources = JSON.stringify(page.sources.filter(s => s.id !== row.modelData.id));
                        if (page.cfg_notesDefault === row.modelData.id) page.cfg_notesDefault = "";
                    }
                }
            }
        }
        QQC2.Label {
            textFormat: Text.PlainText
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            opacity: 0.7
            text: Lang.i18n("Changes take effect when you press \"Apply\". Disconnecting an app also deletes its sign-in from KDE Wallet.")
        }
    }
}
