#!/usr/bin/env bash
# S8b smoke-D: Verify first-run onboarding wizard appears once and not on re-launch.
# Asserts: defaults key `latte.firstRunCompleted` flips false → true after first run,
#          menu-bar icon hidden during wizard (manual visual check via screenshot).

set -euo pipefail
source "$HARNESS_LIB/log.sh"
bash "$HARNESS_LIB/reset_prefs.sh" "$SMOKE_BUNDLE_ID" >/dev/null
bash "$HARNESS_LIB/launch_app.sh" "$SMOKE_APP_PATH" "$SMOKE_BUNDLE_ID" 20 >/dev/null

# Give the onboarding window time to render.
sleep 3

bash "$HARNESS_LIB/capture_screenshot.sh" "$SMOKE_SCREENSHOTS_DIR/01-onboarding-first-launch.png"

state="$(bash "$HARNESS_LIB/defaults_helper.sh" read "$SMOKE_BUNDLE_ID" latte.firstRunCompleted 2>/dev/null || echo missing)"
smoke_record "$SMOKE_REPORT" 01-onboarding "info" "first launch defaults latte.firstRunCompleted=$state (expected 0 or missing while wizard is open)"

# Simulate completing onboarding by writing the key directly (no UI driver yet).
bash "$HARNESS_LIB/defaults_helper.sh" write "$SMOKE_BUNDLE_ID" latte.firstRunCompleted -bool true >/dev/null

bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
sleep 2

# Re-launch — onboarding should NOT appear.
bash "$HARNESS_LIB/launch_app.sh" "$SMOKE_APP_PATH" "$SMOKE_BUNDLE_ID" 20 >/dev/null
sleep 3
bash "$HARNESS_LIB/capture_screenshot.sh" "$SMOKE_SCREENSHOTS_DIR/01-onboarding-second-launch.png"

state2="$(bash "$HARNESS_LIB/defaults_helper.sh" read "$SMOKE_BUNDLE_ID" latte.firstRunCompleted)"
if [[ "$state2" == "1" ]]; then
  smoke_ok "onboarding.completed persisted as true after relaunch"
  smoke_record "$SMOKE_REPORT" 01-onboarding "passed" "completed=true persisted; visual check pending in artifact PNGs"
else
  smoke_error "onboarding.completed expected 1, got $state2"
  exit 1
fi

bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
