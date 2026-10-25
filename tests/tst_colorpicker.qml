/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The settings pages' colour button (ColorPickerButton.qml): its picker
    opens inside the window, in the window's colours, with the button's
    colour; the square, the hue strip, a ready colour and a typed "#rrggbb"
    change it; OK hands it over, Cancel and Escape do not.
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtTest
import "../org.phobby.dynamicisland/contents/ui"

Item {
    id: root
    width: 700
    height: 600

    property var taken: []
    ColorPickerButton {
        id: button
        x: 20; y: 20
        color: "#3daee9"
        onAccepted: c => root.taken = root.taken.concat([String(c)])
    }

    TestCase {
        name: "ColorPicker"
        when: windowShown

        function find(item, name) { if (item.objectName === name) return item; for (const c of item.children) { const f = find(c, name); if (f) return f; } return null; }
        function findPopup() { for (const c of button.data) if (c.objectName === "colorPicker") return c; return null; }
        function init() { root.taken = []; }

        function test_1_opens_with_its_colour_inside_the_window() {
            mouseClick(button);
            const p = findPopup();
            tryVerify(() => p.opened, 1000);
            compare(p.parent, button.QQC2.Overlay.overlay, "in the window, not a window of its own");
            compare(button.hex(p.current), "#3daee9");
            keyClick(Qt.Key_Escape);
            tryVerify(() => !p.visible, 1000);
            compare(root.taken, [], "Escape takes nothing");
        }

        function test_2_square_strip_typed_and_ok() {
            const p = findPopup();
            p.open(); tryVerify(() => p.opened, 1000);
            const field = find(p.contentItem, "colorField"), hues = find(p.contentItem, "colorHue");
            // the hue strip at its start: red; the square's top right: the vivid, bright one
            mouseClick(hues, 1, hues.height / 2);
            mouseClick(field, field.width - 1, 1);
            // (within a pixel of the ends)
            verify(p.hue < 0.01 && p.saturation > 0.98 && p.value > 0.98, button.hex(p.current));
            // its bottom: black
            mouseClick(field, field.width / 2, field.height - 2);
            verify(p.value < 0.03, "dark at the bottom: " + p.value);
            // typed
            const hex = find(p.contentItem, "colorHex");
            hex.forceActiveFocus(); hex.selectAll();
            keyClick(Qt.Key_Backspace);
            for (const ch of "30d158") keyClick(ch);
            compare(button.hex(p.current), "#30d158");
            mouseClick(find(p.contentItem, "colorOk"));
            tryVerify(() => !p.visible, 1000);
            compare(root.taken, [String(Qt.color("#30d158"))]);
        }

        function test_3_cancel_takes_nothing() {
            const p = findPopup();
            p.open(); tryVerify(() => p.opened, 1000);
            p.take("#ff3b30");
            p.close();
            tryVerify(() => !p.visible, 1000);
            compare(root.taken, []);
        }
    }
}
