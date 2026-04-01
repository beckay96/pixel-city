#!/usr/bin/env python3
"""Dev server: serves static files; /supabase-config.js is built from env (multiplayer).

Usage:
    SUPABASE_PROJECT_URL=https://xxx.supabase.co SUPABASE_ANON_KEY=eyJ... python3 dev-server.py [PORT]

Also accepts SUPABASE_PUBLISHABLE_KEY instead of SUPABASE_ANON_KEY.
"""

import http.server
import json
import os
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
SUPABASE_URL = (os.environ.get("SUPABASE_PROJECT_URL") or os.environ.get("SUPABASE_URL") or "").strip()
SUPABASE_KEY = (
    os.environ.get("SUPABASE_ANON_KEY") or os.environ.get("SUPABASE_PUBLISHABLE_KEY") or ""
).strip()


def supabase_js_body():
    return (
        "/* dev-server: from env */\n"
        f"window.__SUPABASE_URL__ = {json.dumps(SUPABASE_URL)};\n"
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
        super().do_GET()


if __name__ == "__main__":
    with http.server.HTTPServer(("", PORT), DevHandler) as httpd:
        status = "Supabase from env (multiplayer OK)" if SUPABASE_URL and SUPABASE_KEY else "no Supabase env — use Play offline or set SUPABASE_PROJECT_URL + key"
        print(f"Dev server http://localhost:{PORT} — {status}")
        httpd.serve_forever()
