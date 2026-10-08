/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Every island of this shell. The widget can be added more than once (twice
    to one desktop, to a panel and to the desktop): each has a window of its
    own at the same place, one over the other. They look like one until one of
    them opens: then the other still stands there as a pill, with a cat of its
    own. So on one screen only the island that came first shows its window;
    one island per screen stays possible.

    An island is anything with a `screenKey` (which screen it is on).
*/
pragma Singleton
import QtQuick

QtObject {
    // in the order they came
    property var all: []
    function join(island: QtObject): void { if (all.indexOf(island) < 0) all = all.concat([island]); }
    function leave(island: QtObject): void { all = all.filter(i => i !== island); }
    // The first island on its screen (also one that has not joined yet, or is alone).
    function leads(island: QtObject): bool {
        for (const other of all) {
            if (other === island) return true;
            if (other.screenKey === island.screenKey) return false;
        }
        return true;
    }
}
