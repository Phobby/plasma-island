/*
    SPDX-License-Identifier: GPL-2.0-or-later
    KDE Connect file exchange (phone → computer and computer → phone). KDE
    Connect reports its transfers as KDE jobs; the device name becomes the
    source (receiving) or the target (sending).
*/
import QtQuick
import ".."
import "../TransferFormat.js" as Fmt

JobTransferSource {
    id: provider

    kind: "kdeconnect"

    describe: function (info, t) {
        const s = info.summary;
        const receiving = /receiv|from|alın|al[ıi]yor/i.test(s) || /from|kaynak/i.test(info.label1);
        // Device name: "Receiving file from Pixel 7" / "Sending to Pixel 7", or a From/To field.
        const m = s.match(/(?:from|to|'den|'dan|'e|'a)\s+(.+)$/i);
        const device = (m ? m[1] : "") || (receiving ? info.value1 : info.value2) || Lang.i18n("Phone");
        const file = Fmt.baseName(receiving ? (info.destUrl || info.value2) : info.value1) || Fmt.baseName(info.value2);
        t.kind = receiving ? "receive" : "send";
        t.icon = "smartphone-symbolic";
        t.source = receiving ? device : Lang.i18n("Computer");
        t.target = receiving ? Lang.i18n("Computer") : device;
        t.fileName = file;
        t.detail = Lang.i18n("KDE Connect");
        t.openUrl = receiving && info.destUrl ? info.destUrl : "";
    }
}
