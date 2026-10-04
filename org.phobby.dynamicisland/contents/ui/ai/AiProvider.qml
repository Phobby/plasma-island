/*
    SPDX-License-Identifier: GPL-2.0-or-later

    What every source of answers of the AI tab is: Claude Code on this
    computer, a model server on this computer, a service with a key. AiBackend
    only ever talks to this; a new source is a file of its own with this type
    as its root, named in AiCatalog.qml.

      detect(done)     is it on this computer? done({ found, … }); never starts
                       or installs anything
      verify(done)     for connecting: does it answer, is the key accepted?
                       done({ ok, models, problem })
      listModels(done) done({ ok, models: [{ id, name }], problem })
      send(messages, model, options)
                       the answer arrives as `delta(text)` pieces and ends with
                       exactly one `finished(result)`
                         messages  [{ role: "user" | "assistant", text }], the
                                   question last
                         options   { system, maxTokens }
                         result    { ok, cut, problem }: cut = stopped at the
                                   length limit; problem = { kind, detail } in
                                   the words of AiStream.js, null when ok
      cancel()         stops the running request; no `finished` follows

    Nothing here blocks: a command runs beside the shell and the network is
    asked asynchronously, so the island never waits. Text answers only: no
    source is ever given a tool, a file or anything the user did not type.
*/
import QtQuick

QtObject {
    id: provider

    // Set by AiBackend before a call.
    property var core: null             // NativeBridge: a command needs it, the network does not
    property string server: ""          // where the service is ("" for a command)
    property string secret: ""          // its key, held only in memory ("" where there is none)
    property var options: ({})          // what AiCatalog.qml says about this kind

    signal delta(string text)
    signal finished(var result)
    // Something arrived, text or not: the request is not hanging.
    signal alive()

    function detect(done: var): void { done({ found: false }); }
    function verify(done: var): void { listModels(done); }
    function listModels(done: var): void { done({ ok: true, models: [], problem: null }); }
    function send(messages: var, model: string, options: var): void {
        finished({ ok: false, cut: false, problem: { kind: "unknown", detail: "" } });
    }
    function cancel(): void {}
}
