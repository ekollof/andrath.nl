#!/usr/bin/env python3

# Save as serve.py in ~/Code/roffblog/public/
import http.server
import socketserver

class CustomHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        if self.path.endswith('.woff2'):
            self.send_header('Content-Type', 'font/woff2')
        super().end_headers()

PORT = 8000
with socketserver.TCPServer(("", PORT), CustomHandler) as httpd:
    print(f"Serving at port {PORT}")
    httpd.serve_forever()
