/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Suggestions: on/off, the pause between two of them, and every rule with
    its switch, its mode (asks / automatic) and what it has learned, which can
    be forgotten per rule or altogether.

    What is learned is the island's own record (SuggestionStore: a small
    file), read and changed there directly, without Apply: the island reads
    it anew at every suggestion, so a change here holds at once.
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasmoid
import "Suggestions.js" as Suggestions

KCM.SimpleKCM {
    id: page

    property string cfg_language
    Binding { target: Lang; property: "setting"; value: page.cfg_language; restoreMode: Binding.RestoreNone }

    property alias cfg_suggestionsEnabled: enabledCheck.checked
    property alias cfg_suggestionGapMinutes: gapSpin.value

    function widget(): var { try { return Plasmoid.configuration; } catch (e) { return null; } }
    Loader { id: localTools; source: "LocalBridge.qml" }
    SuggestionStore {
        id: store
        local: localTools.status === Loader.Ready ? localTools.item : null
        cfg: page.widget()
    }
    property alias learnedStore: store
    SuggestionCatalog { id: catalog }

    // What is learned: as of when the page opened, and after every change made here.
    property var learned: Suggestions.empty()
    function reload(): void { learned = store.read(); }
    function change(next: var): void { store.write(next); reload(); }
    Component.onCompleted: reload()
    Connections {
        target: store
        function onInFileChanged() { page.reload(); }
        function onPathChanged() { page.reload(); }
    }
    // The rules this system can make, as the island says (all of them while that is not known).
    readonly property var available: {
        const c = widget(), text = c ? String(c.suggestionsAvailable || "") : "";
        return text.length > 0 ? text.split(",") : Suggestions.RULES;
    }
    property bool confirmReset: false

    function status(id: string): string {
        const r = Suggestions.rule(learned, id);
        if (available.indexOf(id) < 0) return Lang.i18n("Not available on this system (its part is missing or switched off)");
        const counts = r.yes + r.later > 0 ? " · " + Lang.i18n("Yes: %1 · Not now or no answer: %2", r.yes, r.later) : "";
        if (r.mode === "off")
            return (r.why === "never" ? Lang.i18n("Off: you chose “Never suggest this”")
                  : r.why === "ignored" ? Lang.i18n("Off: not answered five times in a row") : Lang.i18n("Off")) + counts;
        if (r.mode === "auto") return Lang.i18n("Automatic: done without asking, with an Undo") + counts;
        const wait = Suggestions.wait(r);
        return (wait > 0 ? Lang.i18np("Asks, at most once in %1 hour", "Asks, at most once in %1 hours", Math.round(wait / 3600000)) : Lang.i18n("Asks")) + counts;
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.FormLayout {
            Layout.fillWidth: true
            QQC2.CheckBox {
                id: enabledCheck
                Kirigami.FormData.label: Lang.i18n("Suggestions:")
                text: Lang.i18n("Ask at the right moment whether to do something")
            }
            QQC2.SpinBox {
                id: gapSpin
                Kirigami.FormData.label: Lang.i18n("Between two suggestions:")
                enabled: enabledCheck.checked
                from: 1
                to: 240
                // (a new function when the language changes, so that the text follows it)
                textFromValue: { const language = Lang.language; return value => Lang.i18np("at least %1 minute", "at least %1 minutes", value); }
                valueFromText: text => parseInt(text.replace(/\D+/g, "")) || 5
            }
            QQC2.Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 24
                wrapMode: Text.Wrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                text: Lang.i18n("One sentence on the island with Yes, Not now and Never suggest this; gone after ten seconds. Nothing is suggested while Do Not Disturb is on or the screen is recorded. Everything is worked out on this computer by fixed rules: no network, no AI.")
            }
        }

        Kirigami.Heading {
            level: 4
            text: Lang.i18n("Rules")
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: Lang.i18n("Each rule learns from your answers: three times “Not now” in a row and it asks less often, five and it switches itself off; three times “Yes” in a row and it offers to act by itself. What you change here applies at once.")
        }

        Repeater {
            model: catalog.rules
            delegate: QQC2.ItemDelegate {
                id: row
                required property var modelData
                readonly property var record: Suggestions.rule(page.learned, modelData.id)
                readonly property bool here: page.available.indexOf(modelData.id) >= 0
                readonly property bool on: record.mode !== "off"
                Layout.fillWidth: true
                hoverEnabled: false
                down: false
                enabled: enabledCheck.checked
                background: Rectangle { radius: Kirigami.Units.cornerRadius; color: Qt.alpha(Kirigami.Theme.textColor, 0.04) }
                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    Kirigami.Icon {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                        source: row.modelData.icon
                        opacity: row.here ? 1 : 0.5
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        QQC2.Label { Layout.fillWidth: true; text: row.modelData.title; elide: Text.ElideRight; opacity: row.here ? 1 : 0.6 }
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: row.modelData.hint
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                            elide: Text.ElideRight
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: page.status(row.modelData.id)
                            font: Kirigami.Theme.smallFont
                            color: row.here && row.record.mode === "off" && row.record.why !== "settings" ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.textColor
                            opacity: 0.85
                            elide: Text.ElideRight
                        }
                    }
                    // asks, or acts by itself
                    QQC2.ComboBox {
                        id: modeCombo
                        enabled: row.here && row.on
                        model: [Lang.i18n("Asks"), Lang.i18n("Automatic")]
                        readonly property int wanted: row.record.mode === "auto" ? 1 : 0
                        Binding { target: modeCombo; property: "currentIndex"; value: modeCombo.wanted }
                        onModelChanged: Qt.callLater(() => { if (modeCombo.currentIndex !== modeCombo.wanted) modeCombo.currentIndex = modeCombo.wanted; })
                        onActivated: index => page.change(Suggestions.setMode(page.learned, row.modelData.id, index === 1 ? "auto" : "suggest"))
                    }
                    QQC2.ToolButton {
                        enabled: page.learned.rules[row.modelData.id] !== undefined
                        icon.name: "edit-clear-history"
                        display: QQC2.AbstractButton.IconOnly
                        text: Lang.i18n("Forget what this rule learned")
                        onClicked: page.change(Suggestions.reset(page.learned, row.modelData.id))
                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.text: text
                    }
                    QQC2.Switch {
                        id: ruleSwitch
                        enabled: row.here
                        Binding { target: ruleSwitch; property: "checked"; value: row.on }
                        onToggled: page.change(Suggestions.setMode(page.learned, row.modelData.id, checked ? "suggest" : "off"))
                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.text: checked ? Lang.i18n("On") : Lang.i18n("Off")
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            QQC2.Button {
                visible: !page.confirmReset
                enabled: Object.keys(page.learned.rules).length > 0 || page.learned.last > 0
                icon.name: "edit-delete"
                text: Lang.i18n("Forget everything that was learned…")
                onClicked: page.confirmReset = true
            }
            QQC2.Label { visible: page.confirmReset; text: Lang.i18n("Forget the answers of every rule? They all ask again as on the first day.") }
            QQC2.Button {
                visible: page.confirmReset
                icon.name: "edit-delete"
                text: Lang.i18n("Forget")
                onClicked: { page.change(Suggestions.empty()); page.confirmReset = false; }
            }
            QQC2.Button {
                visible: page.confirmReset
                text: Lang.i18n("Cancel")
                onClicked: page.confirmReset = false
            }
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: store.inFile ? Lang.i18n("What is learned is kept in %1: per rule how often it was answered with yes and with “not now”, and whether it asks, acts by itself or is off. Nothing else.", store.path)
                               : Lang.i18n("What is learned is kept in the widget's own settings (without the native helper there is no file of its own): per rule how often it was answered with yes and with “not now”, and whether it asks, acts by itself or is off.")
        }
    }
}
