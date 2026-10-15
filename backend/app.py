"""Teaching API with a health endpoint; no database dependency."""

import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if urlsplit(self.path).path == "/health":
            code, data = 200, {"status": "ok", "app": "example-api"}
        else:
            code, data = 404, {"error": "not_found"}
        body = json.dumps(data).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    server = ThreadingHTTPServer(("0.0.0.0", 18787), Handler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
