#!/usr/bin/env python3
"""
Google Gemini proxy for OpenClaw.
Strips unsupported params (store, max_completion_tokens→max_tokens)
then forwards to Google OpenAI-compat endpoint.
"""
import http.server, urllib.request, json, sys, os, gzip

PORT = int(os.environ.get("PROXY_PORT", 9998))
GOOGLE_BASE = "https://generativelanguage.googleapis.com/v1beta/openai"
# Params OpenClaw sends that Google doesn't support
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

        # Debug: log model and stripped params
        if payload:
            model = payload.get("model", "?")
            stripped = [p for p in STRIP_PARAMS if p in payload]
            has_thinking = "thinking" in payload or any(
                isinstance(m, dict) and "thinking" in str(m)
                for m in payload.get("messages", [])
            )
            print(f"[proxy] model={model} stripped={stripped} thinking={has_thinking}", flush=True)

        if payload:
            # Strip unsupported params
            for p in STRIP_PARAMS:
                payload.pop(p, None)
            # Rename max_completion_tokens → max_tokens if needed
            if "max_completion_tokens" in payload and "max_tokens" not in payload:
                payload["max_tokens"] = payload.pop("max_completion_tokens")
            elif "max_completion_tokens" in payload:
                payload.pop("max_completion_tokens")
            body = json.dumps(payload).encode()

        # Strip /v1 prefix agar tidak double dengan GOOGLE_BASE
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
            # Try to decode error body
            try:
                err = gzip.decompress(data).decode()
            except Exception:
                err = data.decode(errors="replace")
            print(f"[proxy] ERROR {e.code}: {err[:200]}", flush=True)
            # Return JSON error (bukan binary gzip) supaya client bisa parse
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
            self.send_response(502)
            self.end_headers()

if __name__ == "__main__":
    server = http.server.HTTPServer(("127.0.0.1", PORT), ProxyHandler)
    print(f"[proxy] Google Gemini proxy running on 127.0.0.1:{PORT}", flush=True)
    server.serve_forever()
