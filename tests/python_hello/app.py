#!/usr/bin/env python3

from http.server import BaseHTTPRequestHandler, HTTPServer
import json

class RequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/hello" :
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({
                'msg': 'Hello world'
            }).encode())
            return

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 5000), RequestHandler)
    server.serve_forever()
