#!/usr/bin/env python3
"""Dev server: serves static files; /supabase-config.js is built from env (multiplayer).

Usage (preferred):
    VITE_SUPABASE_URL=https://xxx.supabase.co VITE_SUPABASE_PUBLISHABLE_KEY=sb_publishable_... python3 dev-server.py [PORT]

Also: SUPABASE_PROJECT_URL, SUPABASE_PUBLISHABLE_KEY, legacy SUPABASE_ANON_KEY.
"""

import http.server
import json
import os
import re
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
# A join code is 4-8 uppercase alphanumeric chars with no file extension
JOIN_CODE_RE = re.compile(r'^/([A-Z0-9]{4,8})$', re.IGNORECASE)
SUPABASE_URL = (
    os.environ.get("VITE_SUPABASE_URL")
    or os.environ.get("SUPABASE_PROJECT_URL")
    or os.environ.get("SUPABASE_URL")
    or ""
).strip()
SUPABASE_KEY = (
    os.environ.get("VITE_SUPABASE_PUBLISHABLE_KEY")
    or os.environ.get("SUPABASE_PUBLISHABLE_KEY")
    or os.environ.get("SUPABASE_ANON_KEY")
    or ""
).strip()


def supabase_js_body():
    return (
        "/* dev-server: from env */\n"
        f"window.__SUPABASE_URL__ = {json.dumps(SUPABASE_URL)};\n"
        f"window.__SUPABASE_PUBLISHABLE_KEY__ = {json.dumps(SUPABASE_KEY)};\n"
        f"window.__SUPABASE_ANON_KEY__ = {json.dumps(SUPABASE_KEY)};\n"
    )


class DevHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path == "/supabase-config.js":
            body = supabase_js_body().encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/javascript; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)
            return
        # Serve index.html for short join-code paths like /AB3D7K
        if JOIN_CODE_RE.match(path):
            with open(os.path.join(os.path.dirname(__file__), "index.html"), "rb") as f:
                body = f.read()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        super().do_GET()


if __name__ == "__main__":
    with http.server.HTTPServer(("", PORT), DevHandler) as httpd:
        status = "Supabase from env (multiplayer OK)" if SUPABASE_URL and SUPABASE_KEY else "no Supabase env — set VITE_SUPABASE_URL + VITE_SUPABASE_PUBLISHABLE_KEY (or SUPABASE_* fallbacks)"
        print(f"Dev server http://localhost:{PORT} — {status}")
        httpd.serve_forever()
