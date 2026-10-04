/*
    SPDX-License-Identifier: GPL-2.0-or-later
    "Upload…" of the Cloud tab: the system's file dialog, for where dragging
    onto the island is not at hand. In its own file, loaded when asked for.
*/
import QtQuick
import QtQuick.Dialogs

FileDialog {
    signal picked(var urls)
    signal cancelled()
    fileMode: FileDialog.OpenFiles
    onAccepted: picked(selectedFiles)
    onRejected: cancelled()
}
