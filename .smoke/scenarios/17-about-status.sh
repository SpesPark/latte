#!/usr/bin/env bash
# S9.6 (A-1) About status card — verifies the new live status card under
# the hero card (State / Mode / Reason / Power rows) renders correctly
# under three configurations:
#
#   17a-about-asleep.png            : isAwake=false → State=Asleep, Mode hidden, Power hidden
#   17b-about-awake-fullsleep.png   : isAwake=true, allowDisplaySleep=false → Mode="System + display awake"
#   17c-about-awake-displaysleep.png: isAwake=true, allowDisplaySleep=true  → Mode="System awake (display may sleep)"
#
# Power row is hidden by design when requireACForAwake=false; that is the
# intentional clutter-avoidance covered in `AssertionStatusFormatter.powerLabel`
# returning nil, so all three captures here have requireACForAwake=false.
# A separate run in scenario 16 covers the requireACForAwake=true path.
#
# This is a visual capture suite — owner reviews the PNGs to confirm layout.

set -euo pipefail
source "$HARNESS_LIB/log.sh"

capture_about () {
  local name="$1"
  bash "$HARNESS_LIB/launch_app.sh" "$SMOKE_APP_PATH" "$SMOKE_BUNDLE_ID" 20 >/dev/null
  # Variant B/C rely on App trigger evaluation; give bootTriggers + first
  # evaluate pass enough headroom (4s observed sufficient in scenario 15).
  sleep 4
  bash "$HARNESS_LIB/open_settings.sh" latte about >/dev/null
  sleep 3
  bash "$HARNESS_LIB/capture_window.sh" "$SMOKE_SCREENSHOTS_DIR/$name" "Latte" "Latte Settings"
  bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
  sleep 1
}

# Variant A: asleep.
bash "$HARNESS_LIB/reset_prefs.sh" "$SMOKE_BUNDLE_ID" >/dev/null
defaults write "$SMOKE_BUNDLE_ID" latte.firstRunCompleted -bool true
defaults write "$SMOKE_BUNDLE_ID" latte.allowDisplaySleep -bool false
defaults write "$SMOKE_BUNDLE_ID" latte.requireACForAwake -bool false
capture_about 17a-about-asleep.png

# Variant B: awake via App trigger watching Finder (always running), display
# does NOT sleep. App trigger fires shortly after AppEnvironment.bootTriggers,
# so the Status card captures with State=Awake / Reason="App: Finder" /
# Mode="System + display awake".
finder_json='["com.apple.finder"]'
finder_hex="$(printf '%s' "$finder_json" | xxd -p | tr -d '\n')"

bash "$HARNESS_LIB/reset_prefs.sh" "$SMOKE_BUNDLE_ID" >/dev/null
defaults write "$SMOKE_BUNDLE_ID" latte.firstRunCompleted -bool true
defaults write "$SMOKE_BUNDLE_ID" latte.appTrigger.enabled -bool true
defaults write "$SMOKE_BUNDLE_ID" latte.appTrigger.bundleIDs -data "$finder_hex"
defaults write "$SMOKE_BUNDLE_ID" latte.allowDisplaySleep -bool false
defaults write "$SMOKE_BUNDLE_ID" latte.requireACForAwake -bool false
capture_about 17b-about-awake-fullsleep.png

# Variant C: awake via App trigger, display CAN sleep — Mode flips to
# "System awake (display may sleep)".
bash "$HARNESS_LIB/reset_prefs.sh" "$SMOKE_BUNDLE_ID" >/dev/null
defaults write "$SMOKE_BUNDLE_ID" latte.firstRunCompleted -bool true
defaults write "$SMOKE_BUNDLE_ID" latte.appTrigger.enabled -bool true
defaults write "$SMOKE_BUNDLE_ID" latte.appTrigger.bundleIDs -data "$finder_hex"
defaults write "$SMOKE_BUNDLE_ID" latte.allowDisplaySleep -bool true
defaults write "$SMOKE_BUNDLE_ID" latte.requireACForAwake -bool false
capture_about 17c-about-awake-displaysleep.png

smoke_record "$SMOKE_REPORT" 17-about-status "passed" "About status card captured in 3 variants (asleep / awake-fullsleep / awake-displaysleep)"
smoke_ok "About status card variants captured"
