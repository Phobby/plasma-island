/*
    SPDX-License-Identifier: GPL-2.0-or-later

    A colour button for the settings pages. KDE's ColorButton opens Qt's own
    colour dialog, a window of its own drawn in Qt's style: white, whatever
    the colour scheme (on a dark desktop a white panel). This one opens a
    picker inside the settings window, in the window's colours: a square
    for how vivid and how bright, a strip for the hue, the colour as
    "#rrggbb", and a row of ready colours. OK takes it, Cancel or a click
    beside it leaves it.

    As ColorButton: `color`, and `accepted(color)` once one is taken.
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

QQC2.Button {
    id: button

    property color color: "#3daee9"
    // (as KDE's ColorButton has it; the picker has no transparency)
    property bool showAlphaChannel: false
    signal accepted(color color)

    implicitWidth: Kirigami.Units.gridUnit * 2.5
    implicitHeight: Kirigami.Units.gridUnit * 1.6
    Accessible.name: Lang.i18n("Choose a colour")
    contentItem: Rectangle {
        radius: Kirigami.Units.cornerRadius / 2
        color: button.color
        opacity: button.enabled ? 1 : 0.4
        border.width: 1
        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.25)
    }
    onClicked: picker.open()

    function hex(c: color): string { return "#" + [c.r, c.g, c.b].map(v => Math.round(v * 255).toString(16).padStart(2, "0")).join(""); }

    QQC2.Popup {
        id: picker
        objectName: "colorPicker"
        parent: QQC2.Overlay.overlay
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        modal: true
        focus: true
        padding: Kirigami.Units.largeSpacing
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside

        // The colour being picked, as hue, how vivid and how bright (0..1).
        property real hue: 0
        property real saturation: 0
        property real value: 0
        readonly property color current: Qt.hsva(hue, saturation, value, 1)
        function take(c: color): void {
            const h = c.hsvHue;
            if (h >= 0) hue = h;            // (a grey has no hue: the one picked stays)
            saturation = c.hsvSaturation;
            value = c.hsvValue;
        }
        onAboutToShow: take(button.color)

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            // how vivid (across) and how bright (down), at this hue
            Rectangle {
                id: field
                objectName: "colorField"
                Layout.fillWidth: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                Layout.preferredHeight: Kirigami.Units.gridUnit * 9
                radius: Kirigami.Units.cornerRadius / 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "white" }
                    GradientStop { position: 1; color: Qt.hsva(picker.hue, 1, 1, 1) }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 1; color: "black" }
                    }
                }
                Rectangle {
                    x: picker.saturation * field.width - width / 2
                    y: (1 - picker.value) * field.height - height / 2
                    width: 12; height: 12; radius: 6
                    color: "transparent"
                    border.width: 2
                    border.color: picker.value > 0.5 && picker.saturation < 0.5 ? "black" : "white"
                }
                MouseArea {
                    anchors.fill: parent
                    function pick(mouse) {
                        picker.saturation = Math.max(0, Math.min(1, mouse.x / width));
                        picker.value = Math.max(0, Math.min(1, 1 - mouse.y / height));
                    }
                    onPressed: mouse => pick(mouse)
                    onPositionChanged: mouse => { if (pressed) pick(mouse); }
                }
            }
            // the hue
            Rectangle {
                id: hues
                objectName: "colorHue"
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit
                radius: height / 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0 / 6; color: "#ff0000" }
                    GradientStop { position: 1 / 6; color: "#ffff00" }
                    GradientStop { position: 2 / 6; color: "#00ff00" }
                    GradientStop { position: 3 / 6; color: "#00ffff" }
                    GradientStop { position: 4 / 6; color: "#0000ff" }
                    GradientStop { position: 5 / 6; color: "#ff00ff" }
                    GradientStop { position: 6 / 6; color: "#ff0000" }
                }
                Rectangle {
                    x: picker.hue * (hues.width - width)
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8; height: hues.height + 4; radius: 4
                    color: "transparent"
                    border.width: 2
                    border.color: "white"
                }
                MouseArea {
                    anchors.fill: parent
                    function pick(mouse) { picker.hue = Math.max(0, Math.min(0.9999, mouse.x / width)); }
                    onPressed: mouse => pick(mouse)
                    onPositionChanged: mouse => { if (pressed) pick(mouse); }
                }
            }
            // ready colours
            Flow {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                Repeater {
                    model: ["#ff3b30", "#ff9500", "#ffd60a", "#30d158", "#00c7be", "#3daee9", "#0a84ff", "#5856d6",
                            "#af52de", "#ff2d55", "#8e8e93", "#4c566a", "#2e3440", "#1a1b1d", "#000000", "#ffffff"]
                    delegate: QQC2.AbstractButton {
                        required property string modelData
                        width: Kirigami.Units.gridUnit * 1.3
                        height: width
                        Accessible.name: modelData
                        onClicked: picker.take(modelData)
                        contentItem: Rectangle {
                            radius: width / 2
                            color: parent.modelData
                            border.width: 1
                            border.color: Qt.alpha(Kirigami.Theme.textColor, parent.hovered ? 0.6 : 0.25)
                        }
                    }
                }
            }
            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                Rectangle {
                    implicitWidth: Kirigami.Units.gridUnit * 2.5
                    implicitHeight: hexField.implicitHeight
                    radius: Kirigami.Units.cornerRadius / 2
                    color: picker.current
                    border.width: 1
                    border.color: Qt.alpha(Kirigami.Theme.textColor, 0.25)
                }
                QQC2.TextField {
                    id: hexField
                    objectName: "colorHex"
                    Layout.fillWidth: true
                    font.family: "monospace"
                    validator: RegularExpressionValidator { regularExpression: /#?[0-9a-fA-F]{0,6}/ }
                    // (shows the colour; what is typed is taken once it is a whole colour)
                    Binding on text { value: button.hex(picker.current); when: !hexField.activeFocus }
                    onTextEdited: {
                        const t = text.startsWith("#") ? text : "#" + text;
                        if (/^#[0-9a-fA-F]{6}$/.test(t)) picker.take(t);
                    }
                    onAccepted: okButton.clicked()
                }
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                QQC2.Button {
                    id: okButton
                    objectName: "colorOk"
                    icon.name: "dialog-ok"
                    text: Lang.i18n("OK")
                    onClicked: { picker.close(); button.accepted(Qt.color(button.hex(picker.current))); }
                }
                QQC2.Button {
                    icon.name: "dialog-cancel"
                    text: Lang.i18n("Cancel")
                    onClicked: picker.close()
                }
            }
        }
    }
}
