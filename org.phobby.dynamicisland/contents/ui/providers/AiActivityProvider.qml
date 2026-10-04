/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The AI tab on the small island. While an answer is being written and its
    page is not on screen (the island closed, or another tab is shown), a
    quiet live activity says so: three dots, ranked below every other
    activity. When the answer is complete a short event says "Answer ready";
    a click opens the island on the tab. The event can be switched off
    (Settings → AI); the dot on the tab stays either way.

    Nothing runs here while no answer is on its way: the dots only move while
    they are shown.
*/
import QtQuick
import QtQuick.Layouts
import ".."
import "../AiMarkdown.js" as Markdown

Item {
    id: provider

    required property ActivityManager manager
    required property Theme theme
    property var ai: null                   // AiBackend
    property bool enabled: true
    // Say when an answer is ready (or could not be given).
    property bool notify: true
    // The island is to open on the AI page.
    signal opened()

    readonly property bool waiting: enabled && ai !== null && ai.busy && !ai.viewing
    readonly property string sourceName: {
        const s = ai !== null && ai.busySource.length > 0 ? ai.source(ai.busySource) : null;
        return s !== null ? s.name : "";
    }

    Activity {
        id: thinking
        activityId: "ai-thinking"
        // not in the priority order: below every other activity
        category: "assistant"
        active: provider.waiting
        icon: "dialog-messages"
        color: provider.theme.text
        title: Lang.i18n("Thinking…")
        subtitle: provider.sourceName
        actions: [{ icon: "media-playback-stop-symbolic", text: Lang.i18n("Stop"), trigger: () => provider.ai.stop() }]
        onClicked: provider.opened()
        compact: Component {
            Item {
                id: pill
                required property var activity
                required property Theme theme
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 14
                    spacing: 8
                    ActivityIcon {
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        icon: pill.activity?.icon ?? ""
                        color: pill.theme.subText
                    }
                    Text {
                        Layout.fillWidth: true
                        text: pill.activity?.title ?? ""
                        color: pill.theme.subText
                        font.pointSize: pill.theme.fontSmall
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                    AiDots {
                        objectName: "pillDots"
                        color: pill.theme.text
                        running: pill.visible
                    }
                }
            }
        }
        minimal: Component {
            Item {
                id: bubble
                required property var activity
                required property Theme theme
                AiDots {
                    anchors.centerIn: parent
                    size: 4
                    color: bubble.theme.text
                    running: bubble.visible
                }
            }
        }
        Component.onCompleted: provider.manager.register(this)
    }
    Component.onDestruction: manager.unregister(thinking)

    Connections {
        target: provider.ai
        function onAnswered(text) {
            if (!provider.enabled || !provider.notify || provider.ai.viewing) return;
            provider.manager.flash({
                key: "ai-answer",
                icon: "dialog-messages",
                color: provider.theme.live,
                title: Lang.i18n("Answer ready"),
                subtitle: Markdown.firstLine(text, 70),
                trailing: { type: "button", text: Lang.i18n("Open") },
                activate: () => provider.opened(),
                duration: 5000
            });
        }
        function onFailed(problem) {
            if (!provider.enabled || !provider.notify || provider.ai.viewing) return;
            provider.manager.flash({
                key: "ai-answer",
                icon: "dialog-messages",
                color: provider.theme.orange,
                title: Lang.i18n("No answer"),
                subtitle: provider.ai.problemOf(provider.ai.messages[provider.ai.messages.length - 1]),
                trailing: { type: "button", text: Lang.i18n("Open") },
                activate: () => provider.opened(),
                duration: 5000
            });
        }
    }
}
