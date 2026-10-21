#!/usr/bin/env bash
# Renders the README media from the real SwiftUI views: stills into docs/ and the demo loop into
# docs/demo.gif (needs ffmpeg). Frames are drawn at 2x and kept full size for retina screens.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v ffmpeg >/dev/null || { echo "ffmpeg is required: brew install ffmpeg" >&2; exit 1; }
frames="$(mktemp -d)"
trap 'rm -rf "$frames"' EXIT

swift build -c release --product PromoRenderer
renderer="$(swift build -c release --show-bin-path)/PromoRenderer"
"$renderer" stills docs
"$renderer" readme "$frames"
# One palette for the whole loop keeps colours steady; rectangle diffs keep the file small.
ffmpeg -loglevel error -y -framerate 20 -i "$frames/frame-%04d.png" \
  -vf "split[a][b];[a]palettegen=max_colors=256:stats_mode=full[p];[b][p]paletteuse=dither=sierra2_4a:diff_mode=rectangle" \
  -loop 0 docs/demo.gif
echo "rendered docs/*.jpg and docs/demo.gif"
