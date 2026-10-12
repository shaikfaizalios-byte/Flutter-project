"""Serve a Flutter web build for local testing with cross-origin isolation headers.

Drift's web database uses its most reliable storage (OPFS) only when the page is
cross-origin isolated, which requires the COOP/COEP headers below. Production web
hosting needs the same headers.

Usage: python scripts/serve_web.py [build_dir] [port]
"""

import sys
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class IsolatedHandler(SimpleHTTPRequestHandler):
    def end_headers(self) -> None:
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        # "credentialless" still allows Flutter's CDN assets (CanvasKit, fallback fonts).
        self.send_header("Cross-Origin-Embedder-Policy", "credentialless")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    build_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "apps/mobile/build/web"
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 8080
    handler = partial(IsolatedHandler, directory=str(build_dir))
    with ThreadingHTTPServer(("127.0.0.1", port), handler) as server:
        print(f"Serving {build_dir} on http://127.0.0.1:{port} (cross-origin isolated)")
        server.serve_forever()


if __name__ == "__main__":
    main()
