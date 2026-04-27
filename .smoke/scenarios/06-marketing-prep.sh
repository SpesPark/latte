#!/usr/bin/env bash
# Marketing screenshot prep — sets Latte into the canonical demo state described
# in docs/store/screenshot-guide.md so the owner only has to click "capture".
#
# What it sets:
#   - firstRunCompleted = true (skip onboarding for shots 1-5)
#   - menuBarIconStyle  = filled
#   - coffeeAccent      = caramel (one of the 5 presets)
#   - calendarTrigger.enabled = true (Calendar permission still needed manually)
#   - appTrigger.enabled = true with two real bundles (Zoom + Slack if installed)
#   - wifiTrigger.enabled = true with empty SSID list (avoids leaking personal SSID)
#   - launchAtLogin     = false (avoid affecting the host machine)
#
# After running this, the owner follows docs/store/screenshot-guide.md to take
# the 5 marketing PNGs. Onboarding step-1 (welcome) is captured automatically.

set -euo pipefail
source "$HARNESS_LIB/log.sh"
bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
sleep 1
defaults delete "$SMOKE_BUNDLE_ID" 2>/dev/null || true

# Capture the first-run onboarding welcome screen as Shot 6.
bash "$HARNESS_LIB/launch_app.sh" "$SMOKE_APP_PATH" "$SMOKE_BUNDLE_ID" 20 >/dev/null
sleep 4
bash "$HARNESS_LIB/capture_screenshot.sh" "$SMOKE_SCREENSHOTS_DIR/06-onboarding-welcome.png"
bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
sleep 1

# Now seed the canonical demo defaults for shots 1-5.
defaults write "$SMOKE_BUNDLE_ID" latte.firstRunCompleted -bool true
defaults write "$SMOKE_BUNDLE_ID" latte.menuBarIconStyle -string filled
defaults write "$SMOKE_BUNDLE_ID" latte.coffeeAccent -string caramel
defaults write "$SMOKE_BUNDLE_ID" latte.calendarTrigger.enabled -bool true
defaults write "$SMOKE_BUNDLE_ID" latte.appTrigger.enabled -bool true
defaults write "$SMOKE_BUNDLE_ID" latte.wifiTrigger.enabled -bool true

# Encode App-trigger bundle list as JSON ([Zoom, Slack]). The Swift side decodes
# via JSONDecoder.[String]. We write Data via the `-data` form (hex bytes).
# Pure-bash to avoid python ABI surprises across host installs.
bundles_json='["us.zoom.xos","com.tinyspeck.slackmacgap"]'
bundles_hex="$(printf '%s' "$bundles_json" | xxd -p | tr -d '\n')"
defaults write "$SMOKE_BUNDLE_ID" latte.appTrigger.bundleIDs -data "$bundles_hex"

bash "$HARNESS_LIB/launch_app.sh" "$SMOKE_APP_PATH" "$SMOKE_BUNDLE_ID" 20 >/dev/null
sleep 3

smoke_record "$SMOKE_REPORT" 06-marketing-prep "passed" "Latte primed for owner manual marketing capture (shots 1-5); onboarding welcome auto-captured as 06-onboarding-welcome.png"
smoke_ok "marketing prep done — owner: follow docs/store/screenshot-guide.md for shots 1-5"
smoke_info "Latte is now running with: caramel accent, filled icon, all 4 triggers wired"
smoke_info "Quit Latte after capture with: pkill -x Latte"
