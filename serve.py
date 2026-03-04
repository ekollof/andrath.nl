#!/usr/bin/env python3

import http.server
import socketserver
import os
import functools

PUBLIC_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "public")


class CustomHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        if self.path.endswith(".woff2"):
            self.send_header("Content-Type", "font/woff2")
        super().end_headers()


PORT = 8000
print(f"Serving from 'public/' directory at http://localhost:{PORT}")
handler = functools.partial(CustomHandler, directory=PUBLIC_DIR)
socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("", PORT), handler) as httpd:
    print("Press Ctrl+C to stop the server")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped.")
