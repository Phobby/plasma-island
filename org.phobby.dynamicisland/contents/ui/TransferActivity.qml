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
    property string kind: "copy"      // download | upload | copy | move | receive | send | delete | extract | packages | clone
    property string icon: "view-refresh-symbolic"
    property string detail            // secondary text: the stage ("Downloading", "Installing packages")

    property real percent: -1         // 0..100, < 0 = unknown (indeterminate)
    property real speed: 0            // bytes/s, 0 = unknown
    property real processedBytes: 0
    property real totalBytes: 0
    property real etaSeconds: -1      // from the source, < 0 = not provided

    // running | done | failed | cancelled | unknown. "unknown": it ended and nothing says how
    // (a command whose exit code cannot be seen): neither called a success nor a failure.
    property string state: "running"
    property bool suspended: false
    // Seconds without a byte (a download paused in the browser); 0 = moving, or not told.
    property int stalled: 0
    // When it was first seen (ms), for "how long it took"; set by the provider's clock.
    property real startedAt: 0
    property real endedAt: 0
    readonly property real elapsedSeconds: startedAt > 0 && endedAt >= startedAt ? (endedAt - startedAt) / 1000 : -1
    // The size is known: a percentage and a remaining time may be shown. Never made up.
    readonly property bool totalKnown: totalBytes > 0
    property string errorText
    // For the provider's own bookkeeping: on the hub's list / reported by another source too.
    property bool shown: false
    property bool hidden: false
    property string openUrl           // file or folder to open when done
    property bool openIsFolder: false // the button says "Open folder"
    property string doneTitle         // the provider's own word for "done" ("Installed"); "" = the usual one

    // Optional controls (functions), set by the provider when supported.
    property var suspendFn: null
    property var resumeFn: null
    property var cancelFn: null
    // Starts the same transfer again; offered on its "Failed" event when it is set.
    property var retryFn: null

    // "Zen - video.mp4" / "Pixel 7 → Computer: photo.jpg" / "USB DISK → Documents: report.pdf"
    readonly property string headline: target.length > 0
        ? source + " → " + target + (fileName ? ": " + fileName : "")
        : source + (fileName ? " - " + fileName : "")

    // Remaining time: the source's own value, else from the (smoothed) speed when the total
    // is known; else unknown (-1). Not while it stands still.
    readonly property real remaining: suspended || stalled > 2 ? -1 : etaSeconds > 0 ? etaSeconds
        : (speed > 0 && totalBytes > processedBytes ? (totalBytes - processedBytes) / speed : -1)
}
