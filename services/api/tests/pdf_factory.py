"""Small synthetic PDFs for tests (generated, so no copyrighted papers are committed)."""

import io
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from reportlab.lib import pdfencrypt
from reportlab.lib.utils import ImageReader
from reportlab.pdfgen import canvas

SAMPLE_QUESTION = [
    "Q.1 What is 20% of 150?",
    "(1) 20   (2) 30   (3) 40   (4) 50",
    "Q.2 Choose the synonym of RAPID.",
    "(1) Slow   (2) Quick   (3) Late   (4) Weak",
]


def text_pdf(pages: list[list[str]] | None = None, *, password: str | None = None) -> bytes:
    """A PDF with a real text layer; one inner list of lines per page."""
    pages = pages if pages is not None else [SAMPLE_QUESTION]
    buffer = io.BytesIO()
    encrypt = pdfencrypt.StandardEncryption(password, "owner-secret") if password else None
    pdf = canvas.Canvas(buffer, encrypt=encrypt)
    for lines in pages:
        y = 760
        for line in lines:
            pdf.drawString(72, y, line)
            y -= 20
        pdf.showPage()
    pdf.save()
    return buffer.getvalue()


def text_image(lines: list[str], *, font_path: Path | None = None, size: int = 40) -> Image.Image:
    """Render lines of text into a white image (what a scanned page looks like)."""
    font: ImageFont.FreeTypeFont | ImageFont.ImageFont
    font = ImageFont.truetype(str(font_path), size) if font_path else ImageFont.load_default(size)
    image = Image.new("RGB", (1700, 200 + 80 * len(lines)), "white")
    draw = ImageDraw.Draw(image)
    for i, line in enumerate(lines):
        draw.text((80, 80 + 80 * i), line, fill="black", font=font)
    return image


def image_pdf(images: list[Image.Image]) -> bytes:
    """A 'scanned' PDF: every page is just an image, with no text layer."""
    buffer = io.BytesIO()
    pdf = canvas.Canvas(buffer)
    for image in images:
        width, height = 595, 842  # A4 in points
        pdf.drawImage(ImageReader(image), 0, height - 300, width=width, height=300)
        pdf.showPage()
    pdf.save()
    return buffer.getvalue()


def mixed_pdf() -> bytes:
    """Page 1 has a text layer; page 2 is image-only."""
    buffer = io.BytesIO()
    pdf = canvas.Canvas(buffer)
    y = 760
    for line in SAMPLE_QUESTION:
        pdf.drawString(72, y, line)
        y -= 20
    pdf.showPage()
    pdf.drawImage(ImageReader(text_image(["Scanned page"])), 0, 542, width=595, height=300)
    pdf.showPage()
    pdf.save()
    return buffer.getvalue()


def blank_pages_pdf(count: int) -> bytes:
    buffer = io.BytesIO()
    pdf = canvas.Canvas(buffer)
    for _ in range(count):
        pdf.showPage()
    pdf.save()
    return buffer.getvalue()


PNG_BYTES = (
    b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00"
    b"\x1f\x15\xc4\x89\x00\x00\x00\rIDATx\x9cc\xf8\x0f\x00\x00\x01\x01\x00\x05\x18\xd8N\x00"
    b"\x00\x00\x00IEND\xaeB`\x82"
)
CORRUPT_PDF = b"%PDF-1.7\n1 0 obj << /Type /Catalog >> endobj\ntrailer garbage\n%%EOF"
