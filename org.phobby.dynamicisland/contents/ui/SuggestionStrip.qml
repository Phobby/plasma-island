/*
    SPDX-License-Identifier: GPL-2.0-or-later
    The suggestions that wait quietly (SuggestionProvider.pending): one line
    in the open island, the first of at most three, with its "Why?" under the
    pointer. Yes · Always · No, and behind "⋯" Not now · Turn this rule off.
*/
import QtQuick
import QtQuick.Layouts

Item {
    id: strip

    required property Theme theme
    property var source: null               // SuggestionProvider
    readonly property var list: source !== null ? source.pending : []
    readonly property var first: list.length > 0 ? list[0] : null
    property bool more: false
    onFirstChanged: more = false
    visible: first !== null
    implicitHeight: 30

    function answer(what: string): void { if (first !== null) source.answerPending(first.id, what); }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: strip.theme.faint
    }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 4
        spacing: 6
        ActivityIcon {
            Layout.preferredWidth: 14
            Layout.preferredHeight: 14
            icon: strip.first?.icon ?? ""
            color: strip.first?.color ?? strip.theme.text
        }
        Text {
            objectName: "suggestionText"
            Layout.fillWidth: true
            text: strip.first === null ? "" : hover.hovered ? strip.first.why : strip.first.title + (strip.list.length > 1 ? "  +" + (strip.list.length - 1) : "")
            color: hover.hovered ? strip.theme.subText : strip.theme.text
            font.pointSize: strip.theme.fontSmall * 0.92
            elide: Text.ElideRight
            HoverHandler { id: hover }
        }
        PillButton { objectName: "suggestionYes"; visible: !strip.more; theme: strip.theme; implicitHeight: 22; primary: true; tint: strip.theme.control; text: Lang.i18n("Yes"); onClicked: strip.answer("yes") }
        PillButton { visible: !strip.more; theme: strip.theme; implicitHeight: 22; tint: strip.theme.control; text: Lang.i18n("Always"); onClicked: strip.answer("always") }
        PillButton { objectName: "suggestionNo"; visible: !strip.more; theme: strip.theme; implicitHeight: 22; tint: strip.theme.control; text: Lang.i18n("No"); onClicked: strip.answer("no") }
        PillButton { visible: strip.more; theme: strip.theme; implicitHeight: 22; tint: strip.theme.control; text: Lang.i18n("Not now"); onClicked: strip.answer("later") }
        PillButton { visible: strip.more; theme: strip.theme; implicitHeight: 22; tint: strip.theme.control; text: Lang.i18n("Turn this rule off"); onClicked: strip.answer("never") }
        PillButton { objectName: "suggestionMore"; theme: strip.theme; implicitHeight: 22; tint: strip.theme.control; text: strip.more ? "‹" : "⋯"; onClicked: strip.more = !strip.more }
    }
}
