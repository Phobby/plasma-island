/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Settings → Suggestions: how much they may interrupt, each rule's mode,
    and everything they learned, in words: per rule and per context what it
    does now and how sure it is, with "forget" beside it; what was done
    automatically; the last week in numbers; reset and export. What is
    learned is the file of SuggestionStore.qml: this page reads and writes
    the same one as the island.
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
    property string cfg_suggestionLevel: "balanced"
    property alias cfg_suggestionDailyCards: cardsSpin.value
    property alias cfg_suggestionCooldownMinutes: cooldownSpin.value
    property alias cfg_suggestionHalfLifeDays: halfLifeSpin.value

    function widget(): var { try { return Plasmoid.configuration; } catch (e) { return null; } }
    Loader { id: localTools; source: "LocalBridge.qml" }
    SuggestionStore {
        id: store
        local: localTools.status === Loader.Ready ? localTools.item : null
        cfg: page.widget()
    }
    property alias learnedStore: store
    SuggestionCatalog { id: catalog }
    // The moment the page speaks of (tests hand in their own).
    property var clock: null
    function now(): real { return typeof clock === "function" ? clock() : Date.now(); }
    readonly property var tuning: Suggestions.tuning(cfg_suggestionLevel, cfg_suggestionDailyCards, cfg_suggestionCooldownMinutes, cfg_suggestionHalfLifeDays)

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
    property string exported: ""

    readonly property var modes: [{ id: "learn", name: Lang.i18n("Learns by itself") }, { id: "ask", name: Lang.i18n("Always asks") },
                                  { id: "auto", name: Lang.i18n("Automatic") }, { id: "off", name: Lang.i18n("Off") }]
    readonly property var levels: [{ id: "quiet", name: Lang.i18n("Quiet: rarely, two cards a day") }, { id: "balanced", name: Lang.i18n("Balanced") },
                                   { id: "active", name: Lang.i18n("Active: asks sooner and more often") }]
    // One line on a rule: what it does and how sure it is in general.
    function status(id: string): string {
        if (available.indexOf(id) < 0) return Lang.i18n("Not available on this system (its part is missing or switched off)");
        const r = Suggestions.rule(learned, id);
        if (r.mode === "off") {
            return r.why === "never" ? Lang.i18n("Off: you turned this rule off") : r.why === "ignored" ? Lang.i18n("Off: not answered five times in a row")
                 : r.why === "experimental" ? Lang.i18n("Off: experimental, its trigger is a guess") : Lang.i18n("Off");
        }
        if (r.mode === "auto") return Lang.i18n("Automatic: done without asking, with an Undo");
        if (r.mode === "ask") return Lang.i18n("Always asks");
        const all = Suggestions.sums(learned, id, null, now(), tuning.halfLife);
        if (all.weight < 0.5) return Lang.i18n("Asks; nothing learned yet");
        return Lang.i18n("Learning: welcome %1 in general", Lang.percent(Math.round(100 * (1 + all.pos) / (2 + all.pos + all.neg))));
    }
    // "Weekdays · evening: automatic (92%)"
    function contextLine(id: string, c: var): string {
        return catalog.contextText(c.ctx) + ": " + catalog.statusText(c.status) + " (" + Lang.percent(Math.round(c.confidence * 100)) + ")";
    }
    function weekText(): string {
        const w = Suggestions.week(learned, now());
        return Lang.i18n("Last 7 days: %1 shown · %2 accepted · %3 done automatically", w.shown, w.accepted, w.automatic);
    }
    function logLine(entry: var): string {
        return Qt.formatDateTime(new Date(entry.t), "dd.MM.yyyy HH:mm") + " · " + catalog.title(entry.r) + " · " + catalog.contextText(entry.c)
             + (entry.undone ? " · " + Lang.i18n("undone") : "");
    }
    function exportAll(): void {
        const text = JSON.stringify(learned, null, 2);
        const tools = store.local;
        if (tools !== null && typeof tools.writeTextFile === "function") {
            const path = tools.dataHome() + "/dynamicisland/suggestions-export.json";
            exported = tools.writeTextFile(path, text) ? Lang.i18n("Written to %1", path) : Lang.i18n("Could not be written");
        } else {
            exported = text;
        }
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.FormLayout {
            Layout.fillWidth: true
            QQC2.CheckBox {
                id: enabledCheck
                Kirigami.FormData.label: Lang.i18n("Suggestions:")
                text: Lang.i18n("Suggest things at the right moment, and learn when that is welcome")
            }
            QQC2.Label {
                Layout.maximumWidth: Kirigami.Units.gridUnit * 24
                wrapMode: Text.Wrap
                font: Kirigami.Theme.smallFont
                text: Lang.i18n("Rules and counting only, on this computer: no network, no AI. It keeps the rule, coarse circumstances (kind of day, part of the day, the calendar's name…), your answer and when; never a window, an application, an event's title or anything typed.")
            }
            QQC2.ComboBox {
                Kirigami.FormData.label: Lang.i18n("How much it may interrupt:")
                enabled: enabledCheck.checked
                model: page.levels.map(l => l.name)
                currentIndex: Math.max(0, page.levels.findIndex(l => l.id === page.cfg_suggestionLevel))
                onActivated: index => page.cfg_suggestionLevel = page.levels[index].id
            }
            QQC2.SpinBox {
                id: cardsSpin
                Kirigami.FormData.label: Lang.i18n("Cards a day, at most:")
                enabled: enabledCheck.checked
                from: 0; to: 30
                textFromValue: v => v === 0 ? Lang.i18n("as the level says (%1)", page.tuning.dailyCards) : String(v)
                valueFromText: t => parseInt(t) || 0
            }
            QQC2.SpinBox {
                id: cooldownSpin
                Kirigami.FormData.label: Lang.i18n("A rule waits after a card:")
                enabled: enabledCheck.checked
                from: 0; to: 240; stepSize: 5
                textFromValue: v => v === 0 ? Lang.i18n("as the level says (%1 min)", Math.round(page.tuning.cooldown / 60000)) : Lang.i18n("%1 min", v)
                valueFromText: t => parseInt(t) || 0
            }
            QQC2.SpinBox {
                id: gapSpin
                Kirigami.FormData.label: Lang.i18n("Between two cards:")
                enabled: enabledCheck.checked
                from: 1; to: 240
                textFromValue: v => Lang.i18n("%1 min", v)
                valueFromText: t => parseInt(t)
            }
            QQC2.SpinBox {
                id: halfLifeSpin
                Kirigami.FormData.label: Lang.i18n("An answer counts half after:")
                enabled: enabledCheck.checked
                from: 0; to: 365
                textFromValue: v => v === 0 ? Lang.i18n("%1 days", Suggestions.TUNING.halfLifeDays) : Lang.i18n("%1 days", v)
                valueFromText: t => parseInt(t) || 0
            }
        }

        Kirigami.Heading { level: 3; text: Lang.i18n("What I learned") }
        QQC2.Label { objectName: "weekText"; Layout.fillWidth: true; wrapMode: Text.Wrap; text: page.weekText() }

        Repeater {
            model: catalog.rules
            delegate: Kirigami.AbstractCard {
                id: card
                required property var modelData
                readonly property string ruleId: modelData.id
                readonly property bool usable: page.available.indexOf(ruleId) >= 0
                readonly property var contexts: Suggestions.contexts(page.learned, ruleId, page.now(), page.tuning)
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 32
                enabled: enabledCheck.checked
                contentItem: ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing
                    RowLayout {
                        Kirigami.Icon { source: card.modelData.icon; Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium; Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium }
                        Kirigami.Heading { level: 4; text: card.modelData.title; Layout.fillWidth: true; wrapMode: Text.Wrap }
                        QQC2.ComboBox {
                            objectName: "mode-" + card.ruleId
                            enabled: card.usable
                            model: page.modes.map(m => m.name)
                            currentIndex: Math.max(0, page.modes.findIndex(m => m.id === Suggestions.rule(page.learned, card.ruleId).mode))
                            onActivated: index => page.change(Suggestions.setMode(page.learned, card.ruleId, page.modes[index].id))
                        }
                    }
                    QQC2.Label { Layout.fillWidth: true; wrapMode: Text.Wrap; font: Kirigami.Theme.smallFont; text: card.modelData.hint }
                    QQC2.Label { Layout.fillWidth: true; wrapMode: Text.Wrap; text: page.status(card.ruleId) }
                    Repeater {
                        model: card.contexts
                        delegate: RowLayout {
                            id: row
                            required property var modelData
                            Layout.fillWidth: true
                            QQC2.Label { Layout.fillWidth: true; wrapMode: Text.Wrap; font: Kirigami.Theme.smallFont; text: "• " + page.contextLine(card.ruleId, row.modelData) }
                            QQC2.ToolButton {
                                icon.name: "edit-clear-history"
                                text: Lang.i18n("Forget this context")
                                display: QQC2.AbstractButton.IconOnly
                                QQC2.ToolTip.text: text
                                QQC2.ToolTip.visible: hovered
                                onClicked: page.change(Suggestions.forget(page.learned, card.ruleId, row.modelData.ctx))
                            }
                        }
                    }
                    QQC2.Button {
                        visible: page.learned.rules[card.ruleId] !== undefined || card.contexts.length > 0
                        icon.name: "edit-reset"
                        text: Lang.i18n("Reset this rule")
                        onClicked: page.change(Suggestions.reset(page.learned, card.ruleId))
                    }
                }
            }
        }

        Kirigami.Heading { level: 3; text: Lang.i18n("Done automatically") }
        QQC2.Label {
            Layout.fillWidth: true
            visible: page.learned.log.length === 0
            text: Lang.i18n("Nothing yet.")
        }
        Repeater {
            model: page.learned.log.slice().reverse()
            delegate: QQC2.Label {
                required property var modelData
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font: Kirigami.Theme.smallFont
                text: page.logLine(modelData)
            }
        }

        RowLayout {
            QQC2.Button {
                icon.name: "document-export"
                text: Lang.i18n("Export what was learned")
                onClicked: page.exportAll()
            }
            QQC2.Button {
                icon.name: "edit-delete"
                text: page.confirmReset ? Lang.i18n("Really forget everything?") : Lang.i18n("Reset everything learned")
                onClicked: {
                    if (!page.confirmReset) { page.confirmReset = true; return; }
                    page.confirmReset = false;
                    page.change(Suggestions.empty());
                }
            }
        }
        QQC2.TextArea {
            Layout.fillWidth: true
            visible: page.exported.length > 0
            readOnly: true
            wrapMode: TextEdit.WrapAnywhere
            textFormat: TextEdit.PlainText
            text: page.exported
        }
    }
}
