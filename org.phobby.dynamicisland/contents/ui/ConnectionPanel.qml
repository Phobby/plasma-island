/*
    SPDX-License-Identifier: GPL-2.0-or-later
    What holding the Bluetooth, Wi-Fi or VPN button of the Controls page
    opens: the devices / networks / connections as a list, "Scan" and
    "Add new" above it. A click on a row connects or lets go; a new Wi-Fi
    network with a key asks for it here first.
    `rows` is a list of { key, icon, name, detail, active, busy, locked,
    needsPassword }; the page that owns the panel builds it and acts on
    rowClicked(key, password).
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: panel

    required property Theme theme
    property string title
    property var rows: []
    property bool canScan: true
    property bool scanning: false
    // The radio is off: nothing to list, a button to turn it on instead.
    property bool off: false
    property string offText
    property string emptyText
    property string failure
    signal closed()
    signal scanClicked()
    signal addClicked()
    signal turnOnClicked()
    signal rowClicked(string key, string password)

    // The row whose password is being typed (null: the list is shown).
    property var asking: null
    readonly property bool typing: asking !== null
    onVisibleChanged: if (!visible) asking = null
    function submit(): void {
        if (asking === null || password.text.length === 0) return;
        const key = asking.key, text = password.text;
        asking = null;
        rowClicked(key, text);
    }

    // The rows are kept in a model that is changed in place: a list that is
    // rebuilt whenever a signal strength moves would jump back to its top.
    ListModel { id: shown }
    onRowsChanged: {
        const list = rows || [];
        for (let i = 0; i < list.length; ++i) {
            const r = list[i];
            const row = { key: r.key, icon: r.icon, name: r.name, detail: r.detail || "", active: r.active === true,
                          busy: r.busy === true, locked: r.locked === true, needsPassword: r.needsPassword === true };
            if (i < shown.count) shown.set(i, row); else shown.append(row);
        }
        if (shown.count > list.length) shown.remove(list.length, shown.count - list.length);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            IconButton {
                objectName: "panelBack"
                iconName: "go-previous-symbolic"
                color: panel.theme.text
                hoverColor: panel.theme.hoverFill
                onClicked: if (panel.asking !== null) panel.asking = null; else panel.closed()
            }
            Text {
                Layout.fillWidth: true
                text: panel.title
                color: panel.theme.text
                font.pointSize: panel.theme.fontNormal
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            PillButton {
                objectName: "panelScan"
                theme: panel.theme
                implicitHeight: 22
                visible: panel.canScan && !panel.off && !panel.typing
                text: panel.scanning ? Lang.i18n("Scanning…") : Lang.i18n("Scan")
                onClicked: panel.scanClicked()
            }
            PillButton {
                objectName: "panelAdd"
                theme: panel.theme
                implicitHeight: 22
                visible: !panel.typing
                text: Lang.i18n("Add new")
                onClicked: panel.addClicked()
            }
        }

        // The key of a new Wi-Fi network
        ColumnLayout {
            visible: panel.typing
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6
            Text {
                Layout.fillWidth: true
                text: panel.asking !== null ? Lang.i18n("Password for %1", panel.asking.name) : ""
                color: panel.theme.subText
                font.pointSize: panel.theme.fontSmall
                elide: Text.ElideRight
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                PillField {
                    id: password
                    objectName: "panelPassword"
                    Layout.fillWidth: true
                    theme: panel.theme
                    secret: true
                    placeholder: Lang.i18n("Password")
                    onAccepted: panel.submit()
                    onEscaped: panel.asking = null
                    onVisibleChanged: { text = ""; if (visible) input.forceActiveFocus(); }
                }
                PillButton {
                    objectName: "panelConnect"
                    theme: panel.theme
                    primary: true
                    enabled: password.text.length > 0
                    text: Lang.i18n("Connect")
                    onClicked: panel.submit()
                }
            }
            Item { Layout.fillHeight: true }
        }

        IslandListView {
            id: list
            objectName: "panelList"
            visible: !panel.typing && !panel.off && shown.count > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2
            model: shown
            delegate: Rectangle {
                id: row
                required property string key
                required property string icon
                required property string name
                required property string detail
                required property bool active
                required property bool busy
                required property bool locked
                required property bool needsPassword
                width: list.width
                height: 28
                radius: 14
                color: rowMouse.pressed ? panel.theme.pressedFill : rowMouse.containsMouse ? panel.theme.hoverFill : "transparent"
                opacity: busy ? 0.6 : 1
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 10
                    spacing: 8
                    Kirigami.Icon {
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        source: row.icon
                        color: row.active ? panel.theme.control : panel.theme.text
                        isMask: true
                    }
                    Text {
                        Layout.fillWidth: true
                        text: row.name
                        color: panel.theme.text
                        font.pointSize: panel.theme.fontSmall
                        font.weight: row.active ? Font.DemiBold : Font.Normal
                        elide: Text.ElideRight
                    }
                    Text {
                        visible: text.length > 0
                        Layout.maximumWidth: row.width * 0.45
                        text: row.detail
                        color: row.active ? panel.theme.control : panel.theme.subText
                        font.pointSize: panel.theme.fontSmall * 0.95
                        font.features: { "tnum": 1 }
                        elide: Text.ElideRight
                    }
                    Kirigami.Icon {
                        visible: row.locked
                        Layout.preferredWidth: 12
                        Layout.preferredHeight: 12
                        source: "object-locked-symbolic"
                        color: panel.theme.subText
                        isMask: true
                    }
                }
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (row.busy) return;
                        if (row.needsPassword) panel.asking = { key: row.key, name: row.name };
                        else panel.rowClicked(row.key, "");
                    }
                }
            }
        }

        // Nothing to list: off, or nothing found
        ColumnLayout {
            visible: !panel.typing && (panel.off || shown.count === 0)
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6
            Item { Layout.fillHeight: true }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: panel.off ? panel.offText : panel.scanning ? Lang.i18n("Scanning…") : panel.emptyText
                color: panel.theme.subText
                font.pointSize: panel.theme.fontSmall
                wrapMode: Text.WordWrap
            }
            PillButton {
                objectName: "panelTurnOn"
                Layout.alignment: Qt.AlignHCenter
                visible: panel.off
                theme: panel.theme
                primary: true
                text: Lang.i18n("Turn on")
                onClicked: panel.turnOnClicked()
            }
            Item { Layout.fillHeight: true }
        }

        Text {
            visible: panel.failure.length > 0 && !panel.typing
            Layout.fillWidth: true
            text: panel.failure
            color: panel.theme.danger
            font.pointSize: panel.theme.fontSmall * 0.95
            elide: Text.ElideRight
        }
    }
}
