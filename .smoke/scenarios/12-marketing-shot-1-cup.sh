#!/usr/bin/env bash
# Marketing Shot 1 — coffee cup mid-fill demo capture.
# Uses the latte://demo/cup?fill=0.55&accent=caramel URL to open a dedicated
# demo window with a deterministic cup state, then captures the window via
# screencapture -l <wid> (works regardless of always-on-top).

set -euo pipefail
source "$HARNESS_LIB/log.sh"
bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
sleep 1
defaults delete "$SMOKE_BUNDLE_ID" 2>/dev/null || true
defaults write "$SMOKE_BUNDLE_ID" latte.firstRunCompleted -bool true
defaults write "$SMOKE_BUNDLE_ID" latte.coffeeAccent -string caramel

bash "$HARNESS_LIB/launch_app.sh" "$SMOKE_APP_PATH" "$SMOKE_BUNDLE_ID" 20 >/dev/null
sleep 2
open -a "$SMOKE_APP_PATH" "latte://demo/cup?fill=0.55&accent=caramel&awake=true"
smoke_ok "demo cup URL sent"
sleep 4

bash "$HARNESS_LIB/capture_window.sh" "$SMOKE_SCREENSHOTS_DIR/12-shot-1-cup-mid-fill.png" "Latte" "Latte Demo Cup"
smoke_record "$SMOKE_REPORT" 12-marketing-shot-1-cup "passed" "Demo cup window opened at fill=0.55 caramel awake=true; window-id capture saved"

bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
