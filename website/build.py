"""Build the public website into a folder (GitHub Pages publishes it).

    python website/build.py --out _site                # website only
    python website/build.py --out _site --with-app     # the Flutter web app is in _site/app/

The legal pages are generated from the same Markdown the app shows
(apps/mobile/assets/legal/*.md), so the website and the app never disagree. Standard library
only: the Markdown subset those files use (headings, paragraphs, lists, bold, links, code) is
converted here.
"""

import argparse
import html
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SITE = ROOT / "website"
LEGAL = ROOT / "apps/mobile/assets/legal"

TEXT = {
    "en": {
        "open_app": "Open the web app",
        "see": "See what it does",
        "note_app": "Works in your browser. Android and iOS apps are coming soon.",
        "note_no_app": "Coming soon: the web app and the Android and iOS apps.",
    },
    "hi": {
        "open_app": "वेब ऐप खोलें",
        "see": "देखें यह क्या करता है",
        "note_app": "आपके ब्राउज़र में चलता है। Android और iOS ऐप जल्द आ रहे हैं।",
        "note_no_app": "जल्द आ रहा है: वेब ऐप और Android व iOS ऐप।",
    },
}

LEGAL_PAGE = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{title} – PrepLoop</title>
  <link rel="icon" href="../favicon.png">
  <link rel="stylesheet" href="../styles.css">
</head>
<body>
<header class="site-header">
  <div class="wrap">
    <a class="brand" href="../"><img src="../icon.png" alt="" width="34" height="34">PrepLoop</a>
    <nav class="nav" aria-label="Main"><a href="../">Home</a><a href="../privacy/">Privacy</a>
      <a href="../terms/">Terms</a></nav>
  </div>
</header>
<main class="doc" id="main">
{body}
</main>
</body>
</html>
"""


def _inline(text: str) -> str:
    out = html.escape(text, quote=False)
    out = re.sub(r"`([^`]+)`", r"<code>\1</code>", out)
    out = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", out)
    out = re.sub(
        r"\[([^\]]+)\]\((https?://[^)\s]+|mailto:[^)\s]+)\)",
        lambda m: f'<a href="{html.escape(m.group(2))}">{m.group(1)}</a>',
        out,
    )
    return out


def markdown(source: str) -> str:
    """The subset used by the legal texts. Unknown syntax stays as (escaped) text."""
    blocks: list[str] = []
    paragraph: list[str] = []
    items: list[str] = []

    def flush() -> None:
        if paragraph:
            text = " ".join(paragraph)
            css = ' class="banner"' if text.startswith("**Draft") else ""
            blocks.append(f"<p{css}>{_inline(text)}</p>")
            paragraph.clear()
        if items:
            blocks.append(
                "<ul>" + "".join(f"<li>{_inline(i)}</li>" for i in items) + "</ul>"
            )
            items.clear()

    for raw in source.splitlines():
        line = raw.rstrip()
        heading = re.match(r"^(#{1,3})\s+(.*)$", line)
        if heading:
            flush()
            level = len(heading.group(1))
            blocks.append(f"<h{level}>{_inline(heading.group(2))}</h{level}>")
        elif re.match(r"^[-*]\s+", line):
            if paragraph:
                flush()
            items.append(re.sub(r"^[-*]\s+", "", line))
        elif line.startswith("  ") and items:
            items[-1] += " " + line.strip()  # continuation of a list item
        elif not line.strip():
            flush()
        else:
            if items:
                flush()
            paragraph.append(line.strip())
    flush()
    return "\n".join(blocks)


def render(page: Path, lang: str, *, with_app: bool, prefix: str) -> str:
    t = TEXT[lang]
    text = page.read_text(encoding="utf-8")
    app = f"{prefix}app/"
    nav = (
        f'<a class="btn btn-primary" href="{app}">{t["open_app"]}</a>'
        if with_app
        else ""
    )
    hero = (
        f'<a class="btn btn-primary" href="{app}">{t["open_app"]}</a>'
        if with_app
        else f'<a class="btn btn-primary" href="#features">{t["see"]}</a>'
    )
    return (
        text.replace("{{NAV_CTA}}", nav)
        .replace("{{HERO_CTA}}", hero)
        .replace(
            "{{AVAILABILITY_NOTE}}", t["note_app"] if with_app else t["note_no_app"]
        )
    )


def build(out: Path, *, with_app: bool) -> None:
    out.mkdir(parents=True, exist_ok=True)
    for item in (SITE / "static").iterdir():
        shutil.copy2(item, out / item.name)
    shutil.copy2(ROOT / "apps/mobile/web/icons/Icon-192.png", out / "icon.png")
    shutil.copy2(ROOT / "apps/mobile/web/favicon.png", out / "favicon.png")

    (out / "index.html").write_text(
        render(SITE / "pages/index.html", "en", with_app=with_app, prefix=""),
        encoding="utf-8",
    )
    (out / "hi").mkdir(exist_ok=True)
    (out / "hi/index.html").write_text(
        render(SITE / "pages/hi/index.html", "hi", with_app=with_app, prefix="../"),
        encoding="utf-8",
    )
    for slug, source, title in (
        ("privacy", "privacy-policy.md", "Privacy policy"),
        ("terms", "terms.md", "Terms of use"),
    ):
        body = markdown((LEGAL / source).read_text(encoding="utf-8"))
        (out / slug).mkdir(exist_ok=True)
        (out / slug / "index.html").write_text(
            LEGAL_PAGE.format(title=title, body=body), encoding="utf-8"
        )
    (out / ".nojekyll").write_text("", encoding="utf-8")  # serve files as they are


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=ROOT / "website/_site")
    parser.add_argument(
        "--with-app", action="store_true", help="link to the web app in app/"
    )
    args = parser.parse_args()
    build(args.out, with_app=args.with_app)
    print(f"Website written to {args.out}")


if __name__ == "__main__":
    main()
