#!/usr/bin/env python3

"""Build the October 2026 (iOS 27) App Store creative set for Ringbloom.

Inputs are first-party simulator captures (iPhone 17 Pro, iOS 27, en_GB, 09:41) kept under
store-assets/2026-10-ios27/source/. Nothing here fabricates UI: every screen is an untouched
capture (or a still from an untouched recording) placed inside brand-coloured panels.

Outputs (all opaque RGB PNG):
  screenshots/APP_IPHONE_67-1320x2868/en-GB/NN-name.png
  screenshots/APP_IPHONE_65-1242x2688/en-GB/NN-name.png
  creative/header-21x9.png   3840x1646
  creative/search-3x2.png    3840x2560
  contact-sheet.png

Run from anywhere:  python3 Tools/compose-ios27-store-assets.py
"""

from __future__ import annotations

import math
import subprocess
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "store-assets" / "2026-10-ios27"
SRC = OUT / "source"
CAPTURES = Path("/Users/tommurton/GitHub/Marketing-tool/apps/ringbloom/inputs/captures-2026-10")
GAMEPLAY = CAPTURES / "ringbloom-garden1-gameplay-19s.mp4"
ICON = ROOT / "Art" / "ringbloom-icon-master.png"

FONT_ROUNDED = "/System/Library/Fonts/SFNSRounded.ttf"
FONT_REGULAR = "/System/Library/Fonts/SFNS.ttf"

NAVY = (15, 25, 43)
IVORY = (255, 243, 220)
CORAL = (255, 106, 103)
SAFFRON = (247, 198, 83)
MINT = (80, 208, 170)
SKY = (101, 170, 255)


def rounded_font(size: int, weight: str = "Bold") -> ImageFont.FreeTypeFont:
    font = ImageFont.truetype(FONT_ROUNDED, size)
    font.set_variation_by_name(weight)
    return font


def regular_font(size: int, weight: str = "Medium") -> ImageFont.FreeTypeFont:
    font = ImageFont.truetype(FONT_REGULAR, size)
    try:
        font.set_variation_by_name(weight)
    except OSError:
        pass
    return font


# --------------------------------------------------------------------------------------
# Sources
# --------------------------------------------------------------------------------------

STILLS = {
    # name: (video time in seconds)
    "garden1-combo-bloom": 15.5,   # two blooms from one turn, "A bloom combo is opening"
    "garden1-single-bloom": 7.5,   # one bloom opening, chain 1
    "garden1-hint": 4.9,           # hint highlights the Middle ring
}


def flatten(path: Path) -> Image.Image:
    """Return the capture flattened onto opaque navy (captures carry an all-opaque alpha)."""
    image = Image.open(path)
    if image.mode == "RGBA":
        base = Image.new("RGB", image.size, NAVY)
        base.paste(image, mask=image.getchannel("A"))
        return base
    return image.convert("RGB")


def prepare_sources() -> dict[str, Image.Image]:
    SRC.mkdir(parents=True, exist_ok=True)
    sources: dict[str, Image.Image] = {}
    for name, seconds in STILLS.items():
        target = SRC / f"{name}.png"
        if not target.exists():
            subprocess.run(
                ["ffmpeg", "-v", "error", "-y", "-ss", str(seconds), "-i", str(GAMEPLAY), "-frames:v", "1", str(target)],
                check=True,
            )
        sources[name] = flatten(target)
    for name, filename in (
        ("class1-card", "ringbloom-flower-show-class1-card.png"),
        ("class-book", "ringbloom-flower-show-class-book.png"),
    ):
        target = SRC / f"{name}.png"
        if not target.exists():
            flatten(CAPTURES / filename).save(target, "PNG", optimize=True)
        sources[name] = flatten(target)
    return sources


# --------------------------------------------------------------------------------------
# Shared drawing helpers
# --------------------------------------------------------------------------------------

def lerp(a: int, b: int, t: float) -> int:
    return round(a + (b - a) * t)


