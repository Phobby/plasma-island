/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Connect a calendar without leaving the island: pick Google Calendar or
    Apple iCloud, follow the short instructions, paste the link. The link is
    downloaded once to make sure it really is a calendar, then `added(source)`
    is emitted. `interacting` asks the island for keyboard focus while a text
    field is shown.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: connect

    required property Theme theme
    property var sources: []
    signal added(var source)
    signal cancelled()

    // "pick" → "link" → "name"
    property string step: "pick"
    property string type: "google"
    property string device: "iphone"          // which Apple instructions are shown
    property string error: ""
    property bool busy: false
    property string url: ""
    property int count: 0
    property string color: links.palette[0]
    readonly property bool interacting: step !== "pick"

    CalendarLinks { id: links; sources: connect.sources }

    function reset(): void {
        step = "pick"; error = ""; busy = false; url = ""; count = 0;
        linkInput.text = ""; nameInput.text = "";
        color = links.freeColor();
    }
    function tryConnect(): void {
        error = links.formatProblem(linkInput.text);
        if (error !== "" || busy) return;
        busy = true;
        const candidate = linkInput.text;
        links.check(candidate, result => {
            busy = false;
            if (!result.ok) { error = result.error; return; }
            url = links.normalize(candidate);
            count = result.count;
            nameInput.text = result.name;       // only a suggestion
            step = "name";
        });
    }
    function finish(): void {
        if (nameInput.text.trim().length === 0) { error = i18n("Takvime kısa bir ad ver (ör. İş, Kişisel)."); return; }
        if (links.isConnected(url)) { error = i18n("Bu takvim zaten bağlı."); return; }
        added(links.makeSource(type, url, nameInput.text, color));
        reset();
    }
    onStepChanged: Qt.callLater(() => { if (step === "link") linkInput.forceActiveFocus(); else if (step === "name") nameInput.forceActiveFocus(); })

    component PillButton: Rectangle {
        property string text
        property bool primary: false
        signal clicked()
        implicitWidth: pillLabel.implicitWidth + 22
        implicitHeight: 26
        radius: 13
        readonly property color fill: primary ? connect.theme.blue : connect.theme.faint
        color: pillMouse.pressed ? Qt.darker(fill, 1.2) : pillMouse.containsMouse && !primary ? connect.theme.over(connect.theme.hoverFill, connect.theme.over(fill, connect.theme.surface)) : fill
        opacity: enabled ? 1 : 0.4
        scale: pillMouse.pressed ? 0.95 : pillMouse.containsMouse ? 1.05 : 1
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Text {
            id: pillLabel
            anchors.centerIn: parent
            text: parent.text
            color: parent.primary ? connect.theme.onColor(connect.theme.blue) : connect.theme.text
            font.pointSize: connect.theme.fontSmall
            font.weight: Font.DemiBold
        }
        MouseArea { id: pillMouse; anchors.fill: parent; enabled: parent.enabled; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
    }
    component Field: Rectangle {
        property alias input: fieldInput
        property string placeholder
        signal accepted()
        implicitHeight: 28
        radius: 14
        color: connect.theme.faint
        border.width: 1
        border.color: fieldInput.activeFocus ? connect.theme.blue : "transparent"
        TextInput {
            id: fieldInput
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            color: connect.theme.text
            selectionColor: connect.theme.blue
            font.pointSize: connect.theme.fontSmall
            clip: true
            selectByMouse: true
            onAccepted: parent.accepted()
            onTextEdited: connect.error = ""
            Keys.onEscapePressed: connect.cancelled()
        }
        Text {
            anchors.fill: fieldInput
            verticalAlignment: Text.AlignVCenter
            visible: fieldInput.text.length === 0
            text: parent.placeholder
            color: connect.theme.subText
            font.pointSize: connect.theme.fontSmall
            elide: Text.ElideRight
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        // ---- header ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            IconButton {
                visible: connect.step !== "pick"
                iconName: "go-previous-symbolic"
                color: connect.theme.text
                hoverColor: connect.theme.faint
                enabled: !connect.busy
                onClicked: { connect.error = ""; connect.step = connect.step === "name" ? "link" : "pick"; }
            }
            Kirigami.Icon {
                visible: connect.step !== "pick"
                Layout.preferredWidth: 14
                Layout.preferredHeight: 14
                source: links.typeIcons[connect.type]
                color: connect.theme.text
                isMask: true
            }
            Text {
                Layout.fillWidth: true
                text: connect.step === "pick" ? i18n("Takvim Bağla") : links.typeNames[connect.type]
                color: connect.theme.text
                font.pointSize: connect.theme.fontSmall
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            // Apple: which device the instructions are for
            Repeater {
                model: connect.step === "link" && connect.type === "apple" ? [{ key: "iphone", text: "iPhone / iPad" }, { key: "mac", text: "Mac" }] : []
                delegate: Rectangle {
                    required property var modelData
                    implicitWidth: deviceLabel.implicitWidth + 16
                    implicitHeight: 20
                    radius: 10
                    color: connect.device === modelData.key ? connect.theme.faint : "transparent"
                    Text {
                        id: deviceLabel
                        anchors.centerIn: parent
                        text: parent.modelData.text
                        color: connect.device === parent.modelData.key ? connect.theme.text : connect.theme.subText
                        font.pointSize: connect.theme.fontSmall * 0.9
                        font.weight: Font.DemiBold
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: connect.device = parent.modelData.key }
                }
            }
            IconButton {
                iconName: "window-close-symbolic"
                color: connect.theme.subText
                hoverColor: connect.theme.faint
                onClicked: connect.cancelled()
            }
        }

        // ---- step 1: which calendar ----
        RowLayout {
            visible: connect.step === "pick"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8
            Repeater {
                model: ["google", "apple"]
                delegate: Rectangle {
                    id: tile
                    required property string modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    radius: 14
                    color: tileMouse.pressed ? connect.theme.pressedFill
                         : tileMouse.containsMouse ? connect.theme.over(connect.theme.hoverFill, connect.theme.over(connect.theme.faint, connect.theme.surface))
                         : connect.theme.faint
                    scale: tileMouse.pressed ? 0.97 : tileMouse.containsMouse ? 1.03 : 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Kirigami.Icon {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            source: links.typeIcons[tile.modelData]
                            color: connect.theme.text
                            isMask: true
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: links.typeNames[tile.modelData]
                            color: connect.theme.text
                            font.pointSize: connect.theme.fontSmall
                            font.weight: Font.DemiBold
                        }
                    }
                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { connect.type = tile.modelData; connect.error = ""; connect.step = "link"; }
                    }
                }
            }
        }

        // ---- step 2: instructions + link ----
        Flickable {
            visible: connect.step === "link"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: steps.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: steps
                width: parent.width
                spacing: 3
                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    text: connect.type === "google" ? links.instructions.google : links.instructions[connect.device]
                    color: connect.theme.text
                    font.pointSize: connect.theme.fontSmall * 0.9
                }
                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: links.secretWarning
                    color: connect.theme.subText
                    font.pointSize: connect.theme.fontSmall * 0.85
                }
            }
        }

        // ---- step 3: name + colour ----
        ColumnLayout {
            visible: connect.step === "name"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6
            Text {
                Layout.fillWidth: true
                text: i18np("Takvim bulundu: %1 etkinlik içeriyor.", "Takvim bulundu: %1 etkinlik içeriyor.", connect.count)
                color: connect.theme.subText
                font.pointSize: connect.theme.fontSmall
            }
            Row {
                spacing: 8
                Repeater {
                    model: links.palette
                    delegate: Rectangle {
                        required property string modelData
                        width: 20; height: 20; radius: 10
                        color: modelData
                        border.width: connect.color === modelData ? 2.5 : 0
                        border.color: connect.theme.text
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: connect.color = parent.modelData }
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }

        Text {
            Layout.fillWidth: true
            visible: connect.error.length > 0
            text: connect.error
            color: connect.theme.readable(connect.theme.danger, connect.theme.surface)
            font.pointSize: connect.theme.fontSmall * 0.9
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        // ---- input row ----
        RowLayout {
            visible: connect.step !== "pick"
            Layout.fillWidth: true
            spacing: 6
            Field {
                id: linkField
                visible: connect.step === "link"
                Layout.fillWidth: true
                placeholder: "Paste your calendar link here"
                enabled: !connect.busy
                onAccepted: connect.tryConnect()
            }
            IconButton {
                visible: connect.step === "link"
                iconName: "edit-paste-symbolic"
                color: connect.theme.text
                hoverColor: connect.theme.faint
                enabled: !connect.busy
                onClicked: { linkInput.forceActiveFocus(); linkInput.selectAll(); linkInput.paste(); connect.error = ""; }
            }
            Field {
                id: nameField
                visible: connect.step === "name"
                Layout.fillWidth: true
                placeholder: i18n("Takvimin adı (ör. İş, Kişisel)")
                onAccepted: connect.finish()
            }
            PillButton {
                visible: connect.step === "link"
                primary: true
                text: connect.busy ? i18n("Kontrol ediliyor…") : i18n("Bağla")
                enabled: !connect.busy
                onClicked: connect.tryConnect()
            }
            PillButton {
                visible: connect.step === "name"
                primary: true
                text: i18n("Ekle")
                onClicked: connect.finish()
            }
        }
    }

    readonly property TextInput linkInput: linkField.input
    readonly property TextInput nameInput: nameField.input
}
