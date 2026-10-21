#!/usr/bin/env bash
# Builds a release binary and wraps it in dist/UsageGauge.app (ad-hoc signed). UNIVERSAL=1 builds
# Apple silicon and Intel binaries separately and joins them, so one download runs on both.
set -euo pipefail
cd "$(dirname "$0")/.."

app="dist/UsageGauge.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
binary="$app/Contents/MacOS/UsageGauge"

if [[ "${UNIVERSAL:-0}" == 1 ]]; then
  slices=()
  for arch in arm64 x86_64; do
    triple="$arch-apple-macosx14.0"
    swift build -c release --product usage-gauge --triple "$triple"
    slices+=("$(swift build -c release --triple "$triple" --show-bin-path)/usage-gauge")
  done
  lipo -create -output "$binary" "${slices[@]}"
else
  swift build -c release --product usage-gauge
  cp "$(swift build -c release --show-bin-path)/usage-gauge" "$binary"
fi

cp Resources/Info.plist "$app/Contents/Info.plist"
codesign --force --sign - "$app"
echo "built $app"
