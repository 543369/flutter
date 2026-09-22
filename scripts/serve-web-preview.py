#!/usr/bin/env python3
"""Serve the Flutter web build and proxy /api to the local development API."""
import http.client
import gzip
import io
from functools import lru_cache
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

WEB = Path(__file__).resolve().parents[1] / 'mobile/build/web'
HOP = {'connection', 'keep-alive', 'proxy-authenticate', 'proxy-authorization',
       'te', 'trailer', 'transfer-encoding', 'upgrade', 'host', 'content-length'}

@lru_cache(maxsize=64)
def compressed_file(path, modified):
    return gzip.compress(Path(path).read_bytes(), compresslevel=6)

class Handler(SimpleHTTPRequestHandler):
    def send_head(self):
        path = Path(self.translate_path(self.path))
        if path.is_dir():
            path = path / 'index.html'
        if (path.is_file() and path.suffix in ('.js', '.wasm', '.json', '.html', '.css')
                and 'gzip' in self.headers.get('Accept-Encoding', '')):
            data = compressed_file(str(path), path.stat().st_mtime_ns)
            self.send_response(200)
            self.send_header('Content-Type', self.guess_type(str(path)))
            self.send_header('Content-Encoding', 'gzip')
            self.send_header('Vary', 'Accept-Encoding')
            self.send_header('Cache-Control', 'no-cache')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            return io.BytesIO(data)
        return super().send_head()

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(WEB), **kwargs)

    def dispatch(self):
        if not self.path.startswith('/api/'):
            if self.command in ('GET', 'HEAD'):
                return super().do_GET() if self.command == 'GET' else super().do_HEAD()
            return self.send_error(405)
        try:
            size = int(self.headers.get('Content-Length', '0'))
            if size < 0 or size > 25 * 1024 * 1024:
                return self.send_error(413)
            body = self.rfile.read(size) if size else None
            conn = http.client.HTTPConnection('127.0.0.1', 18080, timeout=30)
            try:
                headers = {k: v for k, v in self.headers.items() if k.lower() not in HOP}
                conn.request(self.command, self.path, body, headers)
                response = conn.getresponse()
                data = response.read()
                self.send_response(response.status)
                for k, v in response.getheaders():
                    if k.lower() not in HOP:
                        self.send_header(k, v)
                self.send_header('Content-Length', str(len(data)))
                self.end_headers()
                if self.command != 'HEAD':
                    self.wfile.write(data)
            finally:
                conn.close()
        except (OSError, ValueError, http.client.HTTPException):
            self.send_error(502)

    def list_directory(self, path):
        self.send_error(404)

    do_GET = do_HEAD = do_POST = do_PATCH = do_PUT = do_DELETE = do_OPTIONS = dispatch

if __name__ == '__main__':
    ThreadingHTTPServer(('127.0.0.1', 18765), Handler).serve_forever()
