#!/usr/bin/env python3
# A local stand-in for calendar links, for tests/tst_calendar_download.qml.
#
#   ics-server.py [--lifetime SECONDS]
#
# On 127.0.0.1 at a free port; prints the port and goes on in the background.
#   /ok.ics        a small calendar, with its length
#   /large.ics     a calendar of 1.5 MB, with its length
#   /endless.ics   a calendar that never ends and gives no length (64 kB every 20 ms)
#   /silent.ics    takes the request and says nothing
#   /stalls.ics    the beginning of a calendar, then nothing
# It ends by itself after --lifetime seconds (60), or with a GET of /__quit.
import argparse
import http.server
import os
import sys
import threading
import time

parser = argparse.ArgumentParser()
parser.add_argument("--lifetime", type=float, default=60)
args = parser.parse_args()

HEAD = b"BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//island tests//EN\r\nX-WR-CALNAME:Test\r\n"
EVENT = b"BEGIN:VEVENT\r\nUID:%d@test\r\nDTSTAMP:20261001T000000Z\r\nDTSTART:20261004T090000Z\r\nDTEND:20261004T100000Z\r\nSUMMARY:Event %d\r\nEND:VEVENT\r\n"
TAIL = b"END:VCALENDAR\r\n"


def calendar(size):
    """A calendar of three events, or of as many as make `size` bytes."""
    events, length = [], 0
    while len(events) < 3 or length < size:
        events.append(EVENT % (len(events) + 1, len(events) + 1))
        length += len(events[-1])
    return HEAD + b"".join(events) + TAIL


class Handler(http.server.BaseHTTPRequestHandler):
    def head(self, length=None):
        self.send_response(200)
        self.send_header("Content-Type", "text/calendar; charset=utf-8")
        if length is not None:
            self.send_header("Content-Length", str(length))
        else:
            self.send_header("Connection", "close")
        self.end_headers()

    def do_GET(self):
        try:
            if self.path == "/__quit":
                self.send_response(204)
                self.end_headers()
                threading.Thread(target=self.server.shutdown, daemon=True).start()
            elif self.path in ("/ok.ics", "/large.ics"):
                body = calendar(300 if self.path == "/ok.ics" else 1500000)
                self.head(len(body))
                self.wfile.write(body)
            elif self.path == "/endless.ics":
                self.head()
                self.wfile.write(HEAD)
                block = (EVENT % (1, 1)) * 500             # about 64 kB
                until = time.monotonic() + args.lifetime
                while time.monotonic() < until:
                    self.wfile.write(block)
                    self.wfile.flush()
                    time.sleep(0.02)
            elif self.path == "/silent.ics":
                time.sleep(args.lifetime)
            elif self.path == "/stalls.ics":
                self.head(100000)
                self.wfile.write(HEAD + EVENT % (1, 1))
                self.wfile.flush()
                time.sleep(args.lifetime)
            else:
                self.send_error(404)
        except (BrokenPipeError, ConnectionResetError):
            pass                    # the island hung up: that is what is tested

    def log_message(self, *a):
        pass


class Server(http.server.ThreadingHTTPServer):
    daemon_threads = True


server = Server(("127.0.0.1", 0), Handler)
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
