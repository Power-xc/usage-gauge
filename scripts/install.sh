#!/usr/bin/env bash
# Installs UsageGauge into ~/Applications and starts it at login.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v codexbar >/dev/null 2>&1; then
  echo "codexbar CLI not found. Install it first: brew install --cask codexbar" >&2
  exit 1
fi

scripts/build-app.sh
label="io.github.power-xc.usage-gauge"
target="$HOME/Applications/UsageGauge.app"
agent="$HOME/Library/LaunchAgents/$label.plist"

pkill -x UsageGauge 2>/dev/null || true
mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents"
rm -rf "$target"
cp -R dist/UsageGauge.app "$target"

cat > "$agent" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key><array><string>/usr/bin/open</string><string>-a</string><string>$target</string></array>
  <key>RunAtLoad</key><true/>
</dict></plist>
PLIST

open "$target"
echo "installed $target (starts at login)"
