#!/usr/bin/env bash
# Renders the 9:16 Instagram reel from the real SwiftUI views into media/usage-gauge-reel.mp4, plus
# its cover as media/usage-gauge-reel-cover.jpg (needs ffmpeg). Frames are drawn at 2x and scaled
# down with lanczos, so fine lines stay clean at 1080 x 1920.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v ffmpeg >/dev/null || { echo "ffmpeg is required: brew install ffmpeg" >&2; exit 1; }
frames="$(mktemp -d)"
trap 'rm -rf "$frames"' EXIT
mkdir -p media

swift build -c release --product PromoRenderer
renderer="$(swift build -c release --show-bin-path)/PromoRenderer"
"$renderer" reel "$frames"
"$renderer" cover media/usage-gauge-reel-cover.jpg

# What Instagram asks for: H.264 High, 4:2:0, BT.709, constant 30 fps, a closed GOP of half a
# second with two B-frames, and the index first (faststart). Near-lossless CRF, capped well under
# the 25 Mbps upload limit, so Instagram's own re-encode starts from a clean picture.
ffmpeg -loglevel error -y -framerate 30 -i "$frames/frame-%04d.png" \
  -vf "scale=1080:1920:flags=lanczos+accurate_rnd+full_chroma_int:out_color_matrix=bt709:out_range=tv,format=yuv420p,setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709:range=tv" \
  -c:v libx264 -profile:v high -preset slow -crf 12 -maxrate 20M -bufsize 40M \
  -g 15 -keyint_min 15 -sc_threshold 0 -bf 2 -r 30 \
  -colorspace bt709 -color_primaries bt709 -color_trc bt709 -color_range tv \
  -movflags +faststart media/usage-gauge-reel.mp4
echo "rendered media/usage-gauge-reel.mp4 and media/usage-gauge-reel-cover.jpg"
