"""Signed links to figures, for a CDN to cache. Pure.

A figure is named by the hash of its bytes, so a link never goes stale and the same image is cached
once whoever asks. A link is signed and expires; the expiry falls on a fixed boundary, so everyone
asking within a window gets the same link and the cache serves them all. Only figures every learner
may see get a link: a learner's own paper stays behind the signed-in endpoint.
"""

import hashlib
import hmac
import re

SIGNATURE_CHARS = 32
_SHA = re.compile(r"^[0-9a-f]{64}$")


def window_expiry(now: int, hours: int) -> int:
    """The end of the window after the current one, so a link lasts between one and two windows."""
    window = hours * 3600
    return (now // window + 2) * window


def signature(sha256: str, expires: int, key: bytes) -> str:
    message = f"figure:{sha256}:{expires}".encode()
    return hmac.new(key, message, hashlib.sha256).hexdigest()[:SIGNATURE_CHARS]


def valid(sha256: str, expires: int, given: str, key: bytes, now: int) -> bool:
    if not _SHA.match(sha256) or expires < now:
        return False
    return hmac.compare_digest(signature(sha256, expires, key), given)


def cache_seconds(expires: int, now: int, longest: int) -> int:
    """How long a cache may keep the answer: never past the link's own expiry."""
    return max(0, min(expires - now, longest))
