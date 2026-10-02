/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The clipboard history of Plasma's own clipboard (Klipper): the same
    entries, stars and actions as its popup. `model` rows have the roles
    display (text; editable), decoration (image), imageSize, uuid,
    type (2 = text, 4 = image, 8 = files/links) and starred (writable).
    `filter` narrows the rows to those whose text contains it.
*/
import QtQuick
import org.kde.kitemmodels as KItemModels
import org.kde.plasma.private.clipboard as Private

Item {
    id: clipboard

    readonly property bool available: true
    readonly property var model: proxy
    readonly property int count: history.count
    readonly property int starredCount: history.starredCount
    readonly property string currentText: history.currentText
    property alias starredOnly: history.starredOnly
    property string filter: ""

    // Puts the entry on the clipboard (it moves to the top of the history).
    function copy(uuid: string): void { history.moveToTop(uuid); }
    function remove(uuid: string): void { history.remove(uuid); }
    // Klipper's own confirmation is skipped; the page asks itself.
    function clear(): void { history.clearHistory(); }
    // The actions configured in Klipper for this kind of content.
    function runAction(uuid: string): void { history.invokeAction(uuid); }

    Private.HistoryModel { id: history }
    KItemModels.KSortFilterProxyModel {
        id: proxy
        sourceModel: history
        filterRoleName: "display"
        filterRegularExpression: RegExp(clipboard.filter.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "i")
    }
}
