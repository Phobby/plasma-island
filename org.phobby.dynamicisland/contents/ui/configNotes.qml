/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Notes: the connected notes apps, where quick notes go and how often the
    notes are fetched. Apps are connected on the island's Notes page; their
    tokens are kept in KDE Wallet and removed when an app is disconnected.
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property alias cfg_showNotes: enableCheck.checked
    property alias cfg_notesRefreshMinutes: refreshSpin.value
    property string cfg_notesSources: "[]"
    property string cfg_notesDefault: ""

    readonly property var typeNames: ({ joplin: "Joplin", simplenote: "Simplenote", memos: "Memos" })
    readonly property var sources: {
        try {
            const list = JSON.parse(cfg_notesSources || "[]");
            return Array.isArray(list) ? list.filter(s => s && typeof s.id === "string") : [];
        } catch (e) { return []; }
    }
    function label(s: var): string {
        return (s.name || typeNames[s.type] || s.type) + (s.user ? " · " + s.user : s.server ? " · " + s.server : "");
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.FormLayout {
            Layout.fillWidth: true
            QQC2.CheckBox {
                id: enableCheck
                Kirigami.FormData.label: i18n("Notes:")
                text: i18n("Show the Notes page in the island")
            }
            QQC2.ComboBox {
                id: defaultCombo
                Kirigami.FormData.label: i18n("Quick notes go to:")
                enabled: enableCheck.checked && page.sources.length > 0
                Layout.preferredWidth: Kirigami.Units.gridUnit * 16
                model: page.sources.map(s => page.label(s))
                currentIndex: Math.max(0, page.sources.findIndex(s => s.id === page.cfg_notesDefault))
                onActivated: index => page.cfg_notesDefault = page.sources[index].id
            }
            QQC2.SpinBox {
                id: refreshSpin
                Kirigami.FormData.label: i18n("Fetch notes:")
                enabled: enableCheck.checked
                from: 1
                to: 60
                textFromValue: value => i18np("every minute", "every %1 minutes", value)
                valueFromText: text => parseInt(text.replace(/\D+/g, "")) || 1
            }
        }

        Kirigami.Heading {
            level: 4
            text: i18n("Connected notes apps")
        }
        QQC2.Label {
            Layout.fillWidth: true
            visible: page.sources.length === 0
            wrapMode: Text.Wrap
            opacity: 0.7
            text: i18n("No notes app is connected yet. Open the Notes page in the island to connect Joplin, Simplenote or Memos.")
        }
        Repeater {
            model: page.sources
            delegate: RowLayout {
                id: row
                required property var modelData
                Layout.fillWidth: true
                QQC2.Label {
                    Layout.fillWidth: true
                    text: page.label(row.modelData)
                    elide: Text.ElideMiddle
                }
                QQC2.Button {
                    icon.name: "list-remove"
                    text: i18n("Disconnect")
                    onClicked: {
                        page.cfg_notesSources = JSON.stringify(page.sources.filter(s => s.id !== row.modelData.id));
                        if (page.cfg_notesDefault === row.modelData.id) page.cfg_notesDefault = "";
                    }
                }
            }
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            opacity: 0.7
            text: i18n("Changes take effect when you press \"Apply\". Disconnecting an app also deletes its sign-in from KDE Wallet.")
        }
    }
}
