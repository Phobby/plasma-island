/*
    SPDX-License-Identifier: GPL-2.0-or-later

    TransferActivity: the common interface every transfer provider fills in
    (KIO jobs, KDE Connect, removable drives, browser downloads, …) and the
    TransferHub renders.
*/
import QtQuick

QtObject {
    id: transfer

    property string transferId
    property string source            // "Zen", "Pixel 7", "USB DISK", "Dolphin"
    property string target            // "Computer", "Documents", "USB DISK" (optional)
    property string fileName          // "video.mp4"
    property string kind: "copy"      // download | upload | copy | move | receive | send | delete | extract
    property string icon: "view-refresh-symbolic"
    property string detail            // secondary text (e.g. "Copying")

    property real percent: -1         // 0..100, < 0 = unknown (indeterminate)
    property real speed: 0            // bytes/s, 0 = unknown
    property real processedBytes: 0
    property real totalBytes: 0
    property real etaSeconds: -1      // from the source, < 0 = not provided

    property string state: "running"  // running | done | failed | cancelled
    property bool suspended: false
    property string errorText
    property string openUrl           // file or folder to open when done

    // Optional controls (functions), set by the provider when supported.
    property var suspendFn: null
    property var resumeFn: null
    property var cancelFn: null

    // "Zen - video.mp4" / "Pixel 7 → Computer: photo.jpg" / "USB DISK → Documents: report.pdf"
    readonly property string headline: target.length > 0
        ? source + " → " + target + (fileName ? ": " + fileName : "")
        : source + (fileName ? " - " + fileName : "")

    // Remaining time: the source's own value, else estimated from speed; else unknown.
    readonly property real remaining: etaSeconds > 0 ? etaSeconds
        : (speed > 0 && totalBytes > processedBytes ? (totalBytes - processedBytes) / speed : -1)
}
