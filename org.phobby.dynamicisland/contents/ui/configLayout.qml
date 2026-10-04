/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Two lists, kept apart.
    Tabs: the pages along the top of the expanded island: their order (drag by
    the handle) and whether each is shown; a hidden one is not in the tab bar
    at all. At least one stays on. The switches are the pages' own settings
    (showMediaModule, showTools, showWeather…), the order is pageOrder.
    Modules: the parts inside a page that can be switched.
    The tab order is only where a page sits among the tabs; which live activity
    the island shows first is the priority list in Activities.
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property string cfg_language
    Binding { target: Lang; property: "setting"; value: page.cfg_language; restoreMode: Binding.RestoreNone }

    property string cfg_pageOrder
    property bool cfg_showMediaModule
    property bool cfg_showSystemModule
    property bool cfg_showNotificationModule
    property bool cfg_showQuickSettings
    property bool cfg_showTools
    property bool cfg_showCalendar
    property bool cfg_showNotes
    property bool cfg_showClipboard
    property bool cfg_showDevicesModule
    property bool cfg_showWeather
    property bool cfg_showApps
    property bool cfg_showHabits
    property bool cfg_showAi
    property bool cfg_showCloud
    property alias cfg_showVolumeModule: volumeSwitch.checked

    // Tabs that are switched on (Activities comes and goes by itself and does not count).
    readonly property int shownTabs: catalog.pages.filter(p => p.config.length > 0 && page["cfg_" + p.config] === true).length
    property bool lastTabWarning: false
    Timer { id: warningTimer; interval: 6000; onTriggered: page.lastTabWarning = false }

    PageCatalog { id: catalog }
    function info(key: string): var { return catalog.pages.find(p => p.key === key); }

    // The list follows cfg_pageOrder; a drag moves rows, the drop writes it back.
    ListModel { id: rows }
    function load(): void {
        rows.clear();
        for (const key of catalog.normalize(cfg_pageOrder)) rows.append({ key: key });
    }
    function store(): void {
        const keys = [];
        for (let i = 0; i < rows.count; ++i) keys.push(rows.get(i).key);
        cfg_pageOrder = keys.join(",");
    }
    Component.onCompleted: load()
    onCfg_pageOrderChanged: {
        let same = rows.count > 0;
        const keys = catalog.normalize(cfg_pageOrder);
        for (let i = 0; same && i < rows.count; ++i) same = rows.get(i).key === keys[i];
        if (!same) load();
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading {
            level: 4
            text: Lang.i18n("Tabs")
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: Lang.i18n("Drag a page by its handle to change where its tab sits in the expanded island; the switch shows or hides it.")
        }
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Warning
            visible: page.lastTabWarning
            text: Lang.i18n("At least one tab has to stay on.")
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: contentHeight
            interactive: false
            spacing: Kirigami.Units.smallSpacing
            model: rows

            moveDisplaced: Transition {
                YAnimator { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad }
            }

            // The handle reads `index` from the delegate's context: no required properties here.
            delegate: Item {
                id: wrapper
                readonly property var page_: page.info(model.key)
                readonly property string configKey: page_ ? page_.config : ""
                width: list.width
                height: row.implicitHeight

                QQC2.ItemDelegate {
                    id: row
                    // Lifted off the list while it is being dragged.
                    readonly property bool dragging: parent === list
                    width: wrapper.width
                    hoverEnabled: true
                    down: false
                    scale: dragging ? 1.03 : 1
                    Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration } }

                    background: Kirigami.ShadowedRectangle {
                        radius: Kirigami.Units.cornerRadius
                        color: row.dragging ? Kirigami.Theme.backgroundColor
                             : row.hovered ? Qt.alpha(Kirigami.Theme.highlightColor, 0.12)
                             : Qt.alpha(Kirigami.Theme.textColor, 0.04)
                        border.width: row.dragging ? 1 : 0
                        border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.6)
                        shadow.size: row.dragging ? Kirigami.Units.gridUnit : 0
                        shadow.color: Qt.rgba(0, 0, 0, 0.3)
                        shadow.yOffset: 2
                    }

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.smallSpacing
                        Kirigami.ListItemDragHandle {
                            listItem: row
                            listView: list
                            onMoveRequested: (oldIndex, newIndex) => rows.move(oldIndex, newIndex, 1)
                            onDropped: page.store()
                        }
                        Kirigami.Icon {
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                            source: wrapper.page_ ? wrapper.page_.icon : ""
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            QQC2.Label {
                                Layout.fillWidth: true
                                text: wrapper.page_ ? wrapper.page_.title : model.key
                                elide: Text.ElideRight
                            }
                            QQC2.Label {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: wrapper.page_ ? wrapper.page_.hint : ""
                                font: Kirigami.Theme.smallFont
                                opacity: 0.7
                                elide: Text.ElideRight
                            }
                        }
                        // Activities has no switch: it is there whenever something is going on.
                        QQC2.Label {
                            visible: wrapper.configKey.length === 0
                            text: Lang.i18n("Automatic")
                            opacity: 0.7
                        }
                        QQC2.Switch {
                            id: tabSwitch
                            visible: wrapper.configKey.length > 0
                            readonly property bool on: wrapper.configKey.length > 0 && page["cfg_" + wrapper.configKey] === true
                            Binding { target: tabSwitch; property: "checked"; value: tabSwitch.on }
                            onToggled: {
                                // The last tab that is on stays on.
                                if (!checked && on && page.shownTabs <= 1) {
                                    checked = true;
                                    page.lastTabWarning = true;
                                    warningTimer.restart();
                                    return;
                                }
                                page.lastTabWarning = false;
                                page["cfg_" + wrapper.configKey] = checked;
                            }
                            QQC2.ToolTip.visible: hovered
                            QQC2.ToolTip.text: checked ? Lang.i18n("Shown") : Lang.i18n("Hidden")
                        }
                    }
                }
            }
        }

        RowLayout {
            QQC2.Button {
                icon.name: "edit-undo"
                text: Lang.i18n("Restore default order")
                enabled: page.cfg_pageOrder !== catalog.defaultOrder.join(",")
                onClicked: page.cfg_pageOrder = catalog.defaultOrder.join(",")
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: Lang.i18n("This order only places the tabs. Which live activity the small island shows first (privacy indicators, calls, screen recording…) is set by the priority list in Activities, and urgent events still come first.")
        }

        Kirigami.Heading {
            Layout.topMargin: Kirigami.Units.largeSpacing
            level: 4
            text: Lang.i18n("Modules")
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: Lang.i18n("Parts inside a page. They do not add or remove a tab.")
        }
        QQC2.ItemDelegate {
            Layout.fillWidth: true
            hoverEnabled: false
            down: false
            background: Rectangle { radius: Kirigami.Units.cornerRadius; color: Qt.alpha(Kirigami.Theme.textColor, 0.04) }
            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing
                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                    source: "audio-volume-high"
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    QQC2.Label { Layout.fillWidth: true; text: Lang.i18n("Volume"); elide: Text.ElideRight }
                    QQC2.Label {
                        Layout.fillWidth: true
                        text: Lang.i18n("The volume slider on the Controls page")
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                        elide: Text.ElideRight
                    }
                }
                QQC2.Switch { id: volumeSwitch }
            }
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: Lang.i18n("The buttons of the Controls page and their order are set in Controls; the weather's place in Weather.")
        }
    }
}
