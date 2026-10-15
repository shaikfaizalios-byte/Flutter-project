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


def _page_furniture(pdf: canvas.Canvas) -> None:
    """A logo and a footer rule at the same place on every page (decoration)."""
    pdf.circle(560, 760, 15, stroke=1, fill=1)
    pdf.line(36, 30, 576, 30)


def figure_paper_pdf() -> bytes:
    """Two pages of questions with drawn figures (vector paths), for figure detection.

    Q1: four options that are figures; Q2: text only; Q3: a figure in the stem, options on
    one line; Q4: a bar chart with value labels inside it; Q5: a "formula" drawn as graphics
    on the text line; Q6: a question inside a bordered box (layout, not a figure).
    """
    buffer = io.BytesIO()
    pdf = canvas.Canvas(buffer, pagesize=(612, 792))
    _page_furniture(pdf)
    pdf.drawString(36, 720, "Q.1 Select the Venn diagram that best illustrates the classes.")
    pdf.drawString(36, 700, "(a)")
    pdf.circle(100, 670, 18)
    pdf.circle(120, 670, 18)
    pdf.drawString(36, 630, "(b)")
    for x in (90, 130, 170):
        pdf.circle(x, 600, 14)
    pdf.drawString(36, 560, "(c)")
    pdf.circle(110, 530, 25)
    pdf.circle(110, 530, 15)
    pdf.drawString(36, 490, "(d)")
    pdf.circle(100, 460, 20)
    pdf.drawString(36, 420, "Q.2 What is 20 percent of 150?")
    for i, option in enumerate(["(a) 20", "(b) 30", "(c) 40", "(d) 50"]):
        pdf.drawString(36, 400 - 15 * i, option)
    pdf.drawString(36, 320, "Q.3 How many triangles are there in the following figure?")
    pdf.line(80, 240, 200, 240)
    pdf.line(80, 240, 140, 300)
    pdf.line(200, 240, 140, 300)
    pdf.line(140, 300, 140, 240)
    pdf.drawString(36, 220, "(a) 4 (b) 6 (c) 8 (d) 10")
    pdf.showPage()

    _page_furniture(pdf)
    pdf.drawString(36, 740, "Q.4 The bar graph shows the sales of shops A and B.")
    pdf.rect(60, 600, 200, 120)  # chart frame
    pdf.rect(90, 610, 30, 80, fill=1)
    pdf.rect(170, 610, 30, 50, fill=1)
    pdf.drawString(95, 695, "100")
    pdf.drawString(178, 665, "70")
    pdf.drawString(100, 603, "A")
    pdf.drawString(180, 603, "B")
    pdf.drawString(36, 580, "What is the total sales of both shops?")
    for i, option in enumerate(["(a) 170", "(b) 150", "(c) 130", "(d) 30"]):
        pdf.drawString(36, 560 - 15 * i, option)
    pdf.drawString(36, 480, "Q.5 Find the value of")
    pdf.rect(150, 476, 24, 14)  # a formula drawn as graphics on the text line
    pdf.line(150, 483, 174, 483)
    for i, option in enumerate(["(a) 1", "(b) 2", "(c) 3", "(d) 4"]):
        pdf.drawString(36, 460 - 15 * i, option)
    pdf.rect(30, 290, 400, 100)  # a bordered question
    pdf.drawString(36, 370, "Q.6 Choose the synonym of RAPID.")
    for i, option in enumerate(["(a) Slow", "(b) Quick", "(c) Late", "(d) Weak"]):
        pdf.drawString(36, 350 - 15 * i, option)
    pdf.drawString(36, 200, "Answer Key")
    pdf.drawString(36, 180, "1-(a) 2-(b) 3-(b) 4-(a) 5-(a) 6-(b)")
    pdf.showPage()
    pdf.save()
    return buffer.getvalue()
