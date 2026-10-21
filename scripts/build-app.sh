#!/usr/bin/env bash
# Builds a release binary and wraps it in dist/UsageGauge.app (ad-hoc signed).
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product usage-gauge
app="dist/UsageGauge.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/usage-gauge" "$app/Contents/MacOS/UsageGauge"
cp Resources/Info.plist "$app/Contents/Info.plist"
codesign --force --sign - "$app"
echo "built $app"
