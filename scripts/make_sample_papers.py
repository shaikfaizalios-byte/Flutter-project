"""Writes the made-up sample papers (services/api/data/sample_papers/*.pdf) from sample_papers.json.

The PDFs are committed; run this again only after changing the JSON. Needs reportlab (a dev
dependency of the API): services/api/.venv/Scripts/python.exe scripts/make_sample_papers.py
"""

import json
from pathlib import Path

from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas

FOLDER = Path(__file__).resolve().parent.parent / "services" / "api" / "data" / "sample_papers"
TOP, BOTTOM, LEFT = 800, 60, 56


def write(paper: dict, notice: list[str]) -> None:
    pdf = canvas.Canvas(str(FOLDER / paper["file"]), pagesize=A4, invariant=1)
    pdf.setTitle(paper["title"])
    pdf.setAuthor("PrepLoop (sample data)")
    y = TOP

    def line(text: str, *, size: int = 10, font: str = "Helvetica", gap: int = 16) -> None:
        nonlocal y
        if y < BOTTOM:
            pdf.showPage()
            y = TOP
        pdf.setFont(font, size)
        pdf.drawString(LEFT, y, text)
        y -= gap

    line(paper["title"], size=14, font="Helvetica-Bold", gap=20)
    for text in notice:
        line(text, font="Helvetica-Oblique")
    y -= 8
    number = 0
    key: list[str] = []
    for section in paper["sections"]:
        y -= 6
        line(section["heading"], size=12, font="Helvetica-Bold", gap=20)
        for stem, options, answer in section["questions"]:
            number += 1
            line(f"Q.{number} {stem}")
            line("   ".join(f"({i}) {text}" for i, text in enumerate(options, start=1)), gap=22)
            key.append(f"{number}-({answer})")
    y -= 10
    line("Answer Key", size=12, font="Helvetica-Bold", gap=20)
    for start in range(0, len(key), 5):
        line("   ".join(key[start : start + 5]))
    pdf.showPage()
    pdf.save()


def main() -> None:
    data = json.loads((FOLDER / "sample_papers.json").read_text(encoding="utf-8"))
    for paper in data["papers"]:
        write(paper, data["notice"])
        print("wrote", paper["file"])


if __name__ == "__main__":
    main()
