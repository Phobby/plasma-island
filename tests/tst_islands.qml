/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The widget added twice to one screen: only the island that came first
    shows its window (Islands.qml); one island per screen stays possible.
*/
import QtQuick
import QtTest
import "../org.phobby.dynamicisland/contents/ui"

Item {
    id: root
    width: 100
    height: 100

    component Stand: QtObject {
        property string screenKey: "0,0"
        readonly property bool leads: Islands.leads(this)
    }
    Stand { id: first }
    Stand { id: second }
    Stand { id: other; screenKey: "1920,0" }

    TestCase {
        name: "Islands"

        function init() { for (const i of [first, second, other]) Islands.leave(i); second.screenKey = "0,0"; }

        function test_alone_or_not_joined_yet_it_shows() {
            verify(first.leads && second.leads);
            Islands.join(first);
            verify(first.leads);
        }
        function test_the_second_on_one_screen_stays_hidden() {
            Islands.join(first); Islands.join(second); Islands.join(other);
            compare([first.leads, second.leads, other.leads], [true, false, true]);
            Islands.join(second);           // (joining twice changes nothing)
            compare(Islands.all.length, 3);
        }
        function test_it_shows_once_the_first_is_removed_or_it_moves_to_another_screen() {
            Islands.join(first); Islands.join(second);
            compare(second.leads, false);
            second.screenKey = "0,1080";
            compare(second.leads, true);
            second.screenKey = "0,0";
            compare(second.leads, false);
            Islands.leave(first);
            compare(second.leads, true);
        }
    }
}
