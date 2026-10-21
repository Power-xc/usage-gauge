#!/usr/bin/env bash
# Installs UsageGauge into ~/Applications; the app registers itself as a login item on first launch.
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
mkdir -p "$HOME/Applications"
rm -rf "$target"
cp -R dist/UsageGauge.app "$target"

# Legacy LaunchAgent from older installs: drop it so the gauge does not start twice at login.
launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
rm -f "$agent"

open "$target"
echo "installed $target (starts at login; toggle it in the app menu)"
