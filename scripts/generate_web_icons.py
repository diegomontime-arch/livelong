#!/usr/bin/env python3
"""
Generate PWA / web icons from a tenant logo (multi-tenant ready).

Usage:
  python3 scripts/generate_web_icons.py --tenant=m4life

Place logo at assets/tenants/{tenant}/logo.jpg (or .png / .jpeg).
Falls back to web/icons/og-image.png (center crop) if missing.
"""

from __future__ import annotations

import argparse
import os
import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "web"
ICONS = WEB / "icons"
TENANTS = ROOT / "assets" / "tenants"

BLACK = (0, 0, 0)

ICON_OUTPUTS = {
    "web/favicon.png": 32,
    "web/favicon-48.png": 48,
    "web/icons/Icon-192.png": 192,
    "web/icons/Icon-512.png": 512,
    "web/icons/Icon-maskable-192.png": 192,
    "web/icons/Icon-maskable-512.png": 512,
}


def resolve_logo_path(tenant: str) -> Path | None:
    base = TENANTS / tenant
    for name in ("logo.jpg", "logo.jpeg", "logo.png", "logo.JPG", "logo.PNG"):
        path = base / name
        if path.is_file():
            return path
    return None


def bootstrap_logo_from_og(tenant: str) -> Path:
    """Crop M4LIFE title area from og-image when no logo file exists."""
    og_path = ICONS / "og-image.png"
    if not og_path.is_file():
        raise FileNotFoundError(
            f"Missing {og_path}. Add assets/tenants/{tenant}/logo.jpg manually."
        )

    og = Image.open(og_path).convert("RGB")
    w, h = og.size
    side = min(w, h, 600)
    cx, cy = w // 2, int(h * 0.38)
    left = max(0, cx - side // 2)
    top = max(0, cy - side // 2)
    crop = og.crop((left, top, min(w, left + side), min(h, top + side)))

    out_dir = TENANTS / tenant
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / "logo.png"
    crop.save(out_path, "PNG", optimize=True)
    print(f"Bootstrap logo from og-image → {out_path}")
    return out_path


def ensure_tenant_logo(tenant: str, source_upload: str | None) -> Path:
    if source_upload:
        src = Path(source_upload)
        if not src.is_file():
            raise FileNotFoundError(f"Logo upload not found: {src}")
        out_dir = TENANTS / tenant
        out_dir.mkdir(parents=True, exist_ok=True)
        ext = src.suffix.lower() or ".jpg"
        dest = out_dir / f"logo{ext if ext in {'.jpg', '.jpeg', '.png'} else '.jpg'}"
        shutil.copy2(src, dest)
        print(f"Copied upload → {dest}")
        return dest

    existing = resolve_logo_path(tenant)
    if existing:
        return existing

    if tenant != "m4life":
        default = resolve_logo_path("default")
        if default:
            out_dir = TENANTS / tenant
            out_dir.mkdir(parents=True, exist_ok=True)
            dest = out_dir / "logo.png"
            shutil.copy2(default, dest)
            print(f"Using default logo → {dest}")
            return dest

    return bootstrap_logo_from_og(tenant)


def create_icon_from_logo(
    logo_path: Path,
    size: int,
    output_path: Path,
    *,
    maskable: bool = False,
) -> None:
    logo = Image.open(logo_path).convert("RGB")

    icon = Image.new("RGB", (size, size), color=BLACK)

    margin = size // 6 if maskable else size // 8
    max_size = size - (margin * 2)
    logo_copy = logo.copy()
    logo_copy.thumbnail((max_size, max_size), Image.Resampling.LANCZOS)

    x = (size - logo_copy.width) // 2
    y = (size - logo_copy.height) // 2
    icon.paste(logo_copy, (x, y))

    output_path.parent.mkdir(parents=True, exist_ok=True)
    icon.save(output_path, "PNG", optimize=True)
    print(f"Criado: {output_path} ({size}x{size})")


def generate_icons(tenant: str, source_upload: str | None) -> None:
    logo_path = ensure_tenant_logo(tenant, source_upload)

    for rel_path, size in ICON_OUTPUTS.items():
        out = ROOT / rel_path
        maskable = "maskable" in rel_path
        create_icon_from_logo(
            logo_path,
            size,
            out,
            maskable=maskable,
        )

    print(f"\nÍcones gerados para tenant '{tenant}'!")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate web icons from tenant logo")
    parser.add_argument(
        "--tenant",
        default="m4life",
        help="Tenant companyId (folder under assets/tenants/)",
    )
    parser.add_argument(
        "--source",
        default=None,
        help="Optional path to logo image (e.g. upload JPEG)",
    )
    args = parser.parse_args()

    generate_icons(args.tenant, args.source)


if __name__ == "__main__":
    main()
