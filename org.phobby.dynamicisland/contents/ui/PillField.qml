/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Single-line text field for the pages inside the island.
*/
import QtQuick

Rectangle {
    id: field

    required property Theme theme
    property alias input: fieldInput
    property alias text: fieldInput.text
    property string placeholder
    property bool secret: false
    signal accepted()
    signal edited()
    signal escaped()

    implicitHeight: 28
    radius: height / 2
    color: theme.faint
    border.width: 1
    border.color: fieldInput.activeFocus ? theme.control : "transparent"

    TextInput {
        id: fieldInput
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        verticalAlignment: TextInput.AlignVCenter
        color: field.theme.text
        selectionColor: field.theme.control
        font.pointSize: field.theme.fontSmall
        echoMode: field.secret ? TextInput.Password : TextInput.Normal
        clip: true
        selectByMouse: true
        onAccepted: field.accepted()
        onTextEdited: field.edited()
        Keys.onEscapePressed: field.escaped()
    }
    Text {
        textFormat: Text.PlainText
        anchors.fill: fieldInput
        verticalAlignment: Text.AlignVCenter
        visible: fieldInput.text.length === 0
        text: field.placeholder
        color: field.theme.subText
        font.pointSize: field.theme.fontSmall
        elide: Text.ElideRight
    }
}
