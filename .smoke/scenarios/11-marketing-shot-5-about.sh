#!/usr/bin/env bash
# Marketing Shot 5 — Settings → About tab.
# Most deterministic of the marketing shots; About tab has no app-specific
# state to seed beyond firstRunCompleted.

set -euo pipefail
source "$HARNESS_LIB/log.sh"
bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
sleep 1
defaults delete "$SMOKE_BUNDLE_ID" 2>/dev/null || true
defaults write "$SMOKE_BUNDLE_ID" latte.firstRunCompleted -bool true

bash "$HARNESS_LIB/launch_app.sh" "$SMOKE_APP_PATH" "$SMOKE_BUNDLE_ID" 20 >/dev/null
sleep 2
bash "$HARNESS_LIB/open_settings.sh" latte about >/dev/null
sleep 2
osascript -e "tell application id \"$SMOKE_BUNDLE_ID\" to activate" 2>/dev/null || true
sleep 2

bash "$HARNESS_LIB/capture_screenshot.sh" "$SMOKE_SCREENSHOTS_DIR/11-shot-5-about.png"
smoke_record "$SMOKE_REPORT" 11-marketing-shot-5-about "passed" "Settings opened on About tab via latte:// URL; full-screen capture saved"
smoke_ok "Shot 5 candidate captured"

bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
