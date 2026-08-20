#!/usr/bin/env python3

"""Create deterministic, brand-led showcase panels around untouched app captures."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "screenshots" / "flower-show-v3" / "raw"
OUTPUT = ROOT / "screenshots" / "flower-show-v3" / "showcase"
REVIEW = ROOT / "screenshots" / "flower-show-v3" / "review"
CANVAS = (1242, 2688)
FONT_ROUNDED = "/System/Library/Fonts/SFNSRounded.ttf"
FONT_REGULAR = "/System/Library/Fonts/SFNS.ttf"


SLIDES = (
    {
        "source": "01-two-modes.png",
        "output": "01-two-ways-to-bloom.png",
        "eyebrow": "RINGBLOOM · FLOWER SHOW",
        "title": "TWO WAYS\nTO BLOOM",
        "subtitle": "Endless calm. Crafted challenge.",
        "top": (16, 28, 50),
        "bottom": (11, 53, 59),
        "accent": (84, 211, 169),
    },
    {
        "source": "02-class-book.png",
        "output": "02-thirty-classes-no-filler.png",
        "eyebrow": "THE CLASS BOOK",
        "title": "THIRTY CLASSES.\nNO FILLER.",
        "subtitle": "Every new rule earns its place.",
        "top": (19, 28, 55),
        "bottom": (35, 26, 67),
        "accent": (101, 170, 255),
    },
    {
        "source": "03-bindweed.png",
        "output": "03-the-garden-fights-back.png",
        "eyebrow": "NEW RULE · BINDWEED",
        "title": "THE GARDEN\nFIGHTS BACK",
        "subtitle": "Read the spread. Clear every stem.",
        "top": (17, 34, 51),
        "bottom": (13, 70, 57),
        "accent": (84, 211, 169),
    },
    {
        "source": "04-grand-final.png",
        "output": "04-every-turn-has-consequences.png",
        "eyebrow": "CLASS 30 · GRAND FINAL",
        "title": "EVERY TURN HAS\nCONSEQUENCES",
        "subtitle": "Three objectives. Six choices. One clean route.",
        "top": (25, 26, 52),
        "bottom": (65, 31, 52),
        "accent": (255, 106, 103),
    },
    {
        "source": "05-judges-order.png",
        "output": "05-play-to-the-rhythm.png",
        "eyebrow": "CHAMPION CIRCUIT · JUDGES' ORDER",
        "title": "PLAY TO\nTHE RHYTHM",
        "subtitle": "The next ring matters as much as the bloom.",
        "top": (22, 29, 58),
        "bottom": (38, 33, 81),
        "accent": (255, 199, 78),
    },
    {
        "source": "06-champion-circuit.png",
        "output": "06-the-show-never-ends.png",
        "eyebrow": "AFTER THE GRAND FINAL",
        "title": "THE SHOW\nNEVER ENDS",
        "subtitle": "Become Grand Champion. Then keep climbing.",
        "top": (17, 28, 52),
        "bottom": (18, 60, 72),
        "accent": (86, 180, 255),
    },
    {
        "source": "07-grand-champion.png",
        "output": "07-become-grand-champion.png",
        "eyebrow": "CLASS 30 COMPLETE",
        "title": "BECOME THE\nGRAND CHAMPION",
        "subtitle": "Finish the campaign. Enter the Circuit.",
        "top": (22, 28, 49),
        "bottom": (68, 50, 25),
        "accent": (255, 199, 78),
    },
)


def interpolate(first: int, second: int, amount: float) -> int:
    return round(first + (second - first) * amount)


def gradient(size: tuple[int, int], top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    width, height = size
    strip = Image.new("RGB", (1, height))
    pixels = strip.load()
    for y in range(height):
        amount = y / max(1, height - 1)
        eased = amount * amount * (3 - 2 * amount)
        pixels[0, y] = tuple(interpolate(a, b, eased) for a, b in zip(top, bottom))
    return strip.resize((width, height))


def add_ambient_art(canvas: Image.Image, accent: tuple[int, int, int], index: int) -> None:
    width, height = canvas.size
    glow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)

    anchors = (
        (-80, 250, 570, 900),
        (790, 90, 1460, 780),
        (720, 1850, 1480, 2690),
    )
    for offset, box in enumerate(anchors):
        alpha = 34 if offset == 0 else 22
        shifted = tuple(value + (index * 27 if point % 2 == 0 else 0) for point, value in enumerate(box))
        glow_draw.ellipse(shifted, fill=(*accent, alpha))
    canvas.alpha_composite(glow.filter(ImageFilter.GaussianBlur(95)))

    geometry = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(geometry)
    centre_x = 980 if index % 2 == 0 else 215
    centre_y = 410
    for radius, alpha in ((170, 52), (245, 34), (330, 20)):
        draw.ellipse(
            (centre_x - radius, centre_y - radius, centre_x + radius, centre_y + radius),
            outline=(*accent, alpha),
            width=3,
        )
    for angle in range(0, 360, 60):
        radians = math.radians(angle + index * 11)
        x = centre_x + math.cos(radians) * 205
        y = centre_y + math.sin(radians) * 205
        petal = (x - 24, y - 58, x + 24, y + 58)
        draw.ellipse(petal, fill=(*accent, 22))
    canvas.alpha_composite(geometry)


def rounded_screenshot(source: Image.Image, target_width: int) -> Image.Image:
    target_height = round(source.height * target_width / source.width)
    screenshot = source.convert("RGBA").resize((target_width, target_height), Image.Resampling.LANCZOS)
    mask = Image.new("L", screenshot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, target_width - 1, target_height - 1), radius=62, fill=255)
    screenshot.putalpha(ImageChops.multiply(screenshot.getchannel("A"), mask))
    return screenshot


def centred_text(draw: ImageDraw.ImageDraw, canvas_width: int, y: int, text: str, font: ImageFont.FreeTypeFont, fill: tuple[int, ...], spacing: int = 6) -> int:
    bounds = draw.multiline_textbbox((0, 0), text, font=font, spacing=spacing, align="center")
    text_width = bounds[2] - bounds[0]
    text_height = bounds[3] - bounds[1]
    draw.multiline_text(((canvas_width - text_width) / 2, y), text, font=font, fill=fill, spacing=spacing, align="center")
    return y + text_height


def compose(slide: dict[str, object], index: int) -> Path:
    source_path = RAW / str(slide["source"])
    if not source_path.exists():
        raise FileNotFoundError(source_path)

    canvas = gradient(CANVAS, slide["top"], slide["bottom"]).convert("RGBA")
    accent = slide["accent"]
    add_ambient_art(canvas, accent, index)

    draw = ImageDraw.Draw(canvas)
    eyebrow_font = ImageFont.truetype(FONT_ROUNDED, 34)
    title_font = ImageFont.truetype(FONT_ROUNDED, 86)
    subtitle_font = ImageFont.truetype(FONT_REGULAR, 38)

    eyebrow = str(slide["eyebrow"])
    eyebrow_bounds = draw.textbbox((0, 0), eyebrow, font=eyebrow_font)
    eyebrow_width = eyebrow_bounds[2] - eyebrow_bounds[0]
    pill_width = eyebrow_width + 62
    pill_x = (CANVAS[0] - pill_width) / 2
    draw.rounded_rectangle((pill_x, 74, pill_x + pill_width, 134), radius=30, fill=(*accent, 42), outline=(*accent, 112), width=2)
    draw.text(((CANVAS[0] - eyebrow_width) / 2, 83), eyebrow, font=eyebrow_font, fill=(235, 242, 250, 225))

    title_bottom = centred_text(draw, CANVAS[0], 170, str(slide["title"]), title_font, (255, 246, 214, 255), spacing=-2)
    centred_text(draw, CANVAS[0], title_bottom + 22, str(slide["subtitle"]), subtitle_font, (226, 233, 244, 220))

    screenshot = rounded_screenshot(Image.open(source_path), 890)
    screenshot_x = (CANVAS[0] - screenshot.width) // 2
    screenshot_y = 610

    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(
        (screenshot_x - 18, screenshot_y - 10, screenshot_x + screenshot.width + 18, screenshot_y + screenshot.height + 28),
        radius=78,
        fill=(0, 0, 0, 170),
    )
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(34)))

    frame = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    frame_draw = ImageDraw.Draw(frame)
    frame_draw.rounded_rectangle(
        (screenshot_x - 14, screenshot_y - 14, screenshot_x + screenshot.width + 14, screenshot_y + screenshot.height + 14),
        radius=76,
        fill=(7, 13, 24, 255),
        outline=(*accent, 145),
        width=3,
    )
    canvas.alpha_composite(frame)
    canvas.alpha_composite(screenshot, (screenshot_x, screenshot_y))

    OUTPUT.mkdir(parents=True, exist_ok=True)
    output_path = OUTPUT / str(slide["output"])
    canvas.convert("RGB").save(output_path, "PNG", optimize=True)
    return output_path


def make_contact_sheet(outputs: list[Path]) -> Path:
    columns = 4
    thumb_width = 360
    thumb_height = round(CANVAS[1] * thumb_width / CANVAS[0])
    gap = 28
    margin = 42
    rows = math.ceil(len(outputs) / columns)
    sheet_width = margin * 2 + columns * thumb_width + (columns - 1) * gap
    sheet_height = margin * 2 + rows * thumb_height + (rows - 1) * gap
    sheet = gradient((sheet_width, sheet_height), (14, 24, 43), (17, 46, 50)).convert("RGB")

    for index, output in enumerate(outputs):
        thumbnail = Image.open(output).convert("RGB").resize((thumb_width, thumb_height), Image.Resampling.LANCZOS)
        x = margin + (index % columns) * (thumb_width + gap)
        y = margin + (index // columns) * (thumb_height + gap)
        sheet.paste(thumbnail, (x, y))

    REVIEW.mkdir(parents=True, exist_ok=True)
    contact_sheet = REVIEW / "flower-show-v3-contact-sheet.png"
    sheet.save(contact_sheet, "PNG", optimize=True)
    return contact_sheet


def main() -> None:
    outputs = [compose(slide, index) for index, slide in enumerate(SLIDES)]
    contact_sheet = make_contact_sheet(outputs)
    print(f"FLOWER_SHOW_V3_SHOWCASE_COMPOSED directory={OUTPUT} count={len(outputs)}")
    for output in outputs:
        print(output.name)
    print(f"FLOWER_SHOW_V3_CONTACT_SHEET path={contact_sheet}")


if __name__ == "__main__":
    main()
