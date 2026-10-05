/*
    SPDX-License-Identifier: GPL-2.0-or-later

    A server that speaks the OpenAI chat protocol: GET <server>/models and
    POST <server>/chat/completions, answered as a stream. That is Ollama,
    LM Studio and llama.cpp on this computer (no key), and OpenAI,
    OpenRouter, Groq and others on the internet (a key, sent as
    "Authorization: Bearer …"). `server` is the address up to and including
    its version part ("http://localhost:11434/v1").

    Only what the model says is taken (`content`); what it thinks
    (`reasoning…`) is not shown, and no tool is ever offered to it.
    The longest answer goes as `max_tokens`, or under the name the kind
    gives (`limitField`); a service that only knows the newer name
    (`max_completion_tokens`) says so, and is asked again with it.
*/
import QtQuick
import "AiStream.js" as Stream

HttpProvider {
    id: provider

    function headers(): var { return secret.length > 0 ? { "Authorization": "Bearer " + secret } : {}; }
    function interpret(data: string): var {
        const o = Stream.openAiEvent(data), out = {};
        if (o.problem !== undefined) return { problem: o.problem };
        if (o.finish === "content_filter") return { problem: Stream.problem("refused", "") };
        if (o.text !== undefined) out.text = o.text;
        if (o.finish === "length") out.cut = true;
        if (o.done === true) out.end = true;
        return out;
    }

    // Is the server answering, and is its program on this computer (`command` of the kind)?
    // done({ found, running, installed, models }). Nothing is started.
    function detect(done: var): void {
        const local = core !== null ? core.local : null, command = String(options.command || "");
        const installed = local !== null && command.length > 0 && local.findExecutable(command).length > 0;
        get(server + "/models", (status, text) => {
            // (a list of models, not just any program that answers at this address)
            let listed = false;
            try { const o = JSON.parse(text); listed = o !== null && typeof o === "object" && (Array.isArray(o.data) || Array.isArray(o)); } catch (e) { listed = false; }
            const running = status === 200 && listed;
            done({ found: running || installed, running: running, installed: installed, models: running ? Stream.openAiModels(text) : [] });
        });
    }
    function listModels(done: var): void {
        get(server + "/models", (status, text) => {
            if (status !== 200) done({ ok: false, models: [], problem: clean(Stream.httpProblem(status, text)) });
            else done({ ok: true, models: Stream.openAiModels(text), problem: null });
        });
    }
    // Connecting. A service whose list of models anyone may read is asked about the key itself first (`keyCheck`).
    function verify(done: var): void {
        const check = String(options.keyCheck || "");
        if (check.length === 0 || secret.length === 0) { listModels(done); return; }
        get(server + check, (status, text) => {
            if (status === 401 || status === 403) done({ ok: false, models: [], problem: clean(Stream.httpProblem(status, text)) });
            else listModels(done);
        });
    }
    function send(messages: var, model: string, options: var): void {
        const field = String(provider.options.limitField || "max_tokens");
        const body = name => Stream.openAiBody(model, String(options.system || ""), messages, Number(options.maxTokens) || 0, name);
        post(server + "/chat/completions", body(field),
             (status, text) => field === "max_tokens" && Stream.wantsNewLimitField(status, text) ? body("max_completion_tokens") : null);
    }
}
