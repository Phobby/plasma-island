/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The first opening of a new island: three short steps over its pages,
    each can be skipped. 1. the layout (notch or oval), 2. which tabs are
    on, 3. what is missing (the native module; the rest is said by each tab
    when it is opened, and listed in Diagnostics). Shown once (tourShown);
    an island that ran before this version never sees it (SettingsMigration
    step 3); Settings → Diagnostics → About shows it again.

    What is chosen here is written at once, as the settings window would.
*/
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: tour
    objectName: "islandTour"

    required property Theme theme
    // The widget's configuration (Plasmoid.configuration): what is chosen is written to it.
    required property var cfg
    // Whether the native module is there.
    property bool nativeAvailable: true
    signal finished()
    signal diagnosticsRequested()

    property int step: 0
    readonly property int steps: 3

    // (covers the pages, in the island's own colours; a click goes no further, and the pages are not
    // turned under it: ExpandedContent's wheel is off while it is there)
    color: theme.over(theme.bodyMid, theme.surface)
    radius: 12
    MouseArea { anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.AllButtons }

    PageCatalog { id: catalog }
    readonly property var tabs: catalog.pages.filter(p => p.config.length > 0)
    readonly property int tabsOn: tabs.filter(p => tour.cfg[p.config] === true).length

    function finish(): void {
        cfg.tourShown = true;
        finished();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        Text {
            textFormat: Text.PlainText
            Layout.fillWidth: true
            text: tour.step === 0 ? Lang.i18n("Where should the island sit?")
                : tour.step === 1 ? Lang.i18n("Which tabs do you want?")
                : Lang.i18n("What this computer has")
            color: tour.theme.text
            font.pointSize: tour.theme.fontTitle
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            Accessible.role: Accessible.Heading
            Accessible.name: text
        }
        Text {
            textFormat: Text.PlainText
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            text: tour.step === 0 ? Lang.i18n("The notch hangs from the top edge, over a panel; the oval island floats a little below it.")
                : tour.step === 1 ? Lang.i18n("Click a tab to switch it on or off. Everything else is in the settings.")
                : tour.nativeAvailable ? Lang.i18n("The full install is there. A tab that needs another program says so when it is opened.")
                : Lang.i18n("The native module is not installed: calls, screen recording, blur and a few tabs stay off. Diagnostics says how to install it.")
            color: tour.theme.subText
            font.pointSize: tour.theme.fontSmall
        }

        // ---- the step's choices ----------------------------------------------------------
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Row {
                visible: tour.step === 0
                anchors.centerIn: parent
                spacing: 10
                Repeater {
                    model: [{ value: 0, text: Lang.i18n("Notch") }, { value: 1, text: Lang.i18n("Oval layout") }]
                    delegate: PillButton {
                        required property var modelData
                        objectName: "tourLayout" + modelData.value
                        theme: tour.theme
                        text: modelData.text
                        primary: Number(tour.cfg.islandLayout) === modelData.value
                        onClicked: tour.cfg.islandLayout = modelData.value
                    }
                }
            }

            // (the tabs in as many rows as it takes; more than there is room for: they scroll, and
            // never reach the buttons below)
            IslandFlickable {
                id: tabsView
                objectName: "tourTabs"
                visible: tour.step === 1
                anchors.fill: parent
                contentWidth: width
                contentHeight: tabsFlow.implicitHeight
                Flow {
                    id: tabsFlow
                    width: tabsView.width
                    spacing: 4
                    Repeater {
                        model: tour.tabs
                        delegate: PillButton {
                            required property var modelData
                            objectName: "tourTab-" + modelData.key
                            theme: tour.theme
                            height: 22
                            text: modelData.title
                            readonly property bool on: tour.cfg[modelData.config] === true
                            primary: on
                            // (the last tab that is on stays on)
                            onClicked: if (!on || tour.tabsOn > 1) tour.cfg[modelData.config] = !on
                        }
                    }
                }
            }

            PillButton {
                visible: tour.step === 2
                anchors.centerIn: parent
                objectName: "tourDiagnostics"
                theme: tour.theme
                text: Lang.i18n("Open Diagnostics")
                onClicked: { tour.finish(); tour.diagnosticsRequested(); }
            }
        }

        // ---- moving on -----------------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            PillButton {
                objectName: "tourSkip"
                theme: tour.theme
                text: Lang.i18n("Skip")
                onClicked: tour.finish()
            }
            Item { Layout.fillWidth: true }
            Text {
                textFormat: Text.PlainText
                text: Lang.i18n("%1 of %2", tour.step + 1, tour.steps)
                color: tour.theme.subText
                font.pointSize: tour.theme.fontSmall
            }
            Item { Layout.fillWidth: true }
            PillButton {
                objectName: "tourBack"
                theme: tour.theme
                visible: tour.step > 0
                text: Lang.i18n("Back")
                onClicked: tour.step -= 1
            }
            PillButton {
                objectName: "tourNext"
                theme: tour.theme
                primary: true
                text: tour.step < tour.steps - 1 ? Lang.i18n("Next") : Lang.i18n("Done")
                onClicked: if (tour.step < tour.steps - 1) tour.step += 1; else tour.finish()
            }
        }
    }
}
