"""Serve a Flutter web build for local testing with cross-origin isolation headers.

Drift's web database uses its most reliable storage (OPFS) only when the page is
cross-origin isolated, which requires the COOP/COEP headers below. Production web
hosting needs the same headers.

Usage: python scripts/serve_web.py [build_dir] [port] [--lan]

--lan listens on all interfaces so a phone on the same Wi-Fi can open it (add the page's
origin, e.g. http://192.168.1.25:8080, to PREPLOOP_CORS_ORIGINS for the API).
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
    args = [a for a in sys.argv[1:] if a != "--lan"]
    host = (
        "0.0.0.0" if "--lan" in sys.argv[1:] else "127.0.0.1"
    )  # --lan: opt-in phone testing
    build_dir = Path(args[0]) if args else root / "apps/mobile/build/web"
    port = int(args[1]) if len(args) > 1 else 8080
    handler = partial(IsolatedHandler, directory=str(build_dir))
    with ThreadingHTTPServer((host, port), handler) as server:
        print(f"Serving {build_dir} on http://{host}:{port} (cross-origin isolated)")
        server.serve_forever()


if __name__ == "__main__":
    main()
