#!/bin/zsh

set -euo pipefail

preview_root="AppStorePreview/1.3"
raw_root="$preview_root/raw"
intermediate_root="$preview_root/intermediate"
final_root="$preview_root/final"
evidence_root="$preview_root/evidence"
font_regular="/Library/Fonts/SF-Pro-Rounded-Semibold.otf"
font_bold="/Library/Fonts/SF-Pro-Rounded-Bold.otf"
ffmpeg_binary="$(python3 -c 'import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())')"
output="$final_root/Ringbloom-1.3-App-Preview-iPhone-69.mp4"
poster="$final_root/Ringbloom-1.3-App-Preview-Poster.png"

mkdir -p "$intermediate_root" "$final_root" "$evidence_root"

# Simulator recordings use Core Media edit lists that ffmpeg interprets differently from
# AVFoundation. Normalise the Flower Show journey through Apple's passthrough exporter first
# so all later trim times are stable and frame-accurate.
avconvert --source "$raw_root/flower-show-journey-full.mp4" \
    --preset PresetPassthrough \
    --output "$intermediate_root/flower-show-journey-action.mp4" \
    --start 15 \
    --duration 40 \
    --replace > "$evidence_root/avconvert-flower-show-journey.log" 2>&1

# The source simulator recording returns to the iPhone Home Screen after the
# completion card. Keep the final preview inside Ringbloom for App Store Guideline 2.3.4.
filter_graph="
[0:v]fps=30,trim=start=0.5:end=5.2,setpts=PTS-STARTPTS,
scale=886:1920:force_original_aspect_ratio=increase,crop=886:1920,format=yuv420p,
drawbox=x=0:y=0:w=iw:h=150:color=0x0B1C2B:t=fill,
drawbox=x=0:y=147:w=iw:h=3:color=0xF7C653@0.95:t=fill,
drawtext=fontfile='$font_regular':text='FLOWER SHOW':fontcolor=0xF7C653:fontsize=21:x=(w-text_w)/2:y=25,
drawtext=fontfile='$font_bold':text='NEW RULES. EVERY CLASS.':fontcolor=0xFFF4D6:fontsize=38:x=(w-text_w)/2:y=68[s0];
[0:v]fps=30,trim=start=12.7:end=17.7,setpts=PTS-STARTPTS,
scale=886:1920:force_original_aspect_ratio=increase,crop=886:1920,format=yuv420p,
drawbox=x=0:y=0:w=iw:h=150:color=0x0B1C2B:t=fill,
drawbox=x=0:y=147:w=iw:h=3:color=0x50D0AA@0.95:t=fill,
drawtext=fontfile='$font_regular':text='FLOWER SHOW':fontcolor=0x50D0AA:fontsize=21:x=(w-text_w)/2:y=25,
drawtext=fontfile='$font_bold':text='CLEAR THE BINDWEED':fontcolor=0xFFF4D6:fontsize=40:x=(w-text_w)/2:y=67[s1];
[0:v]fps=30,trim=start=19.8:end=24.3,setpts=PTS-STARTPTS,
scale=886:1920:force_original_aspect_ratio=increase,crop=886:1920,format=yuv420p,
drawbox=x=0:y=0:w=iw:h=150:color=0x0B1C2B:t=fill,
drawbox=x=0:y=147:w=iw:h=3:color=0x50D0AA@0.95:t=fill,
drawtext=fontfile='$font_regular':text='FLOWER SHOW':fontcolor=0x50D0AA:fontsize=21:x=(w-text_w)/2:y=25,
drawtext=fontfile='$font_bold':text='CHAIN BLOOMS TO WIN':fontcolor=0xFFF4D6:fontsize=40:x=(w-text_w)/2:y=67[s2];
[0:v]fps=30,trim=start=28.7:end=36.5,setpts=PTS-STARTPTS,
scale=886:1920:force_original_aspect_ratio=increase,crop=886:1920,format=yuv420p,
drawbox=x=0:y=0:w=iw:h=150:color=0x0B1C2B:t=fill,
drawbox=x=0:y=147:w=iw:h=3:color=0xF7C653@0.95:t=fill,
drawtext=fontfile='$font_regular':text='FLOWER SHOW':fontcolor=0xF7C653:fontsize=21:x=(w-text_w)/2:y=25,
drawtext=fontfile='$font_bold':text='COMPLETE THE CLASS. EARN YOUR RATING.':fontcolor=0xFFF4D6:fontsize=31:x=(w-text_w)/2:y=72,
drawbox=x=0:y=h-106:w=iw:h=106:color=0x0B1C2B@0.94:t=fill,
drawtext=fontfile='$font_bold':text='CLASSES 1-5 FREE':fontcolor=0x50D0AA:fontsize=22:x=(w-text_w)/2:y=h-84,
drawtext=fontfile='$font_regular':text='FULL SHOW REQUIRES A ONE-TIME PURCHASE':fontcolor=0xFFF4D6:fontsize=22:x=(w-text_w)/2:y=h-49[s3];
[s0][s1][s2][s3]concat=n=4:v=1:a=0,
trim=end=16.6,setpts=PTS-STARTPTS,
fade=t=out:st=16.2:d=0.4:color=0x0B1C2B,
format=yuv420p[outv]
"

"$ffmpeg_binary" -hide_banner -y \
    -i "$intermediate_root/flower-show-journey-action.mp4" \
    -f lavfi \
    -i "anullsrc=channel_layout=stereo:sample_rate=48000" \
    -filter_complex "$filter_graph" \
    -map "[outv]" \
    -map "1:a:0" \
    -c:v libx264 \
    -profile:v high \
    -level:v 4.0 \
    -pix_fmt yuv420p \
    -r 30 \
    -b:v 11M \
    -minrate 11M \
    -maxrate 11M \
    -bufsize 22M \
    -x264-params "nal-hrd=cbr:force-cfr=1" \
    -c:a aac \
    -b:a 256k \
    -ar 48000 \
    -ac 2 \
    -shortest \
    -movflags +faststart \
    "$output" \
    2> "$evidence_root/encode.log"

"$ffmpeg_binary" -hide_banner -y \
    -ss 4.0 \
    -i "$output" \
    -frames:v 1 \
    "$poster" \
    2> "$evidence_root/poster.log"

shasum -a 256 "$output" "$poster" > "$evidence_root/sha256.txt"
avmediainfo "$output" > "$evidence_root/avmediainfo.txt"

print "Built $output"
print "Built $poster"
