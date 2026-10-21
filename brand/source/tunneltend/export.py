#!/usr/bin/env python3
"""Export TunnelTend's raster identity assets from the approved Fold SVG masters.

Reads the masters beside this file, copies the SVG appearances into the bundle
byte for byte, and renders the PNG/ICO projections plus the contact sheet.
Never redraws or normalizes path data. Needs CairoSVG and Pillow, which this
script never installs: create an isolated environment yourself, for example
`python -m venv .venv` then `pip install cairosvg pillow`.

Run from anywhere: python brand/source/tunneltend/export.py
"""
from __future__ import annotations

import io
import shutil
from pathlib import Path

import cairosvg
from PIL import Image, ImageDraw, ImageFont

SOURCE = Path(__file__).resolve().parent
ROOT = SOURCE.parents[2]
ASSETS = ROOT / "brand" / "bundle" / "tunneltend" / "assets"
CONTACT_SHEET = ROOT / "docs" / "assets" / "brand-contact-sheet.png"

GRAPHITE = "#191821"
CHALK = "#FAF9FB"
INK_DARK = "#F0EDF3"
INK_LIGHT = "#25222D"
MUTED_DARK = "#AAA4B2"
MUTED_LIGHT = "#635D6B"

# Source master -> bundle role/file. SVG appearances are copied unchanged.
SVG_COPIES = {
    "tunneltend-fold-dark.svg": "mark-primary/on-dark.svg",
    "tunneltend-fold-light.svg": "mark-primary/on-light.svg",
    "tunneltend-fold.svg": "mark-primary/universal-tintable.svg",
    "favicon-dark.svg": "icon-favicon/on-dark.svg",
    "favicon-light.svg": "icon-favicon/on-light.svg",
    "favicon.svg": "icon-favicon/universal-adaptive.svg",
}


def render(svg: Path, pixels: int) -> Image.Image:
    png = cairosvg.svg2png(
        bytestring=svg.read_bytes(), output_width=pixels, output_height=pixels
    )
    return Image.open(io.BytesIO(png)).convert("RGBA")


def export_svgs() -> None:
    for source_name, target in SVG_COPIES.items():
        destination = ASSETS / target
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(SOURCE / source_name, destination)


def export_rasters() -> None:
    for appearance in ("on-dark", "on-light"):
        render(ASSETS / "mark-primary" / f"{appearance}.svg", 512).save(
            ASSETS / "mark-primary" / f"{appearance}-512x512.png"
        )
        render(ASSETS / "icon-favicon" / f"{appearance}.svg", 32).save(
            ASSETS / "icon-favicon" / f"{appearance}-32x32.png"
        )

    # The ICO is the one fixed-background projection: graphite keeps it
    # legible independently of the browser or tab theme.
    canvas = Image.new("RGBA", (256, 256), GRAPHITE)
    side = round(256 * 0.80)
    glyph = render(SOURCE / "favicon-dark.svg", side)
    canvas.alpha_composite(glyph, ((256 - side) // 2, (256 - side) // 2))
    canvas.save(
        ASSETS / "icon-favicon" / "universal-48x48.ico",
        format="ICO",
        sizes=[(16, 16), (32, 32), (48, 48)],
    )


def font(size: int) -> ImageFont.ImageFont:
    for name in ("segoeui.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def contact_sheet() -> None:
    """Render the exported assets at their real sizes on both backgrounds."""
    panel_w, panel_h, pad = 440, 400, 28
    sheet = Image.new("RGBA", (panel_w * 2, panel_h), CHALK)
    themes = (
        ("on-dark", GRAPHITE, INK_DARK, MUTED_DARK, 0),
        ("on-light", CHALK, INK_LIGHT, MUTED_LIGHT, panel_w),
    )
    for appearance, background, ink, muted, x0 in themes:
        draw = ImageDraw.Draw(sheet)
        draw.rectangle([x0, 0, x0 + panel_w, panel_h], fill=background)
        draw.text((x0 + pad, 22), f"The Fold · {appearance}", fill=ink, font=font(18))

        mark = ASSETS / "mark-primary" / f"{appearance}.svg"
        favicon = ASSETS / "icon-favicon" / f"{appearance}.svg"
        sheet.alpha_composite(render(mark, 160), (x0 + pad, 60))

        # Actual-size row: what a reader sees at 16, 24, 32 and 64 px.
        x = x0 + 232
        draw.text((x, 60), "mark.primary, actual size", fill=muted, font=font(12))
        for pixels in (16, 24, 32, 64):
            sheet.alpha_composite(render(mark, pixels), (x, 84))
            x += pixels + 14

        x = x0 + 232
        draw.text((x, 170), "icon.favicon, actual size", fill=muted, font=font(12))
        for pixels in (16, 20, 32):
            sheet.alpha_composite(render(favicon, pixels), (x, 194))
            x += pixels + 14

        draw.text((x0 + pad, 246), "Exported PNG (512 px) at 24 and 16 px", fill=muted, font=font(12))
        exported = Image.open(ASSETS / "mark-primary" / f"{appearance}-512x512.png").convert("RGBA")
        x = x0 + pad
        for pixels in (24, 16):
            sheet.alpha_composite(exported.resize((pixels, pixels), Image.LANCZOS), (x, 270))
            x += pixels + 14

    # Fixed-background ICO frames, shown once across the bottom.
    ico = Image.open(ASSETS / "icon-favicon" / "universal-48x48.ico")
    x = pad
    draw = ImageDraw.Draw(sheet)
    draw.text((232 + pad, 246), "Fallback ICO frames", fill=MUTED_DARK, font=font(12))
    x = 232 + pad
    for size in (16, 32, 48):
        ico.size = (size, size)
        frame = ico.convert("RGBA")
        sheet.alpha_composite(frame, (x, 270))
        x += size + 14

    sheet.save(CONTACT_SHEET)


if __name__ == "__main__":
    export_svgs()
    export_rasters()
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    contact_sheet()
    print(f"Exported to {ASSETS} and {CONTACT_SHEET}")
