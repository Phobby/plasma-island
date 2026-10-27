/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Settings → General: the language, the clock, notifications, how quickly
    the island answers (Response: one choice for four delays, Customize for
    the values), dot mode and new versions. What is set less often is in the
    folding parts (SettingsFold); every setting is found by the search at the
    top (SettingsSearch, SettingsIndex).

    Where the oval island sits (distance from the top, below top panels) is on
    Appearance, with the layout it belongs to.
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page
    header: SettingsSearch { page: page; pageName: "configGeneral" }

    // The language: these settings follow the saved choice; it takes effect with Apply / OK.
    property string cfg_language
    property string applied: ""
    Component.onCompleted: applied = cfg_language
    function saveConfig(): void { applied = cfg_language; }
    Binding { target: Lang; property: "setting"; value: page.applied; when: page.applied.length > 0; restoreMode: Binding.RestoreNone }

    property bool cfg_showClock
    property int cfg_clockFormat
    property bool cfg_showNotifications
    property int cfg_notificationDuration
    property int cfg_hoverDelay
    property int cfg_collapseDelay
    property int cfg_eventDuration
    property string cfg_preferredPlayer
    property bool cfg_dotMode
    property int cfg_dotStart
    property int cfg_dotSize
    property bool cfg_dotHoverExpand
    property int cfg_dotEvents
    property bool cfg_dotCriticalExpand
    property int cfg_updateMode

    // Response: the four delays as one choice. No setting of its own: read from the values,
    // "Custom" when they match none of the three (Balanced is a new island's).
    readonly property var responses: [
        { name: Lang.i18n("Calm"), hoverDelay: 300, collapseDelay: 800, eventDuration: 5000, notificationDuration: 6000 },
        { name: Lang.i18n("Balanced"), hoverDelay: 120, collapseDelay: 400, eventDuration: 3000, notificationDuration: 4000 },
        { name: Lang.i18n("Lively"), hoverDelay: 50, collapseDelay: 200, eventDuration: 2000, notificationDuration: 3000 }
    ]
    readonly property int response: responses.findIndex(r => r.hoverDelay === cfg_hoverDelay && r.collapseDelay === cfg_collapseDelay
                                                          && r.eventDuration === cfg_eventDuration && r.notificationDuration === cfg_notificationDuration)
    function useResponse(index: int): void {
        const r = responses[index];
        cfg_hoverDelay = r.hoverDelay; cfg_collapseDelay = r.collapseDelay;
        cfg_eventDuration = r.eventDuration; cfg_notificationDuration = r.notificationDuration;
    }

    Kirigami.FormLayout {
        id: form

        QQC2.ComboBox {
            id: languageCombo
            objectName: "setting-language"
            Kirigami.FormData.label: Lang.i18n("Language:")
            // (the names in their own language, to be found whatever the current one is)
            readonly property var values: ["auto", "tr", "en"]
            model: [Lang.i18n("Like the system: %1", Lang.systemLanguage === "tr" ? "Türkçe" : "English"), "Türkçe", "English"]
            Binding { target: languageCombo; property: "currentIndex"; value: Math.max(0, languageCombo.values.indexOf(page.cfg_language || "auto")) }
            onActivated: index => page.cfg_language = values[index]
            Accessible.name: Lang.i18n("Language:") + " " + currentText
        }

        SettingCheck {
            settings: page; key: "showClock"
            Kirigami.FormData.label: Lang.i18n("Idle:")
            text: Lang.i18n("Show clock")
        }
        SettingCombo {
            settings: page; key: "clockFormat"
            Kirigami.FormData.label: Lang.i18n("Time format:")
            enabled: page.cfg_showClock
            // (the system's: its region's time format, System Settings → Region & Language → Time)
            model: [
                Lang.i18n("As the system (%1)", Qt.formatTime(new Date(2026, 0, 1, 19, 41), Lang.shortTime(Qt.locale().timeFormat(Locale.ShortFormat), 0))),
                Lang.i18n("24-hour (%1)", Qt.formatTime(new Date(2026, 0, 1, 19, 41), Lang.shortTime(Qt.locale().timeFormat(Locale.ShortFormat), 1))),
                Lang.i18n("12-hour (%1)", Qt.formatTime(new Date(2026, 0, 1, 19, 41), Lang.shortTime(Qt.locale().timeFormat(Locale.ShortFormat), 2)))
            ]
        }
        SettingCheck {
            settings: page; key: "showNotifications"
            Kirigami.FormData.label: Lang.i18n("Notifications:")
            text: Lang.i18n("Show incoming notifications in the island")
        }

        RowLayout {
            Kirigami.FormData.label: Lang.i18n("Response:")
            QQC2.ComboBox {
                id: responseCombo
                objectName: "setting-response"
                model: page.responses.map(r => r.name).concat(page.response < 0 ? [Lang.i18n("Custom")] : [])
                readonly property int shown: page.response < 0 ? 3 : page.response
                Binding { target: responseCombo; property: "currentIndex"; value: responseCombo.shown }
                // ("Custom" comes and goes: a model that changes starts again at its first entry)
                onModelChanged: Qt.callLater(() => { if (currentIndex !== shown) currentIndex = shown; })
                onActivated: index => { if (index < 3) page.useResponse(index); }
                Accessible.name: Lang.i18n("Response:") + " " + currentText
            }
            Kirigami.ContextualHelpButton {
                toolTipText: Lang.i18n("How soon the island opens under the pointer and closes after it, and how long events and notifications stay.")
            }
        }
        SettingsFold {
            title: Lang.i18n("Customize")
            foldId: "general.response"
            twin: form
            keys: ["hoverDelay", "collapseDelay", "eventDuration", "notificationDuration"]
            content: Kirigami.FormLayout {
                SettingSpin {
                    settings: page; key: "hoverDelay"
                    Kirigami.FormData.label: Lang.i18n("Expand after hovering:")
                    from: 0; to: 2000; stepSize: 50
                    unit: Lang.i18n("%1 ms")
                }
                SettingSpin {
                    settings: page; key: "collapseDelay"
                    Kirigami.FormData.label: Lang.i18n("Collapse after leaving:")
                    from: 0; to: 3000; stepSize: 50
                    unit: Lang.i18n("%1 ms")
                }
                SettingSpin {
                    settings: page; key: "eventDuration"
                    Kirigami.FormData.label: Lang.i18n("Transient events stay:")
                    from: 1000; to: 10000; stepSize: 500
                    unit: Lang.i18n("%1 s"); scale: 1000; decimals: 1
                }
                SettingSpin {
                    settings: page; key: "notificationDuration"
                    Kirigami.FormData.label: Lang.i18n("Notifications stay:")
                    enabled: page.cfg_showNotifications
                    from: 1000; to: 20000; stepSize: 500
                    unit: Lang.i18n("%1 s"); scale: 1000; decimals: 1
                }
            }
        }

        // ---- dot mode ----------------------------------------------------------------
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Lang.i18n("Dot mode")
        }
        RowLayout {
            Kirigami.FormData.label: Lang.i18n("Click:")
            SettingCheck {
                settings: page; key: "dotMode"
                text: Lang.i18n("A click shrinks the island to a dot")
            }
            Kirigami.ContextualHelpButton {
                toolTipText: Lang.i18n("Click the small island, use the button at the top of the open island, or right-click it. A click on the dot brings the pill back. Off: a click opens the island.")
            }
        }
        // (only while dot mode is on: hidden otherwise, not greyed)
        SettingsFold {
            title: Lang.i18n("Dot mode details")
            foldId: "general.dot"
            twin: form
            visible: page.cfg_dotMode
            needs: "dotMode"
            keys: ["dotStart", "dotSize", "dotHoverExpand", "dotEvents", "dotCriticalExpand"]
            content: Kirigami.FormLayout {
                SettingCombo {
                    settings: page; key: "dotStart"
                    Kirigami.FormData.label: Lang.i18n("Start as:")
                    model: [Lang.i18n("As it was left"), Lang.i18n("Always the pill"), Lang.i18n("Always the dot")]
                }
                SettingSpin {
                    settings: page; key: "dotSize"
                    Kirigami.FormData.label: Lang.i18n("Dot size:")
                    from: 10; to: 28
                    unit: Lang.i18n("%1 px")
                }
                SettingCheck {
                    settings: page; key: "dotHoverExpand"
                    Kirigami.FormData.label: Lang.i18n("Hovering the dot:")
                    text: Lang.i18n("Opens the island")
                }
                SettingCombo {
                    settings: page; key: "dotEvents"
                    Kirigami.FormData.label: Lang.i18n("Events in dot mode:")
                    Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                    model: [Lang.i18n("Only the dot shows them"), Lang.i18n("Open for them, then back to the dot"), Lang.i18n("Show nothing")]
                }
                SettingCheck {
                    settings: page; key: "dotCriticalExpand"
                    text: Lang.i18n("Always open for critical events (incoming call, alarm, low battery)")
                }
            }
        }

        // ---- the rest ------------------------------------------------------------------
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Lang.i18n("New versions of the island")
        }
        RowLayout {
            Kirigami.FormData.label: Lang.i18n("When there is one:")
            SettingCombo {
                settings: page; key: "updateMode"
                model: [Lang.i18n("Never look"), Lang.i18n("Ask me"), Lang.i18n("Install by itself")]
            }
            Kirigami.ContextualHelpButton {
                toolTipText: page.cfg_updateMode === 0 ? Lang.i18n("The island asks nobody about new versions. To update by hand: git pull in its folder, then ./install.sh.")
                    : Lang.i18n("Once a day the island reads the newest version number from its repository on GitHub; nothing about you is sent. An update is fetched from there, built and installed for your user only, and keeps your settings. Installing needs the native module.")
                      + (page.cfg_updateMode === 2 ? " " + Lang.i18n("By itself it installs without asking, and asks only before the desktop shell restarts.") : "")
            }
        }

        SettingsFold {
            foldId: "general.details"
            twin: form
            keys: ["preferredPlayer"]
            content: Kirigami.FormLayout {
                QQC2.TextField {
                    objectName: "setting-preferredPlayer"
                    Kirigami.FormData.label: Lang.i18n("Preferred player:")
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 16
                    placeholderText: Lang.i18n("e.g. spotify, elisa, firefox (empty = automatic)")
                    text: page.cfg_preferredPlayer
                    onTextEdited: page.cfg_preferredPlayer = text
                    Accessible.name: Lang.i18n("Preferred player:")
                }
            }
        }
    }
}
