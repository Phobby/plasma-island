#!/usr/bin/env node
// A feedback relay on this computer for tests/tst_feedback.qml: the real handler of
// tools/feedback-relay/relay.mjs behind a local port, with a stand-in Telegram that only writes
// down what it was asked. tools/run-tests starts it beside the QML tests.
//
//   node tests/feedback-server.mjs PORT
//   POST /          the relay
//   GET  /calls     what "Telegram" was asked: [{ method, chat, text, file }]
//   POST /reset     forget the calls and who sent (the one-a-minute limit)
import http from "node:http";
import { handle } from "../tools/feedback-relay/relay.mjs";

const port = Number(process.argv[2] || 47391);
let calls = [];
let seen = new Set();
const env = { BOT_TOKEN: "000:test-token", CHAT_ID: "42", TELEGRAM_API: "http://telegram.invalid" };

async function telegram(url, options) {
    const method = url.split("/").pop();
    if (method === "sendMessage") {
        const body = JSON.parse(options.body);
        calls.push({ method, chat: body.chat_id, text: body.text, file: "" });
    } else {
        const form = options.body;
        calls.push({ method, chat: form.get("chat_id"), text: form.get("caption"), file: await form.get("document").text() });
    }
    return new Response(JSON.stringify({ ok: true, result: { message_id: calls.length } }), { status: 200 });
}

http.createServer(async (req, res) => {
    const chunks = [];
    for await (const c of req) chunks.push(c);
    const body = Buffer.concat(chunks);
    if (req.url === "/calls") { res.writeHead(200, { "Content-Type": "application/json" }); res.end(JSON.stringify(calls)); return; }
    if (req.url === "/reset") { calls = []; seen = new Set(); res.writeHead(200); res.end("{}"); return; }
    const request = new Request("http://127.0.0.1:" + port + req.url, {
        method: req.method,
        headers: Object.assign({}, req.headers, { "cf-connecting-ip": req.socket.remoteAddress }),
        body: req.method === "GET" || req.method === "HEAD" ? undefined : body
    });
    const limited = async key => { const was = seen.has(key); seen.add(key); return was; };
    const answer = await handle(request, env, { fetch: telegram, limited });
    res.writeHead(answer.status, { "Content-Type": "application/json" });
    res.end(await answer.text());
}).listen(port, "127.0.0.1");
