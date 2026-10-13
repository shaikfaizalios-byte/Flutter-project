"""OCR engines. The service depends only on the ``OcrEngine`` protocol, so tests use a fake
and production uses the Tesseract command-line program (no Python wrapper needed)."""

import csv
import io
import os
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Protocol

from PIL import Image


class OcrUnavailableError(RuntimeError):
    """The OCR engine (or the requested language data) is not installed."""


class OcrFailedError(RuntimeError):
    """The engine ran but could not process the image (crash, timeout, bad output)."""


@dataclass(frozen=True, slots=True)
class OcrResult:
    text: str
    # Mean word confidence 0-100, or None when no words were recognised.
    mean_confidence: float | None
    word_count: int


class OcrEngine(Protocol):
    def recognize(self, image: Image.Image, *, languages: str, timeout_seconds: float) -> OcrResult:
        """Recognise text. ``languages`` uses Tesseract syntax, e.g. ``"hin+eng"``."""


class TesseractOcrEngine:
    def __init__(self, command: str = "tesseract", tessdata_dir: Path | None = None) -> None:
        self._command = command
        self._tessdata_dir = tessdata_dir

    def is_available(self, languages: str = "eng") -> bool:
        try:
            installed = self.installed_languages()
        except OcrUnavailableError:
            return False
        return all(lang in installed for lang in languages.split("+"))

    def installed_languages(self) -> set[str]:
        output = self._run(["--list-langs"], stdin=None, timeout_seconds=30)
        # First line is a header ("List of available languages in ...").
        return {line.strip() for line in output.splitlines()[1:] if line.strip()}

    def recognize(self, image: Image.Image, *, languages: str, timeout_seconds: float) -> OcrResult:
        buffer = io.BytesIO()
        image.save(buffer, format="PNG")
        # stdin -> stdout, TSV output gives per-word confidences.
        tsv = self._run(
            [
                *("stdin", "stdout", "-l", languages, "--psm", "6"),
                # TSV via options, not the "tsv" config file (which lives in one tessdata dir).
                *("-c", "tessedit_create_tsv=1", "-c", "tessedit_create_txt=0"),
            ],
            stdin=buffer.getvalue(),
            timeout_seconds=timeout_seconds,
        )
        return parse_tesseract_tsv(tsv)

    def _run(self, args: list[str], *, stdin: bytes | None, timeout_seconds: float) -> str:
        executable = shutil.which(self._command) or (
            self._command if Path(self._command).is_file() else None
        )
        if executable is None:
            raise OcrUnavailableError("Tesseract is not installed.")
        command = [executable]
        if self._tessdata_dir is not None:
            command += ["--tessdata-dir", str(self._tessdata_dir)]
        # OMP threads multiply with our own concurrency; one thread per page is enough.
        env = {**os.environ, "OMP_THREAD_LIMIT": "1"}
        try:
            completed = subprocess.run(  # noqa: S603 - fixed executable, no shell
                command + args,
                input=stdin,
                capture_output=True,
                timeout=timeout_seconds,
                check=False,
                env=env,
            )
        except subprocess.TimeoutExpired as exc:
            raise OcrFailedError("Tesseract timed out.") from exc
        except OSError as exc:
            raise OcrUnavailableError("Tesseract could not be started.") from exc
        stderr = completed.stderr.decode("utf-8", "replace")
        if completed.returncode != 0:
            if "Failed loading language" in stderr or "Error opening data file" in stderr:
                raise OcrUnavailableError("Tesseract language data is missing.")
            raise OcrFailedError(f"Tesseract exited with code {completed.returncode}.")
        return completed.stdout.decode("utf-8", "replace")


def parse_tesseract_tsv(tsv: str) -> OcrResult:
    """Rebuild line-preserving text and the mean word confidence from Tesseract TSV."""
    lines: dict[tuple[int, int, int, int], list[str]] = {}
    confidences: list[float] = []
    for row in csv.DictReader(io.StringIO(tsv), delimiter="\t", quoting=csv.QUOTE_NONE):
        word = (row.get("text") or "").strip()
        try:
            conf = float(row.get("conf") or -1)
        except ValueError:
            continue
        if row.get("level") != "5" or not word or conf < 0:
            continue
        key = (
            int(row["page_num"]),
            int(row["block_num"]),
            int(row["par_num"]),
            int(row["line_num"]),
        )
        lines.setdefault(key, []).append(word)
        confidences.append(conf)
    text = "\n".join(" ".join(words) for _, words in sorted(lines.items()))
    mean = sum(confidences) / len(confidences) if confidences else None
    return OcrResult(text=text, mean_confidence=mean, word_count=len(confidences))
