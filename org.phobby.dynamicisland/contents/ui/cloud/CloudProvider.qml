/*
    SPDX-License-Identifier: GPL-2.0-or-later

    What a cloud is to the Cloud tab: a place whose folders can be listed by
    name, whose room can be asked for, and to and from which a file can be
    copied. A new kind of cloud is a file of its own with this type as its
    root. Sync state is a separate thing (see *Status.qml): a cloud may have a
    source for it or none.

      list(path, done)      done({ ok, entries, more, problem }): one level
      about(done)           done({ ok, about: { used, total, free } | null })
      size(path, done)      done({ ok, count, bytes })
      download(path, local, folder, progress, done)   returns a job (cancel())
      upload(local, path, folder, overwrite, progress, done)
                            progress({ bytes, total, speed, eta, percent });
                            done({ ok, cancelled, problem })

    Nothing here can delete, move or rename; nothing blocks the island.
*/
import QtQuick

QtObject {
    property var core: null
    function list(path: string, done: var): void { done({ ok: false, entries: [], more: false, problem: { kind: "unknown", detail: "" } }); }
    function about(done: var): void { done({ ok: true, about: null }); }
    function size(path: string, done: var): void { done({ ok: false, count: 0, bytes: 0 }); }
    function download(path: string, local: string, folder: bool, progress: var, done: var): var { done({ ok: false, cancelled: false, problem: { kind: "unknown", detail: "" } }); return null; }
    function upload(local: string, path: string, folder: bool, overwrite: bool, progress: var, done: var): var { done({ ok: false, cancelled: false, problem: { kind: "unknown", detail: "" } }); return null; }
}
