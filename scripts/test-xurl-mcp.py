#!/usr/bin/env python3

import argparse
import concurrent.futures
import json
import os
import pathlib
import re
import socket
import subprocess
import tempfile
import threading
import time
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class BridgeProcessTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = pathlib.Path(self.directory.name)
        self.marker = self.root / "browser-opened"
        self.store = self.root / ".xurl" / "auth.yml"
        self.store.parent.mkdir()
        self.generation = 0
        self.refreshes = 0
        self.fail_refresh = False
        self.lock = threading.Lock()
        case = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def do_POST(self):
                body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
                if self.path == "/token":
                    from urllib.parse import parse_qs
                    fields = parse_qs(body.decode())
                    with case.lock:
                        case.refreshes += 1
                        expected = f"refresh-{case.generation}"
                        valid = fields.get("refresh_token") == [expected] and not case.fail_refresh
                        if valid:
                            time.sleep(0.1)
                            case.generation += 1
                            result = {"access_token": f"access-{case.generation}", "token_type": "Bearer",
                                      "refresh_token": f"refresh-{case.generation}", "expires_in": 3600}
                        else:
                            result = {"error": "invalid_grant", "error_description": "invalid test token"}
                    self.send_response(200 if valid else 400)
                else:
                    case.assertEqual(self.headers.get("Authorization"), f"Bearer access-{case.generation}")
                    message = json.loads(body)
                    result = {"jsonrpc": "2.0", "id": message["id"],
                              "result": {"protocolVersion": "2025-03-26", "capabilities": {},
                                         "serverInfo": {"name": "test", "version": "1"}}}
                    self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps(result).encode())

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self.server.server_close)
        self.addCleanup(self.server.shutdown)
        self.url = f"http://127.0.0.1:{self.server.server_port}"
        commands = self.root / "bin"
        commands.mkdir()
        for name in ("open", "xdg-open"):
            p = commands / name
            p.write_text('#!/bin/sh\nprintf "opened\\n" >> "$BROWSER_MARKER"\n')
            p.chmod(0o700)
        self.env = {key: value for key, value in os.environ.items()
                    if key not in {"CLIENT_ID", "CLIENT_SECRET", "TOKEN_URL", "AUTH_URL", "INFO_URL", "REDIRECT_URI"}}
        self.env.update(HOME=str(self.root), CLIENT_ID="test-client", CLIENT_SECRET="test-secret",
                        TOKEN_URL=self.url + "/token", BROWSER_MARKER=str(self.marker),
                        PATH=str(commands) + os.pathsep + self.env.get("PATH", ""))

    def seed(self):
        self.store.write_text(f'''apps:
  default:
    client_id: test-client
    client_secret: test-secret
    oauth2_tokens:
      example:
        type: oauth2
        oauth2:
          access_token: access-0
          refresh_token: refresh-0
          expiration_time: {int(time.time()) - 3600}
default_app: default
''')

    def start(self):
        return subprocess.Popen([BINARY, "mcp", self.url + "/mcp"], env=self.env,
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

    def finish(self, process, success=True):
        message = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}}) + "\n"
        try:
            out, err = process.communicate(message, timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.communicate()
            self.fail("background startup did not finish")
        self.assertFalse(self.marker.exists(), "background startup opened a browser")
        if success:
            self.assertEqual(process.returncode, 0, err)
            self.assertEqual(json.loads(out)["id"], 1)
        else:
            self.assertNotEqual(process.returncode, 0)
            self.assertEqual(out, "")
            self.assertEqual(err.count("oauth2 token unavailable"), 1)
            self.assertIn("xurl-mcp auth oauth2", err)

    def test_concurrent_refresh_and_client_restart(self):
        self.seed()
        processes = [self.start() for _ in range(4)]
        with concurrent.futures.ThreadPoolExecutor() as executor:
            list(executor.map(self.finish, processes))
        self.assertEqual(self.refreshes, 1)
        self.assertIn("refresh_token: refresh-1", self.store.read_text())
        self.finish(self.start())
        self.assertEqual(self.refreshes, 1)
        updated = re.sub(r"expiration_time: \d+", f"expiration_time: {int(time.time()) - 3600}", self.store.read_text())
        self.store.write_text(updated)
        self.finish(self.start())
        self.assertEqual(self.refreshes, 2)
        self.assertIn("refresh_token: refresh-2", self.store.read_text())

    def test_missing_token_stays_noninteractive_across_restarts(self):
        for _ in range(3):
            self.finish(self.start(), success=False)
        self.assertEqual(self.refreshes, 0)

    def test_rejected_refresh_stays_noninteractive_and_preserves_token(self):
        self.seed()
        before = self.store.read_bytes()
        self.fail_refresh = True
        for _ in range(2):
            self.finish(self.start(), success=False)
        self.assertEqual(self.store.read_bytes(), before)
        self.assertEqual(self.refreshes, 2)

    def test_explicit_login_opens_the_browser(self):
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            port = listener.getsockname()[1]
        env = dict(self.env, REDIRECT_URI=f"http://localhost:{port}/callback")
        process = subprocess.Popen([BINARY, "auth", "oauth2"], env=env,
                                   stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        try:
            for _ in range(100):
                if self.marker.exists() or process.poll() is not None:
                    break
                time.sleep(0.02)
            self.assertTrue(self.marker.exists(), "explicit login did not open the browser")
        finally:
            process.terminate()
            try:
                process.communicate(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.communicate()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("binary")
    args = parser.parse_args()
    BINARY = str(pathlib.Path(args.binary).resolve())
    unittest.main(argv=[__file__])
