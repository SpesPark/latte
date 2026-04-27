#!/usr/bin/env bash
# Marketing Shot 2 — Settings → General with Coffee tone preview.
# Auto-opens Settings on the General tab via the latte:// URL scheme,
# captures the full screen for owner review.

set -euo pipefail
source "$HARNESS_LIB/log.sh"
bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
sleep 1
defaults delete "$SMOKE_BUNDLE_ID" 2>/dev/null || true

# Demo defaults — match docs/store/screenshot-guide.md.
defaults write "$SMOKE_BUNDLE_ID" latte.firstRunCompleted -bool true
defaults write "$SMOKE_BUNDLE_ID" latte.menuBarIconStyle -string filled
defaults write "$SMOKE_BUNDLE_ID" latte.coffeeAccent -string caramel

bash "$HARNESS_LIB/launch_app.sh" "$SMOKE_APP_PATH" "$SMOKE_BUNDLE_ID" 20 >/dev/null
sleep 2
bash "$HARNESS_LIB/open_settings.sh" latte general >/dev/null
sleep 3

# Window-id capture: works even if always-on-top windows obscure Latte.
bash "$HARNESS_LIB/capture_window.sh" "$SMOKE_SCREENSHOTS_DIR/09-shot-2-general.png" "Latte" "Latte Settings"
smoke_record "$SMOKE_REPORT" 09-marketing-shot-2-general "passed" "Settings opened on General tab via latte:// URL; full-screen capture saved"
smoke_ok "Shot 2 candidate captured"

bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
