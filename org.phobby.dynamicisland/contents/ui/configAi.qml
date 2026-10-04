/*
    SPDX-License-Identifier: GPL-2.0-or-later
    AI: whether the tab is shown (off until switched on), what is connected
    to answer (each with its model and "Disconnect"), which of them answers
    by default, how long an answer and a question may be, whether the chat is
    kept in a file, and whether the island says when an answer is ready.

    Sources are connected on the island's AI page. Their keys are kept in KDE
    Wallet, never in these settings; disconnecting one here deletes its key
    from the wallet when "Apply" is pressed (the island does it).

    What Claude Code is run with cannot be changed here, on purpose.
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "ai"
import "ai/AiStream.js" as Stream

KCM.SimpleKCM {
    id: page

    property string cfg_language
    Binding { target: Lang; property: "setting"; value: page.cfg_language; restoreMode: Binding.RestoreNone }

    property alias cfg_showAi: enableCheck.checked
    property alias cfg_aiMaxTokens: tokensSpin.value
    property alias cfg_aiMaxChars: charsSpin.value
    property alias cfg_aiKeepHistory: keepCheck.checked
    property alias cfg_aiNotify: notifyCheck.checked
    property string cfg_aiSources: "[]"
    property string cfg_aiDefault: ""

    AiCatalog { id: catalog }
    readonly property var sources: {
        try {
            const list = JSON.parse(cfg_aiSources || "[]");
            return Array.isArray(list) ? list.filter(s => s && typeof s.id === "string" && catalog.kind(s.kind) !== null) : [];
        } catch (e) { return []; }
    }
    readonly property bool hasClaudeCode: sources.some(s => s.kind === "claude-cli")
    function label(s: var): string {
        const a = Stream.address(String(s.server || ""));
        return a.ok ? Lang.i18n("%1 · %2", catalog.kind(s.kind).name, a.host) : catalog.kind(s.kind).name;
    }
    function store(list: var): void {
        cfg_aiSources = JSON.stringify(list.map(s => ({ id: s.id, kind: s.kind, server: String(s.server || ""), model: String(s.model || "") })));
    }
    function setModel(id: string, model: string): void {
        store(sources.map(s => s.id === id ? Object.assign({}, s, { model: model.trim() }) : s));
    }
    function remove(id: string): void {
        store(sources.filter(s => s.id !== id));
        if (cfg_aiDefault === id) cfg_aiDefault = "";
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.FormLayout {
            Layout.fillWidth: true
            QQC2.CheckBox {
                id: enableCheck
                Kirigami.FormData.label: Lang.i18n("AI:")
                text: Lang.i18n("Show the AI page in the island")
            }
            QQC2.Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 24
                wrapMode: Text.Wrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                text: Lang.i18n("A box for quick questions: text in, text out. It reads no files, runs no commands and is given nothing you did not type. What you type is sent to the source you connected.")
            }
            QQC2.ComboBox {
                id: defaultCombo
                Kirigami.FormData.label: Lang.i18n("Answers by default:")
                enabled: enableCheck.checked && page.sources.length > 0
                Layout.preferredWidth: Kirigami.Units.gridUnit * 16
                model: page.sources.map(s => page.label(s))
                currentIndex: Math.max(0, page.sources.findIndex(s => s.id === page.cfg_aiDefault))
                onActivated: index => page.cfg_aiDefault = page.sources[index].id
            }
            QQC2.SpinBox {
                id: tokensSpin
                Kirigami.FormData.label: Lang.i18n("Longest answer:")
                enabled: enableCheck.checked
                from: 128
                to: 8192
                stepSize: 128
                textFromValue: value => Lang.i18n("%1 tokens", value)
                valueFromText: text => parseInt(text.replace(/\D+/g, "")) || 2048
            }
            QQC2.SpinBox {
                id: charsSpin
                Kirigami.FormData.label: Lang.i18n("Longest question:")
                enabled: enableCheck.checked
                from: 200
                to: 20000
                stepSize: 500
                textFromValue: value => Lang.i18n("%1 characters", value)
                valueFromText: text => parseInt(text.replace(/\D+/g, "")) || 4000
            }
            QQC2.Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 24
                wrapMode: Text.Wrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                text: Lang.i18n("An answer stops at its limit (a token is about three quarters of a word; with a service that is paid for, this caps what one answer can cost). A longer question is not sent: that is work for the Claude app or a terminal.")
            }
            QQC2.CheckBox {
                id: notifyCheck
                Kirigami.FormData.label: Lang.i18n("On the island:")
                enabled: enableCheck.checked
                text: Lang.i18n("Say “Answer ready” when an answer arrived while its page was not shown")
            }
            QQC2.CheckBox {
                id: keepCheck
                Kirigami.FormData.label: Lang.i18n("The chat:")
                enabled: enableCheck.checked
                text: Lang.i18n("Keep it in a file on this computer")
            }
            QQC2.Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 24
                wrapMode: Text.Wrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                text: keepCheck.checked ? Lang.i18n("The chat is written to ~/.local/share/dynamicisland/ai-chat.json, readable by you only, and is there again after a restart. Switching this off deletes the file.")
                                        : Lang.i18n("The chat is only in memory: it is gone when the shell restarts or the widget is removed.")
            }
        }

        Kirigami.Heading {
            level: 4
            text: Lang.i18n("What is connected")
        }
        QQC2.Label {
            Layout.fillWidth: true
            visible: page.sources.length === 0
            wrapMode: Text.Wrap
            opacity: 0.7
            text: Lang.i18n("Nothing is connected yet. Open the AI page in the island: Claude Code and Ollama are found by themselves, a key or a model server of your own is added there.")
        }
        Repeater {
            model: page.sources
            delegate: RowLayout {
                id: row
                required property var modelData
                readonly property var kind: catalog.kind(modelData.kind)
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    source: row.kind.where === "cli" ? "utilities-terminal" : row.kind.where === "device" ? "computer" : "globe"
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    text: page.label(row.modelData)
                    elide: Text.ElideMiddle
                }
                QQC2.Label {
                    text: Lang.i18n("Model:")
                    opacity: 0.7
                }
                QQC2.TextField {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 11
                    text: row.modelData.model || ""
                    placeholderText: row.kind.modelOptional === true ? Lang.i18n("Its own choice") : Lang.i18n("Chosen on the island")
                    onEditingFinished: if (text.trim() !== String(row.modelData.model || "")) page.setModel(row.modelData.id, text)
                }
                QQC2.Button {
                    icon.name: "list-remove"
                    text: Lang.i18n("Disconnect")
                    onClicked: page.remove(row.modelData.id)
                }
            }
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            opacity: 0.7
            text: Lang.i18n("Keys are kept in KDE Wallet, never in these settings. Changes take effect when you press \"Apply\"; disconnecting a source also deletes its key from the wallet. A model's name is the source's own: it can be chosen from its list on the island, or typed here.")
        }

        // What Claude Code is run with: said, not set.
        Kirigami.InlineMessage {
            objectName: "claudeCodeNote"
            Layout.fillWidth: true
            visible: true
            type: Kirigami.MessageType.Information
            showCloseButton: false
            text: Lang.i18n("Claude Code: tools are off, text answers only. It is started in an empty folder of the island's own, without your settings, hooks, MCP servers, skills or CLAUDE.md files, for one turn, and keeps nothing of the chat. If it starts with a tool anyway, or the model reaches for one, it is stopped at once. This cannot be changed here.")
        }
    }
}
