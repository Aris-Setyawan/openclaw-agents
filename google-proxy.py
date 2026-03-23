#!/usr/bin/env python3
"""
Google Gemini OpenAI-Compatible Proxy

Forwards OpenAI-format requests to Google Gemini API.
Strips unsupported parameters automatically.
Returns clean JSON errors instead of binary gzip responses.

Usage:
    python3 proxy.py

Environment variables:
    PROXY_PORT      Port to listen on (default: 9998)
    PROXY_HOST      Host to bind (default: 127.0.0.1)
    GOOGLE_BASE     Google API base URL (default: https://generativelanguage.googleapis.com/v1beta/openai)
"""

import http.server
import urllib.request
import json
import os
import gzip

PORT = int(os.environ.get("PROXY_PORT", 9998))
HOST = os.environ.get("PROXY_HOST", "127.0.0.1")
GOOGLE_BASE = os.environ.get(
    "GOOGLE_BASE",
    "https://generativelanguage.googleapis.com/v1beta/openai"
)

# Parameters that OpenAI clients send but Google doesn't support
STRIP_PARAMS = {"store", "user", "thinking", "thinking_effort"}


class ProxyHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print(f"[proxy] {fmt % args}", flush=True)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length)

        try:
            payload = json.loads(body)
        except Exception:
            payload = None

        if payload:
            model = payload.get("model", "?")
            stripped = [p for p in STRIP_PARAMS if p in payload]
            has_thinking = "thinking" in payload or any(
                isinstance(m, dict) and "thinking" in str(m)
                for m in payload.get("messages", [])
            )
            print(f"[proxy] model={model} stripped={stripped} thinking={has_thinking}", flush=True)

            # Strip unsupported params
            for p in STRIP_PARAMS:
                payload.pop(p, None)

            # Rename max_completion_tokens → max_tokens if needed
            if "max_completion_tokens" in payload and "max_tokens" not in payload:
                payload["max_tokens"] = payload.pop("max_completion_tokens")
            elif "max_completion_tokens" in payload:
                payload.pop("max_completion_tokens")

            body = json.dumps(payload).encode()

        # Strip /v1 prefix to avoid double path with GOOGLE_BASE
        path = self.path
        if path.startswith("/v1/"):
            path = path[3:]
        url = GOOGLE_BASE + path

        req = urllib.request.Request(url, data=body, method="POST")
        for k, v in self.headers.items():
            if k.lower() not in ("host", "content-length"):
                req.add_header(k, v)
        req.add_header("Content-Length", str(len(body)))

        try:
            resp = urllib.request.urlopen(req, timeout=120)
            data = resp.read()
            self.send_response(resp.status)
            for k, v in resp.headers.items():
                if k.lower() not in ("transfer-encoding", "connection"):
                    self.send_header(k, v)
            self.end_headers()
            self.wfile.write(data)

        except urllib.error.HTTPError as e:
            data = e.read()
            # Decode error body (may be gzip compressed)
            try:
                err = gzip.decompress(data).decode()
            except Exception:
                err = data.decode(errors="replace")
            print(f"[proxy] ERROR {e.code}: {err[:200]}", flush=True)
            # Return JSON error instead of raw binary so clients can parse it
            err_json = json.dumps({"error": {"code": e.code, "message": err[:500]}}).encode()
            self.send_response(e.code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(err_json)))
            self.end_headers()
            self.wfile.write(err_json)

    def do_GET(self):
        url = GOOGLE_BASE + self.path
        req = urllib.request.Request(url)
        for k, v in self.headers.items():
            if k.lower() != "host":
                req.add_header(k, v)
        try:
            resp = urllib.request.urlopen(req, timeout=30)
            data = resp.read()
            self.send_response(resp.status)
            for k, v in resp.headers.items():
                if k.lower() not in ("transfer-encoding", "connection"):
                    self.send_header(k, v)
            self.end_headers()
            self.wfile.write(data)
        except Exception as e:
            print(f"[proxy] GET error: {e}", flush=True)
            self.send_response(502)
            self.end_headers()


if __name__ == "__main__":
    server = http.server.HTTPServer((HOST, PORT), ProxyHandler)
    print(f"[proxy] Google Gemini proxy running on {HOST}:{PORT}", flush=True)
    print(f"[proxy] Forwarding to: {GOOGLE_BASE}", flush=True)
    server.serve_forever()
