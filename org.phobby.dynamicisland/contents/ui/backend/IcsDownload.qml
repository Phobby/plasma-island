/*
    SPDX-License-Identifier: GPL-2.0-or-later

    One download of a calendar link (.ics), with an end to it. A link is
    somebody else's server, and what it sends is held in memory and parsed:
    so no more than `limit` is taken and no longer than `timeout` is waited.
    What is cut off is dropped whole, never read in part.
*/
import QtQuick

QtObject {
    id: download

    property int limit: 10 * 1024 * 1024    // characters of the text: about as many bytes
    property int timeout: 30000             // ms, from asking to the last of the file

    readonly property int tooLarge: -1
    readonly property int tooLate: -2
    readonly property Component clock: Component { Timer {} }

    // done(status, text): the server's status and what it sent; 0 = no
    // connection, tooLarge = more than `limit`, tooLate = not there in `timeout`.
    function get(url: string, done: var): void {
        const xhr = new XMLHttpRequest(), timer = clock.createObject(download, { interval: timeout });
        let over = false, looked = 0;
        const end = (status, text) => {
            if (over) return;
            over = true;
            timer.destroy();
            done(status, text);
        };
        // (Aborting from inside the request's own callback crashes Qt's XMLHttpRequest: a moment later.)
        const cut = status => { end(status, ""); Qt.callLater(() => xhr.abort()); };
        timer.triggered.connect(() => { end(tooLate, ""); xhr.abort(); });
        xhr.onreadystatechange = () => {
            if (over) return;
            if (xhr.readyState === XMLHttpRequest.HEADERS_RECEIVED) {
                // Too large by its own account: not downloaded at all.
                if (Number(xhr.getResponseHeader("Content-Length")) > limit) cut(tooLarge);
            } else if (xhr.readyState === XMLHttpRequest.LOADING) {
                // No length was given, or a wrong one: what has come so far is looked
                // at twice a second (every look copies all of it).
                const now = Date.now();
                if (now - looked < 500) return;
                looked = now;
                if ((xhr.responseText || "").length > limit) cut(tooLarge);
            } else if (xhr.readyState === XMLHttpRequest.DONE) {
                const text = xhr.responseText || "";
                if (text.length > limit) end(tooLarge, ""); else end(xhr.status, text);
            }
        };
        xhr.open("GET", url);
        // Always the server's current copy, never one cached on the way.
        xhr.setRequestHeader("Cache-Control", "no-cache");
        xhr.setRequestHeader("Pragma", "no-cache");
        xhr.send();
        timer.start();
    }
}
