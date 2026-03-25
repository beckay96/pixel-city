#!/usr/bin/env python3
"""Dev server that injects Supabase credentials into index.html from env vars.

Usage:
    SUPABASE_PROJECT_URL=https://xxx.supabase.co SUPABASE_PUBLISHABLE_KEY=sb_publishable_... python3 dev-server.py [PORT]

Serves the repo root as static files, but rewrites index.html on the fly to
inject window.__SUPABASE_URL__ and window.__SUPABASE_ANON_KEY__ right before
the closing </head> tag.
"""

import http.server
import os
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
SUPABASE_URL = os.environ.get("SUPABASE_PROJECT_URL", "")
SUPABASE_KEY = os.environ.get("SUPABASE_ANON_KEY", "") or os.environ.get("SUPABASE_PUBLISHABLE_KEY", "")

INJECT_SNIPPET = f"""<script>
  window.__SUPABASE_URL__ = '{SUPABASE_URL}';
  window.__SUPABASE_ANON_KEY__ = '{SUPABASE_KEY}';
</script>
"""


class InjectHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path in ("/", "/index.html"):
            try:
                with open("index.html", "rb") as f:
                    content = f.read().decode("utf-8")
                content = content.replace("</head>", INJECT_SNIPPET + "</head>", 1)
                encoded = content.encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(encoded)))
                self.end_headers()
                self.wfile.write(encoded)
            except FileNotFoundError:
                self.send_error(404, "index.html not found")
        else:
            super().do_GET()


if __name__ == "__main__":
    with http.server.HTTPServer(("", PORT), InjectHandler) as httpd:
        status = "with Supabase credentials" if SUPABASE_URL and SUPABASE_KEY else "WITHOUT Supabase (env vars not set)"
        print(f"Dev server running on http://localhost:{PORT} {status}")
        httpd.serve_forever()
