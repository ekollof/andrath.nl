#!/usr/bin/env python3

import http.server
import socketserver
import os

# Set the working directory to public/
os.chdir('public')

class CustomHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        if self.path.endswith('.woff2'):
            self.send_header('Content-Type', 'font/woff2')
        super().end_headers()

PORT = 8000
print(f"Serving from 'public/' directory at http://localhost:{PORT}")
with socketserver.TCPServer(("", PORT), CustomHandler) as httpd:
    print(f"Press Ctrl+C to stop the server")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped.")
