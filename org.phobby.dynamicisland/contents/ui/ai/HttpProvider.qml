/*
    SPDX-License-Identifier: GPL-2.0-or-later

    What the AI tab's network providers share: a question that is answered
    with a time limit (GET), and a question whose answer is read while it is
    written (POST, server-sent events). XMLHttpRequest does both without ever
    making the island wait; every request can be stopped.

    A provider on top of this gives the headers (where its key goes), reads
    one event (interpret) and builds its addresses and bodies. The key is
    only ever put into a header: never into an address, and it is taken out
    of whatever a service says before that is shown (clean); what a service
    says about a key it refused is not shown at all.
*/
import QtQuick
import "AiStream.js" as Stream

AiProvider {
    id: provider

    // ---- what a provider gives ---------------------------------------------------------
    function headers(): var { return {}; }
    // One event's data → { text, cut, end, problem }, each only when it is there.
    function interpret(data: string): var { return {}; }

    // What a service says about a refused key is not repeated at all: some name part of the key in it.
    function clean(problem: var): var {
        return { kind: problem.kind, detail: problem.kind === "auth" ? "" : Stream.scrub(problem.detail, secret) };
    }

    // ---- a question with a time limit ---------------------------------------------------
    property int askTimeout: 15000
    readonly property Component clock: Component { Timer {} }
    // done(status, text); status 0 = no connection, or no answer in time
    function get(url: string, done: var): void {
        const x = new XMLHttpRequest(), timer = clock.createObject(provider, { interval: askTimeout });
        let over = false;
        const end = (status, text) => {
            if (over) return;
            over = true;
            if (timer) timer.destroy();
            done(status, text);
        };
        timer.triggered.connect(() => { end(0, ""); x.abort(); });
        x.onreadystatechange = () => { if (x.readyState === XMLHttpRequest.DONE) end(x.status, x.responseText || ""); };
        x.open("GET", url);
        const h = headers();
        for (const name in h) x.setRequestHeader(name, h[name]);
        x.send();
        timer.start();
    }

    // ---- an answer read while it is written -----------------------------------------------
    property var request: null
    property int serial: 0
    // `again(status, text)` may give another body for a service that refused this one (asked once).
    function post(url: string, body: var, again: var): void {
        cancel();
        const mine = ++serial, x = new XMLHttpRequest(), state = Stream.reader();
        let over = false, cut = false;
        const end = result => {
            if (over || mine !== serial) return;
            over = true;
            request = null;
            finished(result);
        };
        const read = text => {
            for (const e of Stream.events(state, text)) {
                if (over) return;
                const o = interpret(e.data);
                if (o.problem !== undefined) { end({ ok: false, cut: false, problem: clean(o.problem) }); x.abort(); return; }
                if (o.text !== undefined) delta(o.text);
                if (o.cut === true) cut = true;
                if (o.end === true) { end({ ok: true, cut: cut, problem: null }); x.abort(); return; }
            }
        };
        x.onreadystatechange = () => {
            if (over || mine !== serial) return;
            if (x.readyState === XMLHttpRequest.LOADING) {
                alive();
                if (x.status === 200) read(x.responseText);
                return;
            }
            if (x.readyState !== XMLHttpRequest.DONE) return;
            const text = x.responseText || "";
            if (x.status === 200) {
                // what is left, also when the last event has no empty line after it; a stream
                // that ends without saying so is taken as it is
                read(text + "\n\n");
                end({ ok: true, cut: cut, problem: null });
                return;
            }
            const other = x.status !== 0 && again ? again(x.status, text) : null;
            if (other) { post(url, other, null); return; }
            // (status 0 after pieces had come: the connection was cut)
            end({ ok: false, cut: false, problem: clean(Stream.httpProblem(x.status, text)) });
        };
        x.open("POST", url);
        const h = headers();
        for (const name in h) x.setRequestHeader(name, h[name]);
        x.setRequestHeader("Content-Type", "application/json");
        request = x;
        x.send(JSON.stringify(body));
    }
    function cancel(): void {
        ++serial;
        const x = request;
        request = null;
        if (x !== null) x.abort();
    }
    Component.onDestruction: cancel()
}
