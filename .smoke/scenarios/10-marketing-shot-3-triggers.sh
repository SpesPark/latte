#!/usr/bin/env bash
# Marketing Shot 3 — Settings → Triggers with all 4 trigger sections visible.
# Pre-enables Calendar + App + WiFi triggers, opens Settings on Triggers tab,
# captures full screen.

set -euo pipefail
source "$HARNESS_LIB/log.sh"
bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
sleep 1
defaults delete "$SMOKE_BUNDLE_ID" 2>/dev/null || true

defaults write "$SMOKE_BUNDLE_ID" latte.firstRunCompleted -bool true
defaults write "$SMOKE_BUNDLE_ID" latte.menuBarIconStyle -string filled
defaults write "$SMOKE_BUNDLE_ID" latte.coffeeAccent -string caramel
defaults write "$SMOKE_BUNDLE_ID" latte.calendarTrigger.enabled -bool true
defaults write "$SMOKE_BUNDLE_ID" latte.appTrigger.enabled -bool true
defaults write "$SMOKE_BUNDLE_ID" latte.wifiTrigger.enabled -bool true

# Seed App trigger with realistic bundle list (Zoom + Slack).
bundles_json='["us.zoom.xos","com.tinyspeck.slackmacgap"]'
bundles_hex="$(printf '%s' "$bundles_json" | xxd -p | tr -d '\n')"
defaults write "$SMOKE_BUNDLE_ID" latte.appTrigger.bundleIDs -data "$bundles_hex"

bash "$HARNESS_LIB/launch_app.sh" "$SMOKE_APP_PATH" "$SMOKE_BUNDLE_ID" 20 >/dev/null
sleep 2
bash "$HARNESS_LIB/open_settings.sh" latte triggers >/dev/null
sleep 3
bash "$HARNESS_LIB/capture_window.sh" "$SMOKE_SCREENSHOTS_DIR/10-shot-3-triggers.png" "Latte" "Latte Settings"
smoke_record "$SMOKE_REPORT" 10-marketing-shot-3-triggers "passed" "Settings opened on Triggers tab with 3/4 triggers enabled and Zoom+Slack pre-seeded; full-screen capture saved"
smoke_ok "Shot 3 candidate captured"

bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
