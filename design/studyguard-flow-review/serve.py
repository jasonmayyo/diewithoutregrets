"""Serve this local review with byte ranges for Safari's video player."""

from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import os
import re


class ReviewHandler(SimpleHTTPRequestHandler):
    def send_head(self):
        self.remaining = None
        path = self.translate_path(self.path)
        requested = self.headers.get("Range")
        if not requested or not os.path.isfile(path):
            return super().send_head()
        match = re.fullmatch(r"bytes=(\d*)-(\d*)", requested.strip())
        if not match or not any(match.groups()):
            return super().send_head()
        file = open(path, "rb")
        size = os.fstat(file.fileno()).st_size
        first, last = match.groups()
        start = int(first) if first else max(0, size - int(last))
        end = min(size - 1, int(last)) if first and last else size - 1
        if start > end or start >= size:
            file.close()
            self.send_response(416)
            self.send_header("Content-Range", f"bytes */{size}")
            self.send_header("Content-Length", "0")
            self.end_headers()
            return None
        self.remaining = end - start + 1
        self.send_response(206)
        self.send_header("Content-Type", self.guess_type(path))
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        self.send_header("Content-Length", str(self.remaining))
        self.end_headers()
        file.seek(start)
        return file

    def copyfile(self, source, outputfile):
        if self.remaining is None:
            return super().copyfile(source, outputfile)
        while self.remaining:
            chunk = source.read(min(64 * 1024, self.remaining))
            if not chunk:
                break
            outputfile.write(chunk)
            self.remaining -= len(chunk)


if __name__ == "__main__":
    handler = partial(ReviewHandler, directory=str(Path(__file__).resolve().parent))
    print("Review: http://127.0.0.1:4186/#inline-motion", flush=True)
    ThreadingHTTPServer(("127.0.0.1", 4186), handler).serve_forever()
