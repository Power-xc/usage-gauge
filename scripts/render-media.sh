#!/usr/bin/env bash
# Renders the README media from the real SwiftUI views: stills into docs/ and the demo loop into
# docs/demo.gif (needs ffmpeg). Frames are drawn at 2x.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v ffmpeg >/dev/null || { echo "ffmpeg is required: brew install ffmpeg" >&2; exit 1; }
frames="$(mktemp -d)"
trap 'rm -rf "$frames"' EXIT

swift build -c release --product PromoRenderer
renderer="$(swift build -c release --show-bin-path)/PromoRenderer"
"$renderer" stills docs
"$renderer" readme "$frames"
# 12.5 fps is exactly 8 centiseconds a frame, the GIF's native step. The frames go through a
# lossless video first: paletteuse drops frames when it reads the image sequence directly, so the
# loop would play at the wrong speed. The 2x frames are scaled down to 1280 px wide (1.6x the
# README's 800 px), with one 96-colour palette for the whole loop to keep colours steady and no
# dithering to keep flat areas clean; that keeps the loop under GitHub's 5 MB image proxy limit.
ffmpeg -loglevel error -y -framerate 12.5 -i "$frames/frame-%04d.png" -c:v ffv1 "$frames/loop.mkv"
ffmpeg -loglevel error -y -i "$frames/loop.mkv" \
  -vf "scale=1280:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=96:stats_mode=full[p];[b][p]paletteuse=dither=none:diff_mode=rectangle" \
  -loop 0 docs/demo.gif
echo "rendered docs/*.jpg and docs/demo.gif"
