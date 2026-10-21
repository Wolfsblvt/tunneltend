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
ACCENT_DARK = "#79CAD9"
ACCENT_LIGHT = "#167B91"

# Source master -> bundle role/file. SVG appearances are copied unchanged.
# The tintable master (currentColor) serves both background classes, so it is
# copied once per appearance; each gets its own static PNG fallback ink.
SVG_COPIES = {
    "tunneltend-fold-dark.svg": ["mark-primary/on-dark.svg"],
    "tunneltend-fold-light.svg": ["mark-primary/on-light.svg"],
    "tunneltend-fold.svg": [
        "mark-primary/on-dark-tintable.svg",
        "mark-primary/on-light-tintable.svg",
    ],
    "favicon-dark.svg": ["icon-favicon/on-dark.svg"],
    "favicon-light.svg": ["icon-favicon/on-light.svg"],
    "favicon.svg": ["icon-favicon/universal-adaptive.svg"],
    "application-icon.svg": ["icon-application/universal.svg"],
}

# The static fallback of a tintable variant is the master rendered in the
# approved text ink for its background class.
TINTABLE_FALLBACK_INK = {"on-dark": INK_DARK, "on-light": INK_LIGHT}


def render(svg: Path, pixels: int, ink: str | None = None) -> Image.Image:
    data = svg.read_bytes()
    if ink is not None:
        data = data.replace(b"currentColor", ink.encode())
    png = cairosvg.svg2png(bytestring=data, output_width=pixels, output_height=pixels)
    return Image.open(io.BytesIO(png)).convert("RGBA")


def export_svgs() -> None:
    for source_name, targets in SVG_COPIES.items():
        for target in targets:
            destination = ASSETS / target
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(SOURCE / source_name, destination)


def export_rasters() -> None:
    for appearance in ("on-dark", "on-light"):
        render(ASSETS / "mark-primary" / f"{appearance}.svg", 512).save(
            ASSETS / "mark-primary" / f"{appearance}-512x512.png"
        )
        render(
            ASSETS / "mark-primary" / f"{appearance}-tintable.svg",
            512,
            TINTABLE_FALLBACK_INK[appearance],
        ).save(ASSETS / "mark-primary" / f"{appearance}-tintable-512x512.png")
        render(ASSETS / "icon-favicon" / f"{appearance}.svg", 32).save(
            ASSETS / "icon-favicon" / f"{appearance}-32x32.png"
        )

    # Avatar-sized application icon: an opaque graphite tile that stays
    # legible on any ground, so one universal appearance carries it.
    for pixels in (64, 128):
        render(ASSETS / "icon-application" / "universal.svg", pixels).save(
            ASSETS / "icon-application" / f"universal-{pixels}x{pixels}.png"
        )

    # The ICO is the one fixed-background favicon projection: graphite keeps
    # it legible independently of the browser or tab theme.
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
    panel_w, panel_h, pad = 440, 560, 28
    sheet = Image.new("RGBA", (panel_w * 2, panel_h), CHALK)
    themes = (
        ("on-dark", GRAPHITE, INK_DARK, MUTED_DARK, ACCENT_DARK, 0),
        ("on-light", CHALK, INK_LIGHT, MUTED_LIGHT, ACCENT_LIGHT, panel_w),
    )
    ico = Image.open(ASSETS / "icon-favicon" / "universal-48x48.ico")
    application = ASSETS / "icon-application"
    for appearance, background, ink, muted, accent, x0 in themes:
        draw = ImageDraw.Draw(sheet)
        draw.rectangle([x0, 0, x0 + panel_w, panel_h], fill=background)
        draw.text((x0 + pad, 22), f"The Fold · {appearance}", fill=ink, font=font(18))

        mark = ASSETS / "mark-primary" / f"{appearance}.svg"
        tintable = ASSETS / "mark-primary" / f"{appearance}-tintable.svg"
        favicon = ASSETS / "icon-favicon" / f"{appearance}.svg"
        sheet.alpha_composite(render(mark, 160), (x0 + pad, 60))

        # Actual-size rows: what a reader sees at small sizes.
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

        # Exported 512 px PNG scaled down, then the ICO frames (opaque graphite).
        draw.text((x0 + pad, 246), "Exported 512 px PNG at 24 and 16 px", fill=muted, font=font(12))
        exported = Image.open(ASSETS / "mark-primary" / f"{appearance}-512x512.png").convert("RGBA")
        x = x0 + pad
        for pixels in (24, 16):
            sheet.alpha_composite(exported.resize((pixels, pixels), Image.LANCZOS), (x, 270))
            x += pixels + 14

        draw.text((x0 + 232, 246), "Fallback ICO frames", fill=muted, font=font(12))
        x = x0 + 232
        for size in (16, 32, 48):
            ico.size = (size, size)
            sheet.alpha_composite(ico.convert("RGBA"), (x, 270))
            x += size + 14

        # Tintable colour treatment: the currentColor master tinted with this
        # background's text ink and accent, and its static PNG fallback.
        draw.text((x0 + pad, 332), "mark.primary tintable: text ink, accent ink, PNG fallback", fill=muted, font=font(12))
        x = x0 + pad
        for tint in (ink, accent):
            for pixels in (24, 16):
                sheet.alpha_composite(render(tintable, pixels, tint), (x, 356))
                x += pixels + 14
        fallback = Image.open(ASSETS / "mark-primary" / f"{appearance}-tintable-512x512.png").convert("RGBA")
        for pixels in (24, 16):
            sheet.alpha_composite(fallback.resize((pixels, pixels), Image.LANCZOS), (x + 14, 356))
            x += pixels + 14

        # Application icon / avatar tile, opaque so it reads on either ground.
        draw.text((x0 + pad, 410), "icon.application, 128 and 64 px", fill=muted, font=font(12))
        x = x0 + pad
        for pixels in (128, 64):
            tile = Image.open(application / f"universal-{pixels}x{pixels}.png").convert("RGBA")
            sheet.alpha_composite(tile, (x, 434))
            x += pixels + 18

    sheet.save(CONTACT_SHEET)


if __name__ == "__main__":
    export_svgs()
    export_rasters()
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    contact_sheet()
    print(f"Exported to {ASSETS} and {CONTACT_SHEET}")
