#!/usr/bin/env python3

"""Cut the October 2026 App Store app preview from the untouched iOS 27 Garden 1 recording.

Source: Marketing-tool/apps/ringbloom/inputs/captures-2026-10/ringbloom-garden1-gameplay-19s.mp4
(real Garden 1 play, iPhone 17 Pro simulator, iOS 27, 09:41). Real-time, not sped up.
Output: 886x1920 (Apple's accepted portrait size for iPhone), 30 fps, H.264 High 4.0,
~11 Mbps, stereo AAC (silent). The recording is inset in a navy frame with three short
captions so it reads when muted; it opens on a bloom, ends on a settled combo and fades
through navy at both ends so the loop is clean.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "store-assets" / "2026-10-ios27" / "preview"
WORK = OUT / "work"
SOURCE = Path("/Users/tommurton/GitHub/Marketing-tool/apps/ringbloom/inputs/captures-2026-10/ringbloom-garden1-gameplay-19s.mp4")

W, H = 886, 1920
NAVY = (15, 25, 43)
IVORY = (255, 243, 220)
VIDEO_W = 800
VIDEO_H = 1739  # 800 * 2622 / 1206, rounded to even
VIDEO_X = (W - VIDEO_W) // 2
VIDEO_Y = 96
CUT_START = 0.45   # first bloom glow begins ~0.6 s
CUT_END = 15.78    # combo settled; result card begins to fade in at ~15.85 s
HOLD = 0.70        # freeze on the settled combo so the clip is comfortably over 15 s
TOTAL = (CUT_END - CUT_START) + HOLD
CAPTIONS = (
    ("TURN A RING", 0.0, 4.6),
    ("FOLLOW A HINT", 4.6, 10.4),
    ("CHAIN BLOOMS", 10.4, TOTAL),
)
POSTER_SOURCE_TIME = 15.45
FONT = "/System/Library/Fonts/SFNSRounded.ttf"


def make_frame() -> Path:
    frame = Image.new("RGBA", (W, H), (*NAVY, 255))
    hole = Image.new("L", (W, H), 255)
    ImageDraw.Draw(hole).rounded_rectangle((VIDEO_X, VIDEO_Y, VIDEO_X + VIDEO_W - 1, VIDEO_Y + VIDEO_H - 1), radius=58, fill=0)
    frame.putalpha(hole)
    path = WORK / "frame.png"
    frame.save(path)
    return path


def make_caption(text: str, index: int) -> Path:
    image = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype(FONT, 46)
    font.set_variation_by_name("Heavy")
    box = draw.textbbox((0, 0), text, font=font)
    draw.text(((W - (box[2] - box[0])) / 2 - box[0], 28 - box[1]), text, font=font, fill=(*IVORY, 255))
    path = WORK / f"caption-{index}.png"
    image.save(path)
    return path


def main() -> None:
    WORK.mkdir(parents=True, exist_ok=True)
    frame = make_frame()
    captions = [make_caption(text, i) for i, (text, _, _) in enumerate(CAPTIONS)]
    output = OUT / "ringbloom-ios27-preview-886x1920.mp4"

    inputs = ["-i", str(SOURCE), "-loop", "1", "-i", str(frame)]
    for caption in captions:
        inputs += ["-loop", "1", "-i", str(caption)]
    inputs += ["-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=48000"]
    audio_index = 2 + len(captions)

    filters = [
        f"[0:v]trim=start={CUT_START}:end={CUT_END},setpts=PTS-STARTPTS,fps=30,"
        f"scale={VIDEO_W}:{VIDEO_H}:flags=lanczos,tpad=stop_mode=clone:stop_duration={HOLD}[vid]",
        f"color=c=0x{NAVY[0]:02x}{NAVY[1]:02x}{NAVY[2]:02x}:s={W}x{H}:r=30:d={TOTAL:.3f}[bg]",
        f"[bg][vid]overlay={VIDEO_X}:{VIDEO_Y}[a0]",
        "[a0][1:v]overlay=0:0:shortest=0[a1]",
    ]
    previous = "a1"
    for i, (_, start, end) in enumerate(CAPTIONS):
        label = f"c{i}"
        filters.append(f"[{previous}][{2 + i}:v]overlay=0:12:enable='between(t,{start:.2f},{end:.2f})'[{label}]")
        previous = label
    filters.append(
        f"[{previous}]fade=t=in:st=0:d=0.25:color=0x0f192b,fade=t=out:st={TOTAL - 0.45:.2f}:d=0.45:color=0x0f192b,format=yuv420p[outv]"
    )

    command = [
        "ffmpeg", "-hide_banner", "-y", *inputs,
        "-filter_complex", ";".join(filters),
        "-map", "[outv]", "-map", f"{audio_index}:a",
        "-t", f"{TOTAL:.3f}",
        "-c:v", "libx264", "-profile:v", "high", "-level:v", "4.0", "-pix_fmt", "yuv420p", "-r", "30",
        "-b:v", "11M", "-minrate", "11M", "-maxrate", "11M", "-bufsize", "22M", "-x264-params", "nal-hrd=cbr:force-cfr=1",
        "-c:a", "aac", "-b:a", "256k", "-ar", "48000", "-ac", "2",
        "-movflags", "+faststart",
        str(output),
    ]
    subprocess.run(command, check=True, stderr=open(WORK / "encode.log", "w"))

    # Poster frame: the combo moment, composed exactly like the video (no fades).
    poster_t = POSTER_SOURCE_TIME - CUT_START
    poster = OUT / "poster-frame.png"
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-ss", f"{poster_t:.2f}", "-i", str(output), "-frames:v", "1", str(poster)],
        check=True,
    )
    print(f"PREVIEW_BUILT {output} duration={TOTAL:.2f}s poster_at={poster_t:.2f}s")


if __name__ == "__main__":
    main()
