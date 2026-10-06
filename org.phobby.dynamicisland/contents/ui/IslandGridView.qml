/*
    SPDX-License-Identifier: GPL-2.0-or-later
    The GridView of the island's pages: it keeps its scroll (IslandScroll),
    stops at its ends and cuts off what does not fit.
*/
import QtQuick

GridView {
    id: view
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    IslandScroll { area: view }
}
