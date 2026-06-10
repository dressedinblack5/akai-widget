#!/usr/bin/env python3
"""Mock opencode server for integration testing the AI Chat widget."""

import json
import uuid
from http.server import HTTPServer, BaseHTTPRequestHandler

HOST = "localhost"
PORT = 4096

SESSIONS = {}


class MockHandler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print(f"[mock] {args[0]} {args[1]} {args[2]}")

    def _json(self, data, status=200):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        if self.path == "/global/health":
            self._json({"healthy": True, "version": "0.0.0-test"})
        elif self.path == "/provider":
            self._json({
                "providers": [
                    {
                        "id": "test-provider",
                        "name": "Test Provider",
                        "enabled": True,
                        "models": {
                            "model-a": {"name": "Model Alpha"},
                            "model-b": {"name": "Model Beta"},
                        },
                    },
                    {
                        "id": "disabled-provider",
                        "name": "Disabled Provider",
                        "enabled": False,
                        "models": {"model-x": {"name": "Model X"}},
                    },
                ]
            })
        else:
            self._json({"error": "not found"}, 404)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(length)) if length else {}

        if self.path == "/api/session":
            sid = str(uuid.uuid4())[:8]
            SESSIONS[sid] = []
            self._json({"id": sid}, 201)
        elif self.path.startswith("/api/session/") and self.path.endswith("/prompt"):
            parts = self.path.split("/")
            sid = parts[3]
            user_msg = body.get("prompt", {}).get("parts", [{}])[0].get("text", "")
            reply = f"You said: {user_msg}"
            SESSIONS.setdefault(sid, []).append({"role": "user", "text": user_msg})
            SESSIONS[sid].append({"role": "assistant", "text": reply})
            self._json({"text": reply})
        else:
            self._json({"error": "not found"}, 404)

    def do_DELETE(self):
        parts = self.path.split("/")
        if len(parts) == 4 and parts[1] == "api" and parts[2] == "session":
            sid = parts[3]
            SESSIONS.pop(sid, None)
            self._json({"deleted": True})
        else:
            self._json({"error": "not found"}, 404)


def main():
    server = HTTPServer((HOST, PORT), MockHandler)
    print(f"[mock] opencode mock server listening on {HOST}:{PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[mock] shutting down")
        server.shutdown()


if __name__ == "__main__":
    main()
