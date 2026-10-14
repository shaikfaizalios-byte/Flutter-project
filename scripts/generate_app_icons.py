"""Generates PrepLoop's launcher icons for Android, iOS and web from one drawn master.

A simple, provisional brand mark: a loop (the study loop) and a check on the brand teal.
Replace with a designer's artwork before public release by changing `draw_master` or
dropping a 1024 px master PNG at `--master`.

    services\\api\\.venv\\Scripts\\python.exe scripts\\generate_app_icons.py
"""

import argparse
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
MOBILE = ROOT / "apps" / "mobile"
BRAND = (0x1E, 0x6B, 0x8F, 255)  # AppTheme.seed
LIGHT = (0xF4, 0xFA, 0xFD, 255)

ANDROID = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
IOS = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}


def draw_master(size: int = 1024, *, rounded: bool, padding: float = 0.0) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    if rounded:
        draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=int(size * 0.22), fill=BRAND)
    else:
        draw.rectangle((0, 0, size, size), fill=BRAND)
    inset = size * (0.2 + padding)
    box = (inset, inset, size - inset, size - inset)
    width = int(size * 0.075)
    # The loop: an open circle, from 300° round to 240°, leaving a gap at the top right.
    draw.arc(box, start=-60, end=240, fill=LIGHT, width=width)
    # The check mark inside the loop.
    c = size / 2
    s = (size - 2 * inset) / 2
    points = [(c - s * 0.42, c + s * 0.02), (c - s * 0.1, c + s * 0.34), (c + s * 0.48, c - s * 0.3)]
    draw.line(points, fill=LIGHT, width=width, joint="curve")
    return image


def save(image: Image.Image, path: Path, size: int, *, opaque: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    resized = image.resize((size, size), Image.Resampling.LANCZOS)
    if opaque:  # App Store icons must not have transparency
        background = Image.new("RGBA", resized.size, BRAND)
        background.alpha_composite(resized)
        resized = background.convert("RGB")
    resized.save(path, optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--master", type=Path, help="Optional 1024 px artwork to use instead")
    args = parser.parse_args()
    rounded = Image.open(args.master).convert("RGBA") if args.master else draw_master(rounded=True)
    square = Image.open(args.master).convert("RGBA") if args.master else draw_master(rounded=False)

    res = MOBILE / "android" / "app" / "src" / "main" / "res"
    for density, size in ANDROID.items():
        save(rounded, res / f"mipmap-{density}" / "ic_launcher.png", size)
    # Splash image (centred on the brand colour, see launch_background.xml).
    save(draw_master(rounded=False, padding=0.05), res / "drawable" / "splash_logo.png", 288)

    icons = MOBILE / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for name, size in IOS.items():
        save(square, icons / name, size, opaque=True)

    web = MOBILE / "web"
    save(rounded, web / "favicon.png", 32)
    save(rounded, web / "icons" / "Icon-192.png", 192)
    save(rounded, web / "icons" / "Icon-512.png", 512)
    maskable = draw_master(rounded=False, padding=0.08)  # safe zone for maskable icons
    save(maskable, web / "icons" / "Icon-maskable-192.png", 192)
    save(maskable, web / "icons" / "Icon-maskable-512.png", 512)
    print("Icons written for Android, iOS and web.")


if __name__ == "__main__":
    main()