def vertical_gradient(size: tuple[int, int], top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    width, height = size
    strip = Image.new("RGB", (1, height))
    pixels = strip.load()
    for y in range(height):
        t = y / max(1, height - 1)
        t = t * t * (3 - 2 * t)
        pixels[0, y] = tuple(lerp(a, b, t) for a, b in zip(top, bottom))
    return strip.resize((width, height))


def radial_glow(size: tuple[int, int], centre: tuple[float, float], radius: float, colour: tuple[int, int, int], strength: float) -> Image.Image:
    """Soft RGBA glow; built small and upscaled for speed."""
    scale = 8
    small = (max(1, size[0] // scale), max(1, size[1] // scale))
    layer = Image.new("L", small, 0)
    draw = ImageDraw.Draw(layer)
    cx, cy, r = centre[0] / scale, centre[1] / scale, radius / scale
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=int(255 * strength))
    layer = layer.filter(ImageFilter.GaussianBlur(r * 0.55)).resize(size, Image.Resampling.BICUBIC)
    glow = Image.new("RGBA", size, (*colour, 0))
    glow.putalpha(layer)
    return glow


def ring_motif(canvas: Image.Image, centre: tuple[float, float], radii: tuple[int, ...], colour: tuple[int, int, int], alpha: int, width: int) -> None:
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for radius in radii:
        draw.ellipse(
            (centre[0] - radius, centre[1] - radius, centre[0] + radius, centre[1] + radius),
            outline=(*colour, alpha),
            width=width,
        )
    canvas.alpha_composite(layer)


def petal_motif(canvas: Image.Image, centre: tuple[float, float], orbit: float, colour: tuple[int, int, int], alpha: int, count: int, phase: float, length: float, thickness: float) -> None:
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for index in range(count):
        angle = math.radians(phase + index * 360 / count)
        x = centre[0] + math.cos(angle) * orbit
        y = centre[1] + math.sin(angle) * orbit
        petal = Image.new("RGBA", (int(length * 2), int(length * 2)), (0, 0, 0, 0))
        ImageDraw.Draw(petal).ellipse(
            (length - thickness, length - length * 0.5, length + thickness, length + length * 0.5),
            fill=(*colour, alpha),
        )
        petal = petal.rotate(-math.degrees(angle) - 90, resample=Image.Resampling.BICUBIC)
        layer.alpha_composite(petal, (int(x - length), int(y - length)))
    canvas.alpha_composite(layer)


def text_size(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont, spacing: int = 0) -> tuple[int, int]:
    box = draw.multiline_textbbox((0, 0), text, font=font, spacing=spacing, align="center")
    return box[2] - box[0], box[3] - box[1]


def centred_text(draw: ImageDraw.ImageDraw, canvas_width: int, y: int, text: str, font: ImageFont.FreeTypeFont, fill: tuple[int, ...], spacing: int = 0) -> int:
    box = draw.multiline_textbbox((0, 0), text, font=font, spacing=spacing, align="center")
    draw.multiline_text(((canvas_width - (box[2] - box[0])) / 2 - box[0], y), text, font=font, fill=fill, spacing=spacing, align="center")
    return y + box[3]


def rounded_phone(source: Image.Image, width: int, radius: int) -> Image.Image:
    height = round(source.height * width / source.width)
    shot = source.convert("RGBA").resize((width, height), Image.Resampling.LANCZOS)
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width - 1, height - 1), radius=radius, fill=255)
    shot.putalpha(ImageChops.multiply(shot.getchannel("A"), mask))
    return shot


