#!/usr/bin/env python3
# A local stand-in for the published theme catalog, for tests/tst_themes.qml.
#
#   catalog-server.py --dir DIR --log FILE [--lifetime SECONDS]
#
# Serves DIR on 127.0.0.1 at a free port, prints the port and goes on in the
# background; every request is written to FILE (one "GET /path" per line), so
# a test can see what was asked and what was not. It ends by itself after
# --lifetime seconds (60), or with a GET of /__quit.
import argparse
import http.server
import os
import sys
import threading

parser = argparse.ArgumentParser()
parser.add_argument("--dir", required=True)
parser.add_argument("--log", required=True)
parser.add_argument("--lifetime", type=float, default=60)
args = parser.parse_args()


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=args.dir, **k)

    def do_GET(self):
        with open(args.log, "a", encoding="utf-8") as log:
            log.write("GET " + self.path + "\n")
        if self.path == "/__quit":
            self.send_response(204)
            self.end_headers()
            threading.Thread(target=self.server.shutdown, daemon=True).start()
            return
        super().do_GET()

    def log_message(self, *a):
        pass


server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
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
