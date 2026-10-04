/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Sync state from Syncthing on this computer, through its own REST interface
    (http://127.0.0.1:8384). It needs Syncthing's API key, which the user
    pastes once (Syncthing → Actions → Settings → API Key); it is kept in KDE
    Wallet. Syncthing's configuration file is not read. Asked only while the
    Cloud tab or its indicator wants it.

      /rest/noauth/health        is it there (no key)
      /rest/db/completion        how far along everything is
      /rest/system/error         its errors
      /rest/config/folders       paused folders
*/
import QtQuick
import "Rclone.js" as Rclone

QtObject {
    id: source

    property var core: null
    property string server: "http://127.0.0.1:8384"
    property string secret: ""
    readonly property string name: "Syncthing"
    readonly property bool needsKey: true

    function get(path: string, done: var): void {
        const x = new XMLHttpRequest();
        x.onreadystatechange = () => { if (x.readyState === XMLHttpRequest.DONE) done(x.status, x.responseText || ""); };
        x.open("GET", server + path);
        if (secret.length > 0) x.setRequestHeader("X-API-Key", secret);
        x.send();
    }
    // done({ found, installed, running })
    function detect(done: var): void {
        const installed = core !== null && core.local !== null && core.local.findExecutable("syncthing").length > 0;
        get("/rest/noauth/health", status => done({ found: status === 200 || installed, installed: installed, running: status === 200 }));
    }
    // done({ state, progress, problem }): problem "key" = the key is missing or refused
    function status(done: var): void {
        const parse = text => { try { return JSON.parse(text); } catch (e) { return null; } };
        get("/rest/db/completion", (status, text) => {
            if (status === 0) { done(Object.assign(Rclone.syncthingState(0, false, 0, false), { problem: "" })); return; }
            if (status === 401 || status === 403) { done({ state: "unknown", progress: -1, problem: "key" }); return; }
            const completion = status === 200 && parse(text) ? parse(text).completion : undefined;
            get("/rest/system/error", (s2, t2) => {
                const errors = s2 === 200 && parse(t2) && Array.isArray(parse(t2).errors) ? parse(t2).errors.length : 0;
                get("/rest/config/folders", (s3, t3) => {
                    const folders = s3 === 200 && Array.isArray(parse(t3)) ? parse(t3) : [];
                    const paused = folders.length > 0 && folders.every(f => f && f.paused === true);
                    done(Object.assign(Rclone.syncthingState(completion, paused, errors, true), { problem: "" }));
                });
            });
        });
    }
}
