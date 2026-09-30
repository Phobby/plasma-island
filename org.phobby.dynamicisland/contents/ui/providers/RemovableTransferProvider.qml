/*
    SPDX-License-Identifier: GPL-2.0-or-later
    Copies to / from removable drives (USB sticks, external disks, SD cards —
    mounted under /media or /run/media). The drive's label names the source
    (import) or the target (export).
*/
import QtQuick
import ".."
import "../TransferFormat.js" as Fmt

JobTransferSource {
    id: provider

    kind: "removable"

    describe: function (info, t) {
        const src = Fmt.field(info, "source"), dst = Fmt.field(info, "destination") || info.destUrl;
        const fromDrive = Fmt.removableLabel(src), toDrive = Fmt.removableLabel(dst) || Fmt.removableLabel(info.destUrl);
        const moving = /mov|taşı/i.test(info.summary);
        t.kind = moving ? "move" : "copy";
        t.icon = "drive-removable-media-usb";
        t.source = fromDrive || Fmt.folderName(src) || info.app;
        t.target = toDrive || Fmt.folderName(dst);
        t.fileName = Fmt.baseName(src);
        t.detail = info.summary;
        t.openUrl = dst ? String(dst).replace(/\/[^\/]*$/, "") : "";
    }
}