def place_phone(canvas: Image.Image, source: Image.Image, x: int, y: int, width: int, radius: int, accent: tuple[int, int, int], border: int) -> tuple[int, int]:
    shot = rounded_phone(source, width, radius)
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (x - border - 8, y - border + 6, x + width + border + 8, y + shot.height + border + 34),
        radius=radius + border + 8,
        fill=(0, 0, 0, 165),
    )
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(radius * 0.55)))
    frame = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle(
        (x - border, y - border, x + width + border, y + shot.height + border),
        radius=radius + border,
        fill=(7, 13, 24, 255),
        outline=(*accent, 150),
        width=max(2, border // 5),
    )
    canvas.alpha_composite(frame)
    canvas.alpha_composite(shot, (x, y))
    return width, shot.height


# --------------------------------------------------------------------------------------
# Screenshots
# --------------------------------------------------------------------------------------

SLIDES = (
    {
        "file": "01-turn-a-ring-bloom-the-garden",
        "layout": "single",
        "source": "garden1-combo-bloom",
        "eyebrow": "RINGBLOOM",
        "title": "TURN A RING.\nBLOOM THE GARDEN.",
        "subtitle": "One thumb. Three rings.",
        "top": (17, 29, 52),
        "bottom": (12, 52, 60),
        "accent": MINT,
    },
    {
        "file": "02-two-ways-to-play",
        "layout": "pair",
        "source": "garden1-single-bloom",
        "source2": "class1-card",
        "eyebrow": "RINGBLOOM",
        "title": "TWO WAYS\nTO PLAY",
        "subtitle": "Settle in, or take on a Class.",
        "labels": (("GARDEN", "Endless and calm"), ("FLOWER SHOW", "Judged Classes")),
        "top": (19, 28, 55),
        "bottom": (38, 31, 70),
        "accent": SAFFRON,
    },
    {
        "file": "03-a-new-rule-to-master",
        "layout": "single",
        "source": "class1-card",
        "eyebrow": "FLOWER SHOW",
        "title": "A NEW RULE\nTO MASTER",
        "subtitle": "Special rules. Fresh objectives.",
        "top": (17, 31, 54),
        "bottom": (66, 38, 54),
        "accent": CORAL,
    },
    {
        "file": "04-thirty-classes-to-master",
        "layout": "single",
        "source": "class-book",
        "eyebrow": "THE CLASS BOOK",
        "title": "THIRTY CLASSES\nTO MASTER",
        "subtitle": "Replay to improve your rating.",
        "top": (19, 28, 55),
        "bottom": (24, 52, 82),
        "accent": SKY,
    },
    {
        "file": "05-stuck-take-a-hint",
        "layout": "single",
        "source": "garden1-hint",
        "eyebrow": "GARDEN",
        "title": "STUCK?\nTAKE A HINT",
        "subtitle": "Hints show which ring to turn.",
        "top": (17, 30, 50),
        "bottom": (62, 52, 30),
        "accent": SAFFRON,
    },
)


def slide_background(size: tuple[int, int], slide: dict, index: int) -> Image.Image:
    width, height = size
    canvas = vertical_gradient(size, slide["top"], slide["bottom"]).convert("RGBA")
    accent = slide["accent"]
    unit = width / 1242
    canvas.alpha_composite(radial_glow(size, (width * 0.12, height * 0.14), 520 * unit, accent, 0.22))
    canvas.alpha_composite(radial_glow(size, (width * 0.92, height * 0.9), 620 * unit, accent, 0.16))
    centre = (width * (0.82 if index % 2 == 0 else 0.18), 410 * unit)
    ring_motif(canvas, centre, tuple(int(r * unit) for r in (170, 245, 330)), accent, 46, max(2, int(3 * unit)))
    return canvas


def header_block(canvas: Image.Image, slide: dict, unit: float) -> int:
    width = canvas.width
    draw = ImageDraw.Draw(canvas)
    accent = slide["accent"]
    eyebrow_font = rounded_font(int(34 * unit), "Semibold")
    title_font = rounded_font(int(86 * unit), "Heavy")
    subtitle_font = regular_font(int(42 * unit), "Medium")

    eyebrow = slide["eyebrow"]
    ew, _ = text_size(draw, eyebrow, eyebrow_font)
    pill_w = ew + 66 * unit
    pill_x = (width - pill_w) / 2
    draw.rounded_rectangle((pill_x, 74 * unit, pill_x + pill_w, 134 * unit), radius=30 * unit, fill=(*accent, 44), outline=(*accent, 120), width=max(2, int(2 * unit)))
    draw.text(((width - ew) / 2, 83 * unit), eyebrow, font=eyebrow_font, fill=(238, 244, 250, 235))
    bottom = centred_text(draw, width, int(166 * unit), slide["title"], title_font, (*IVORY, 255), spacing=int(-2 * unit))
    return centred_text(draw, width, bottom + int(24 * unit), slide["subtitle"], subtitle_font, (226, 233, 244, 225))


def compose_single(slide: dict, sources: dict[str, Image.Image], size: tuple[int, int], index: int) -> Image.Image:
    width, height = size
    unit = width / 1242
    canvas = slide_background(size, slide, index)
    header_block(canvas, slide, unit)
    phone_w = int(930 * unit)
    place_phone(canvas, sources[slide["source"]], (width - phone_w) // 2, int(570 * unit), phone_w, int(62 * unit), slide["accent"], int(14 * unit))
    return canvas.convert("RGB")


def compose_pair(slide: dict, sources: dict[str, Image.Image], size: tuple[int, int], index: int) -> Image.Image:
    width, height = size
    unit = width / 1242
    canvas = slide_background(size, slide, index)
    header_block(canvas, slide, unit)
    draw = ImageDraw.Draw(canvas)
    phone_w = int(590 * unit)
    gap = int(28 * unit)
    left_x = (width - (2 * phone_w + gap)) // 2
    top = int(790 * unit)
    label_font = rounded_font(int(36 * unit), "Bold")
    note_font = regular_font(int(40 * unit), "Medium")
    for position, (key, (label, note)) in enumerate(zip(("source", "source2"), slide["labels"])):
        x = left_x + position * (phone_w + gap)
        drop = int(position * 170 * unit)
        colour = MINT if position == 0 else SAFFRON
        lw, _ = text_size(draw, label, label_font)
        pill_w = lw + 54 * unit
        pill_x = x + (phone_w - pill_w) / 2
        draw.rounded_rectangle((pill_x, 670 * unit + drop, pill_x + pill_w, 736 * unit + drop), radius=33 * unit, fill=(*colour, 52), outline=(*colour, 150), width=max(2, int(2 * unit)))
        draw.text((x + (phone_w - lw) / 2, 680 * unit + drop), label, font=label_font, fill=(*IVORY, 255))
        _, phone_h = place_phone(canvas, sources[slide[key]], x, top + drop, phone_w, int(44 * unit), colour, int(10 * unit))
        nw, _ = text_size(draw, note, note_font)
        draw.text((x + (phone_w - nw) / 2, top + drop + phone_h + 52 * unit), note, font=note_font, fill=(226, 233, 244, 235))
    return canvas.convert("RGB")


def compose_screenshots(sources: dict[str, Image.Image]) -> dict[str, list[Path]]:
    written: dict[str, list[Path]] = {}
    for folder, size in (("APP_IPHONE_67-1320x2868", (1320, 2868)), ("APP_IPHONE_65-1242x2688", (1242, 2688))):
        directory = OUT / "screenshots" / folder / "en-GB"
        directory.mkdir(parents=True, exist_ok=True)
        for old in directory.glob("*.png"):
            old.unlink()
        paths = []
        for index, slide in enumerate(SLIDES):
            image = (compose_pair if slide["layout"] == "pair" else compose_single)(slide, sources, size, index)
            path = directory / f"{slide['file']}.png"
            image.save(path, "PNG", optimize=True)
            paths.append(path)
        written[folder] = paths
    return written


# --------------------------------------------------------------------------------------
# Header (21:9) and search (3:2)
# --------------------------------------------------------------------------------------

def board_crop(source: Image.Image, scale: float, feather: float = 0.07) -> Image.Image:
    """The ring board from a gameplay capture, edge-faded so it melts into the panel."""
    crop = source.crop((0, 665, 1206, 1871))
    width, height = round(crop.width * scale), round(crop.height * scale)
    crop = crop.resize((width, height), Image.Resampling.LANCZOS).convert("RGBA")
    mask = Image.new("L", crop.size, 0)
    fade = int(min(width, height) * feather)
    ImageDraw.Draw(mask).ellipse((fade, fade, width - fade, height - fade), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(fade * 0.55))
    crop.putalpha(mask)
    return crop


def app_icon(size: int) -> Image.Image:
    icon = Image.open(ICON).convert("RGB").resize((size, size), Image.Resampling.LANCZOS).convert("RGBA")
    mask = Image.new("L", icon.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), radius=int(size * 0.225), fill=255)
    icon.putalpha(mask)
    return icon


def creative_background(size: tuple[int, int], focus: tuple[float, float]) -> Image.Image:
    width, height = size
    canvas = Image.new("RGBA", size, (*NAVY, 255))
    canvas.alpha_composite(radial_glow(size, focus, height * 0.95, (44, 70, 118), 0.85))
    canvas.alpha_composite(radial_glow(size, (width * 0.06, height * 0.9), height * 0.7, CORAL, 0.16))
    canvas.alpha_composite(radial_glow(size, (width * 0.95, height * 0.12), height * 0.7, MINT, 0.14))
    canvas.alpha_composite(radial_glow(size, (width * 0.93, height * 0.92), height * 0.55, SAFFRON, 0.12))
    canvas.alpha_composite(radial_glow(size, (width * 0.04, height * 0.1), height * 0.55, SKY, 0.13))
    ring_motif(canvas, focus, tuple(int(height * f) for f in (0.46, 0.62, 0.8, 1.02)), (180, 205, 240), 30, max(3, height // 400))
    return canvas


def compose_header(sources: dict[str, Image.Image]) -> Image.Image:
    size = (3840, 1646)
    focus = (2500.0, 823.0)
    canvas = creative_background(size, focus)

    board = board_crop(sources["garden1-combo-bloom"], 1.0)
    canvas.alpha_composite(board, (int(focus[0] - board.width / 2), int(focus[1] - board.height / 2)))

    draw = ImageDraw.Draw(canvas)
    title_font = rounded_font(168, "Heavy")
    lines = ["Turn a ring.", "Bloom the", "garden."]
    line_height = 184
    icon_size = 200
    block_h = icon_size + 56 + line_height * len(lines)
    top = int((size[1] - block_h) / 2)
    left = 800
    canvas.alpha_composite(app_icon(icon_size), (left, top))
    y = top + icon_size + 56
    for line in lines:
        draw.text((left, y), line, font=title_font, fill=(*IVORY, 255))
        y += line_height
    return canvas.convert("RGB")


def compose_search(sources: dict[str, Image.Image]) -> Image.Image:
    size = (3840, 2560)
    focus = (2640.0, 1280.0)
    canvas = creative_background(size, focus)

    phone_w = 1180
    shot = sources["garden1-combo-bloom"]
    place_phone(canvas, shot, int(focus[0] - phone_w / 2), 150, phone_w, 92, MINT, 22)

    draw = ImageDraw.Draw(canvas)
    title_font = rounded_font(236, "Heavy")
    lines = ["Turn a ring.", "Bloom the", "garden."]
    line_height = 262
    icon_size = 270
    block_h = icon_size + 90 + line_height * len(lines)
    top = int((size[1] - block_h) / 2)
    left = 300
    canvas.alpha_composite(app_icon(icon_size), (left, top))
    y = top + icon_size + 90
    for line in lines:
        draw.text((left, y), line, font=title_font, fill=(*IVORY, 255))
        y += line_height
    return canvas.convert("RGB")


# --------------------------------------------------------------------------------------
# Contact sheet
# --------------------------------------------------------------------------------------

def contact_sheet(shots: list[Path], header: Path, search: Path, poster: Path | None) -> Path:
    thumb_w = 330
    thumb_h = round(2868 * thumb_w / 1320)
    margin, gap = 36, 24
    columns = max(len(shots), 6)
    row1_w = margin * 2 + columns * thumb_w + (columns - 1) * gap
    creative_w = (row1_w - margin * 2 - gap) // 2
    header_img = Image.open(header).convert("RGB")
    search_img = Image.open(search).convert("RGB")
    header_thumb = header_img.resize((creative_w, round(header_img.height * creative_w / header_img.width)), Image.Resampling.LANCZOS)
    search_thumb = search_img.resize((creative_w, round(search_img.height * creative_w / search_img.width)), Image.Resampling.LANCZOS)
    row2_h = max(header_thumb.height, search_thumb.height)
    sheet = Image.new("RGB", (row1_w, margin * 3 + thumb_h + row2_h + 20), (10, 16, 28))
    for i, path in enumerate(shots):
        sheet.paste(Image.open(path).convert("RGB").resize((thumb_w, thumb_h), Image.Resampling.LANCZOS), (margin + i * (thumb_w + gap), margin))
    if poster and poster.exists():
        p = Image.open(poster).convert("RGB")
        p = p.resize((thumb_w, round(p.height * thumb_w / p.width)), Image.Resampling.LANCZOS)
        sheet.paste(p, (margin + len(shots) * (thumb_w + gap), margin))
    y2 = margin * 2 + thumb_h
    sheet.paste(header_thumb, (margin, y2))
    sheet.paste(search_thumb, (margin + creative_w + gap, y2))
    path = OUT / "contact-sheet.png"
    sheet.save(path, "PNG", optimize=True)
    return path


def main() -> None:
    sources = prepare_sources()
    written = compose_screenshots(sources)
    creative = OUT / "creative"
    creative.mkdir(parents=True, exist_ok=True)
    header_path = creative / "header-21x9.png"
    search_path = creative / "search-3x2.png"
    compose_header(sources).save(header_path, "PNG", optimize=True)
    compose_search(sources).save(search_path, "PNG", optimize=True)
    poster = OUT / "preview" / "poster-frame.png"
    sheet = contact_sheet(written["APP_IPHONE_67-1320x2868"], header_path, search_path, poster)
    print("IOS27_STORE_ASSETS_COMPOSED", OUT)
    print("contact sheet", sheet)


if __name__ == "__main__":
    main()
