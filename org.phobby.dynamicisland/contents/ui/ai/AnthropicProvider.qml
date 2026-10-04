/*
    SPDX-License-Identifier: GPL-2.0-or-later

    The Anthropic API with a key of the user's own, as its documentation
    gives it (platform.claude.com/docs, checked October 2026):

      GET  <server>/v1/models?limit=100     the models, newest first
      POST <server>/v1/messages             { model, max_tokens, system,
                                              messages, stream: true }
      headers  x-api-key, anthropic-version: 2023-06-01, content-type

    The answer is a stream of events; only the text of text blocks is taken
    (`content_block_delta` with a `text_delta`). What the model thinks is not
    shown, and no tool is ever sent along. `stop_reason` "max_tokens" = cut
    off at the length limit, "refusal" = the model declined; an `error` event
    may arrive in the middle of an answer. Nothing else is sent: no beta
    header, no thinking or effort setting, so every model of the list takes
    the same request.
*/
import QtQuick
import "AiStream.js" as Stream

HttpProvider {
    id: provider

    readonly property string apiVersion: "2023-06-01"

    function headers(): var { return { "x-api-key": secret, "anthropic-version": apiVersion }; }
    function interpret(data: string): var {
        const o = Stream.anthropicEvent(data), out = {};
        if (o.problem !== undefined) return { problem: o.problem };
        if (o.stop === "refusal") return { problem: Stream.problem("refused", "") };
        if (o.text !== undefined) out.text = o.text;
        if (o.stop === "max_tokens") out.cut = true;
        if (o.done === true) out.end = true;
        return out;
    }
    function listModels(done: var): void {
        get(server + "/v1/models?limit=100", (status, text) => {
            if (status !== 200) done({ ok: false, models: [], problem: clean(Stream.httpProblem(status, text)) });
            else done({ ok: true, models: Stream.anthropicModels(text), problem: null });
        });
    }
    function send(messages: var, model: string, options: var): void {
        post(server + "/v1/messages", Stream.anthropicBody(model, String(options.system || ""), messages, Math.max(1, Number(options.maxTokens) || 1024)), null);
    }
}
