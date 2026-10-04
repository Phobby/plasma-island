#!/usr/bin/env python3
# A local stand-in for the services the AI tab talks to, for tests/tst_ai*.qml.
#
#   ai-server.py --log FILE [--key KEY] [--lifetime SECONDS]
#
# Listens on 127.0.0.1 at a free port, prints the port and goes on in the
# background; ends by itself after --lifetime seconds (60), or with a GET of
# /__quit. Every request is written to FILE as one line of JSON
# ({ method, path, headers, body }), so a test can see what was sent and what
# was not. With --key the key is asked for (as a real service does); without
# it none is needed (as a local model server).
#
#   /v1/models, /v1/chat/completions     OpenAI compatible (Ollama, LM Studio,
#                                        OpenAI, OpenRouter, Groq…), streamed
#   /v1/key                              OpenRouter's "is this key valid"
#   /anthropic/v1/models, …/v1/messages  the Anthropic API, streamed
#   /pixel.png                           a picture nobody should ever fetch
#
# What a chat request gets is chosen by its model:
#   tiny-1, claude-test-1  "REPLY[n]: <the last message>" in pieces (n = the
#                          number of messages sent, the system one not counted)
#   markdown               an answer with a heading, a list, a link and code
#   slow                   forty pieces, 100 ms apart (to press Stop)
#   hang                   the headers, then nothing
#   silent                 nothing at all
#   drop                   two pieces, then the connection is cut
#   midfail                one piece, then an error inside the stream
#   limit, missing, boom   429, 404, 500
#   long                   cut off at the length limit
#   newparam               refuses `max_tokens`, wants `max_completion_tokens`
#   claude-refuse          the model declines (stop_reason "refusal")
#   claude-overloaded      an "overloaded" error inside the stream
import argparse
import http.server
import json
import os
import socket
import sys
import threading
import time

parser = argparse.ArgumentParser()
parser.add_argument("--log", required=True)
parser.add_argument("--key", default="")
parser.add_argument("--lifetime", type=float, default=60)
args = parser.parse_args()

MODELS = ["tiny-1", "tiny-2", "markdown", "slow", "hang", "silent", "drop", "midfail", "limit", "missing", "boom", "long", "newparam"]
CLAUDE_MODELS = [("claude-test-1", "Claude Test 1"), ("claude-test-2", "Claude Test 2"), ("claude-refuse", "Claude Refuse"),
                 ("claude-overloaded", "Claude Overloaded"), ("claude-max", "Claude Max"), ("slow", "Slow")]
MARKDOWN = ("## Answer\n\nTwo things, with **bold** and *italic*:\n\n- one\n- two\n\n"
            "See [the docs](https://example.org/docs) and ![a picture](http://127.0.0.1:%d/pixel.png).\n\n"
            "```python\nprint(\"hi <there>\")\n```\n\nDone.")
log_lock = threading.Lock()


