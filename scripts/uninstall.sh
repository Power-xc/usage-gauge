#!/usr/bin/env bash
# Removes the app, its login item and its preferences.
set -euo pipefail
label="io.github.power-xc.usage-gauge"
pkill -x UsageGauge 2>/dev/null || true
rm -rf "$HOME/Applications/UsageGauge.app"
rm -f "$HOME/Library/LaunchAgents/$label.plist"
defaults delete "$label" 2>/dev/null || true
echo "removed UsageGauge"
