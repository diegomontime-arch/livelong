#!/usr/bin/env python3
"""Generate HitLook web icons and Open Graph image."""

from __future__ import annotations

import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "web"
ICONS = WEB / "icons"

GOLD = (212, 175, 55)
BLACK = (0, 0, 0)


def _font(size: int, bold: bool = True) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/Library/Fonts/Arial Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "C:\\Windows\\Fonts\\arialbd.ttf",
    ]
    if not bold:
        candidates.insert(0, "/System/Library/Fonts/Supplemental/Arial.ttf")
    for path in candidates:
        if os.path.isfile(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def create_app_icon(size: int, *, maskable: bool = False) -> Image.Image:
    img = Image.new("RGB", (size, size), color=BLACK)
    draw = ImageDraw.Draw(img)
    margin = size // 6 if maskable else size // 8
    draw.ellipse(
        [margin, margin, size - margin, size - margin],
        outline=GOLD,
        width=max(2, size // 20),
    )
    font = _font(size // 3)
    draw.text((size // 2, size // 2), "HL", fill=GOLD, anchor="mm", font=font)
    return img


def create_og_image() -> Image.Image:
    w, h = 1200, 630
    img = Image.new("RGB", (w, h), color=BLACK)
    draw = ImageDraw.Draw(img)

    # Decorative rings
    cx, cy = w // 2, h // 2 - 20
    for radius, width in [(220, 4), (260, 2)]:
        draw.ellipse(
            [cx - radius, cy - radius, cx + radius, cy + radius],
            outline=GOLD,
            width=width,
        )

    title_font = _font(72)
    sub_font = _font(36, bold=False)
    brand_font = _font(28)

    draw.text((cx, cy - 30), "M4LIFE USA", fill=GOLD, anchor="mm", font=title_font)
    draw.text(
        (cx, cy + 50),
        "Proteção Familiar",
        fill=(200, 200, 200),
        anchor="mm",
        font=sub_font,
    )
    draw.text(
        (cx, cy + 120),
        "Descubra seu nível de proteção familiar",
        fill=(150, 150, 150),
        anchor="mm",
        font=sub_font,
    )

    # HitLook badge
    badge_size = 96
    bx, by = 48, 48
    draw.ellipse(
        [bx, by, bx + badge_size, by + badge_size],
        outline=GOLD,
        width=3,
    )
    draw.text(
        (bx + badge_size // 2, by + badge_size // 2),
        "HL",
        fill=GOLD,
        anchor="mm",
        font=_font(32),
    )
    draw.text((bx + badge_size + 16, by + 34), "HitLook", fill=GOLD, font=brand_font)

    return img


def main() -> None:
    ICONS.mkdir(parents=True, exist_ok=True)

    for size in (192, 512):
        icon = create_app_icon(size)
        icon.save(ICONS / f"Icon-{size}.png")
        create_app_icon(size, maskable=True).save(ICONS / f"Icon-maskable-{size}.png")

    create_app_icon(32).save(WEB / "favicon.png")
    create_app_icon(48).save(WEB / "favicon-48.png")

    og = create_og_image()
    og.save(ICONS / "og-image.png", optimize=True)

    print("Generated:")
    print(f"  {WEB / 'favicon.png'}")
    for p in sorted(ICONS.glob("*.png")):
        print(f"  {p}")


if __name__ == "__main__":
    main()