def pieces(text, size=7):
    return [text[i:i + size] for i in range(0, len(text), size)] or [""]


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    # ---- plumbing ---------------------------------------------------------------
    def record(self, body):
        entry = {"method": self.command, "path": self.path,
                 "headers": {k.lower(): v for k, v in self.headers.items()}, "body": body}
        with log_lock, open(args.log, "a", encoding="utf-8") as log:
            log.write(json.dumps(entry, ensure_ascii=False) + "\n")

    def answer(self, status, data, content_type="application/json"):
        raw = data if isinstance(data, bytes) else json.dumps(data).encode()
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def start_stream(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream; charset=utf-8")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Transfer-Encoding", "chunked")
        self.end_headers()

    def chunk(self, text):
        raw = text.encode()
        self.wfile.write(b"%x\r\n%s\r\n" % (len(raw), raw))
        self.wfile.flush()

    def end_stream(self):
        self.wfile.write(b"0\r\n\r\n")
        self.wfile.flush()

    def cut(self):
        # the connection goes away in the middle of the answer
        self.close_connection = True
        try:
            self.connection.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass

    def keyed(self, anthropic):
        if not args.key:
            return True
        given = self.headers.get("x-api-key", "") if anthropic else self.headers.get("Authorization", "")[len("Bearer "):]
        if given == args.key:
            return True
        if anthropic:
            self.answer(401, {"type": "error", "error": {"type": "authentication_error", "message": "invalid x-api-key"}})
        else:
            self.answer(401, {"error": {"message": "Incorrect API key provided.", "type": "invalid_request_error", "code": "invalid_api_key"}})
        return False

    def log_message(self, *a):
        pass

    # ---- GET ----------------------------------------------------------------------
    def do_GET(self):
        self.record(None)
        path = self.path.split("?")[0]
        if path == "/__quit":
            self.answer(204, b"")
            threading.Thread(target=self.server.shutdown, daemon=True).start()
        elif path == "/pixel.png":
            self.answer(200, b"\x89PNG\r\n\x1a\n", "image/png")
        elif path == "/v1/models":
            if self.keyed(False):
                self.answer(200, {"object": "list", "data": [{"id": m, "object": "model"} for m in MODELS]})
        elif path == "/v1/key":
            if self.keyed(False):
                self.answer(200, {"data": {"label": "test"}})
        elif path == "/anthropic/v1/models":
            if not self.headers.get("anthropic-version"):
                self.answer(400, {"type": "error", "error": {"type": "invalid_request_error", "message": "anthropic-version: header is required"}})
            elif self.keyed(True):
                data = [{"type": "model", "id": i, "display_name": n, "created_at": "2026-01-01T00:00:00Z"} for i, n in CLAUDE_MODELS]
                self.answer(200, {"data": data, "has_more": False, "first_id": data[0]["id"], "last_id": data[-1]["id"]})
        else:
            self.answer(404, {"error": {"message": "not found"}})

    # ---- POST ---------------------------------------------------------------------
    def do_POST(self):
        raw = self.rfile.read(int(self.headers.get("Content-Length", "0") or 0)).decode("utf-8", "replace")
        try:
            body = json.loads(raw)
        except ValueError:
            body = raw
        self.record(body)
        path = self.path.split("?")[0]
        if not isinstance(body, dict):
            self.answer(400, {"error": {"message": "the body is not JSON"}})
        elif path == "/v1/chat/completions":
            if self.keyed(False):
                self.chat(body)
        elif path == "/anthropic/v1/messages":
            if not self.headers.get("anthropic-version"):
                self.answer(400, {"type": "error", "error": {"type": "invalid_request_error", "message": "anthropic-version: header is required"}})
            elif self.keyed(True):
                self.messages(body)
        else:
            self.answer(404, {"error": {"message": "not found"}})

    def reply_text(self, body, count_system):
        messages = body.get("messages") or []
        n = len([m for m in messages if count_system or m.get("role") != "system"])
        last = messages[-1].get("content", "") if messages else ""
        return "REPLY[%d]: %s" % (n, last)

    def chat(self, body):
        model = body.get("model", "")
        if model == "silent":
            time.sleep(args.lifetime)
            return
        if model == "limit":
            return self.answer(429, {"error": {"message": "Rate limit reached for requests.", "type": "rate_limit_error", "code": "rate_limit_exceeded"}})
        if model == "missing" or model not in MODELS:
            return self.answer(404, {"error": {"message": "The model `%s` does not exist." % model, "type": "invalid_request_error", "code": "model_not_found"}})
        if model == "boom":
            return self.answer(500, {"error": {"message": "The server had an error."}})
        if model == "newparam" and "max_tokens" in body:
            return self.answer(400, {"error": {"message": "Unsupported parameter: 'max_tokens' is not supported with this model. Use 'max_completion_tokens' instead.",
                                               "type": "invalid_request_error", "param": "max_tokens", "code": "unsupported_parameter"}})
        text = MARKDOWN % self.server.server_address[1] if model == "markdown" else self.reply_text(body, False)
        parts = pieces("word " * 40, 5) if model == "slow" else pieces(text)
        self.start_stream()
        if model == "hang":
            time.sleep(args.lifetime)
            return

        def event(delta, finish=None):
            return "data: " + json.dumps({"id": "chatcmpl-test", "object": "chat.completion.chunk", "model": model,
                                          "choices": [{"index": 0, "delta": delta, "finish_reason": finish}]}) + "\n\n"
        try:
            self.chunk(": keep-alive comment\n\n")
            self.chunk(event({"role": "assistant", "content": ""}))
            for i, part in enumerate(parts):
                if model == "drop" and i == 2:
                    return self.cut()
                if model == "midfail" and i == 1:
                    self.chunk("data: " + json.dumps({"error": {"message": "The upstream provider failed.", "code": 502}}) + "\n\n")
                    return self.end_stream()
                self.chunk(event({"content": part}))
                time.sleep(0.1 if model == "slow" else 0.01)
            self.chunk(event({}, "length" if model == "long" else "stop"))
            self.chunk("data: [DONE]\n\n")
            self.end_stream()
        except (BrokenPipeError, ConnectionResetError):
            pass                        # the client stopped listening (Stop)

    def messages(self, body):
        model = body.get("model", "")
        if model == "claude-limit":
            return self.answer(429, {"type": "error", "error": {"type": "rate_limit_error", "message": "This request would exceed your rate limit."}})
        if model not in [m for m, _ in CLAUDE_MODELS]:
            return self.answer(404, {"type": "error", "error": {"type": "not_found_error", "message": "model: " + model}})
        if not isinstance(body.get("max_tokens"), int):
            return self.answer(400, {"type": "error", "error": {"type": "invalid_request_error", "message": "max_tokens: Field required"}})
        roles = [m.get("role") for m in body.get("messages") or []]
        if not roles or roles[0] != "user" or any(a == b for a, b in zip(roles, roles[1:])):
            return self.answer(400, {"type": "error", "error": {"type": "invalid_request_error", "message": "messages: roles must alternate between \"user\" and \"assistant\""}})
        parts = pieces("word " * 40, 5) if model == "slow" else pieces(self.reply_text(body, True))
        stop = "refusal" if model == "claude-refuse" else "max_tokens" if model == "claude-max" else "end_turn"

        def event(name, data):
            data["type"] = name
            return "event: %s\ndata: %s\n\n" % (name, json.dumps(data))
        self.start_stream()
        try:
            self.chunk(event("message_start", {"message": {"id": "msg_test", "type": "message", "role": "assistant", "model": model, "content": [],
                                                           "stop_reason": None, "usage": {"input_tokens": 9, "output_tokens": 1}}}))
            self.chunk(event("ping", {}))
            # a thinking block first, as the current models send one: nothing of it is shown
            self.chunk(event("content_block_start", {"index": 0, "content_block": {"type": "thinking", "thinking": ""}}))
            self.chunk(event("content_block_delta", {"index": 0, "delta": {"type": "thinking_delta", "thinking": "SECRET-THOUGHT"}}))
            self.chunk(event("content_block_delta", {"index": 0, "delta": {"type": "signature_delta", "signature": "c2ln"}}))
            self.chunk(event("content_block_stop", {"index": 0}))
            if model != "claude-refuse":
                self.chunk(event("content_block_start", {"index": 1, "content_block": {"type": "text", "text": ""}}))
                for i, part in enumerate(parts):
                    if model == "claude-overloaded" and i == 1:
                        self.chunk(event("error", {"error": {"type": "overloaded_error", "message": "Overloaded"}}))
                        return self.end_stream()
                    self.chunk(event("content_block_delta", {"index": 1, "delta": {"type": "text_delta", "text": part}}))
                    time.sleep(0.1 if model == "slow" else 0.01)
                self.chunk(event("content_block_stop", {"index": 1}))
            self.chunk(event("message_delta", {"delta": {"stop_reason": stop, "stop_sequence": None}, "usage": {"output_tokens": 12}}))
            self.chunk(event("message_stop", {}))
            self.end_stream()
        except (BrokenPipeError, ConnectionResetError):
            pass


class Server(http.server.ThreadingHTTPServer):
    daemon_threads = True


server = Server(("127.0.0.1", 0), Handler)
open(args.log, "a").close()
print(server.server_address[1], flush=True)
if os.fork() > 0:
    sys.exit(0)                     # the caller has the port; the child serves
os.setsid()
devnull = os.open(os.devnull, os.O_RDWR)
for fd in (0, 1, 2):
    os.dup2(devnull, fd)
threading.Timer(args.lifetime, server.shutdown).start()
server.serve_forever()
os._exit(0)
