/*
    SPDX-License-Identifier: GPL-2.0-or-later
    The widget's language: automatic (the system's), Türkçe or English.
    Applies at once to the island and to these settings (see Lang.qml); the
    language names are written in their own language so that they can be
    found whatever the current one is.
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property string cfg_language
    // These settings follow the saved choice; it takes effect with Apply / OK.
    property string applied: ""
    Component.onCompleted: applied = cfg_language
    function saveConfig(): void { applied = cfg_language; }
    Binding { target: Lang; property: "setting"; value: page.applied; when: page.applied.length > 0; restoreMode: Binding.RestoreNone }

    readonly property var choices: [
        { value: "auto", title: Lang.i18n("Automatic"),
          detail: Lang.i18n("Like the system: %1", Lang.systemLanguage === "tr" ? "Türkçe" : "English") },
        { value: "tr", title: "Türkçe", detail: "Türkçe arayüz" },
        { value: "en", title: "English", detail: "English interface" }
    ]

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: Lang.i18n("Language of the island and of these settings:")
        }

        RowLayout {
            spacing: Kirigami.Units.largeSpacing
            Repeater {
                model: page.choices
                delegate: QQC2.Button {
                    id: choice
                    required property var modelData
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 9
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 4
                    checkable: true
                    checked: page.cfg_language === modelData.value
                    onClicked: page.cfg_language = modelData.value
                    contentItem: ColumnLayout {
                        spacing: 2
                        QQC2.Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: choice.modelData.title
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.25
                            font.weight: Font.DemiBold
                        }
                        QQC2.Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: choice.modelData.detail
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                        }
                    }
                }
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: Lang.i18n("The change takes effect with Apply, at once, without restarting Plasma. Names of apps and services (Google Calendar, Joplin…) stay as they are.")
        }
    }
}
