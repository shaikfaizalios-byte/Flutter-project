"""Reading page layouts from a PDF and rendering crops of it (PDFium).

The layout is what ``app.domain.figures`` needs: text lines with positions (in the PDF's own
text order, the same text the extractor stores) and the image / vector objects on the page.
Crops are rendered from the original PDF, so a figure is shown exactly as printed.
"""

import io
from collections.abc import Iterator
from pathlib import Path

import pypdfium2 as pdfium
import pypdfium2.raw as pdfium_c
from PIL import Image

from app.domain.figures import Box, Graphic, LayoutLine, PageLayout

_GRAPHIC_KINDS = {
    pdfium_c.FPDF_PAGEOBJ_IMAGE: "image",
    pdfium_c.FPDF_PAGEOBJ_PATH: "path",
    pdfium_c.FPDF_PAGEOBJ_SHADING: "shading",
}
# Rendering: 2x = 144 dpi, enough for small symbols; very wide crops are scaled down.
RENDER_SCALE = 2.0
MAX_CROP_PIXELS = 1600
MAX_CROP_BYTES = 1_000_000


def read_layouts(pdf_path: Path, pages: set[int]) -> Iterator[PageLayout]:
    """Yield the layout of each requested page (1-based numbers), one page in memory at a
    time."""
    document = pdfium.PdfDocument(pdf_path)
    try:
        for number in sorted(pages):
            if not 1 <= number <= len(document):
                continue
            page = document[number - 1]
            try:
                yield _layout(page, number)
            finally:
                page.close()
    finally:
        document.close()


def _layout(page: pdfium.PdfPage, number: int) -> PageLayout:
    width, height = page.get_size()
    text_page = page.get_textpage()
    try:
        lines = _lines(text_page)
    finally:
        text_page.close()
    graphics: list[Graphic] = []
    # Form XObjects are walked into (max_depth); their own bounds are not used.
    for obj in page.get_objects(max_depth=4):
        kind = _GRAPHIC_KINDS.get(obj.type)
        if kind is None:
            continue
        left, bottom, right, top = obj.get_bounds()
        graphics.append(Graphic(kind, Box(left, bottom, right, top)))
    return PageLayout(
        number=number,
        width=width,
        height=height,
        lines=lines,
        graphics=graphics,
        rotated=page.get_rotation() % 360 != 0,
    )


def _lines(text_page: pdfium.PdfTextPage) -> list[LayoutLine]:
    count = text_page.count_chars()
    if count <= 0:
        return []
    text = text_page.get_text_range(0, count)
    if len(text) != count:  # characters outside the BMP: positions would not line up
        return [LayoutLine(t, Box(0, 0, 0, 0)) for t in text.replace("\r", "").split("\n")]
    lines: list[LayoutLine] = []
    start = 0
    for index in range(count + 1):
        if index < count and text[index] != "\n":
            continue
        line_text = text[start:index].replace("\r", "")
        box: Box | None = None
        for i in range(start, index):
            if text[i].isspace() or pdfium_c.FPDFText_IsGenerated(text_page, i) == 1:
                continue
            left, bottom, right, top = text_page.get_charbox(i)
            char_box = Box(left, bottom, right, top)
            box = char_box if box is None else box.union(char_box)
        lines.append(LayoutLine(line_text, box or Box(0, 0, 0, 0)))
        start = index + 1
    return lines


class PdfRenderer:
    """Renders crops of one PDF, keeping the document open between crops."""

    def __init__(self, pdf_path: Path) -> None:
        self._document = pdfium.PdfDocument(pdf_path)

    def __enter__(self) -> "PdfRenderer":
        return self

    def __exit__(self, *_exc: object) -> None:
        self.close()

    def close(self) -> None:
        self._document.close()

    def render(self, page_number: int, box: Box) -> tuple[bytes, int, int]:
        """PNG bytes (and pixel size) of ``box`` on the page, rendered from the PDF."""
        page = self._document[page_number - 1]
        try:
            width, height = page.get_size()
            scale = min(RENDER_SCALE, MAX_CROP_PIXELS / max(box.width, 1.0))
            bitmap = page.render(
                scale=scale,
                crop=(box.left, box.bottom, width - box.right, height - box.top),
            )
            try:
                image = bitmap.to_pil()
                try:
                    return _png(image)
                finally:
                    image.close()
            finally:
                bitmap.close()
        finally:
            page.close()


def _png(image: Image.Image) -> tuple[bytes, int, int]:
    current = image.convert("RGB")
    while True:
        buffer = io.BytesIO()
        current.save(buffer, format="PNG", optimize=True)
        data = buffer.getvalue()
        if len(data) <= MAX_CROP_BYTES or current.width < 200:
            return data, current.width, current.height
        current = current.resize((current.width * 3 // 4, current.height * 3 // 4))
