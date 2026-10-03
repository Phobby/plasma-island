/*
    SPDX-License-Identifier: GPL-2.0-or-later
    File operations through KIO (Dolphin copy/move/delete, Ark extraction,
    kioclient, uploads to remote places such as sftp:// / smb:// / MTP …).
    Feeds the TransferHub; KDE Connect, removable-drive and browser jobs are
    handled by their own providers.
*/
import QtQuick
import ".."
import "../TransferFormat.js" as Fmt

JobTransferSource {
    id: provider

    kind: "kio"

    function kindOf(summary: string): string {
        const s = summary.toLowerCase();
        if (/delet|trash|sil|çöp/.test(s)) return "delete";
        if (/mov|taşı/.test(s)) return "move";
        if (/extract|unpack|çıkar|aç/.test(s)) return "extract";
        if (/download|indir/.test(s)) return "download";
        if (/upload|send|gönder|yükle/.test(s)) return "upload";
        return "copy";
    }
    function iconFor(kind: string): string {
        return { copy: "edit-copy-symbolic", move: "transform-move", delete: "edit-delete-symbolic",
                 extract: "archive-extract", download: "download", upload: "document-send-symbolic" }[kind] ?? "view-refresh-symbolic";
    }

    describe: function (info, t) {
        const src = Fmt.field(info, "source"), dst = Fmt.field(info, "destination") || info.destUrl;
        t.kind = kindOf(info.summary);
        t.icon = iconFor(t.kind);
        t.source = info.app || Lang.i18n("Files");
        t.fileName = Fmt.baseName(src) || Fmt.baseName(dst);
        // Remote destinations (sftp, smb, mtp, kdeconnect…) are uploads.
        if (/^(sftp|smb|ftp|ftps|webdav|webdavs|mtp|fish|nfs):/.test(String(dst))) t.kind = "upload";
        t.detail = dst ? Lang.i18nc("@info operation → folder", "%1 → %2", info.summary, Fmt.folderName(dst)) : info.summary;
        t.openUrl = dst && t.kind !== "delete" ? String(dst).replace(/\/[^\/]*$/, "") : "";
    }
}
