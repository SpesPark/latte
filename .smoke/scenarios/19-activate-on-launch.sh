#!/usr/bin/env bash
# S10 — Activate at launch (SettingsKey.activateOnLaunch + AwakeReason.launch)
# verifies AppEnvironment.applyActivateOnLaunchIfEnabled fires from
# LatteAppDelegate.applicationDidFinishLaunching when the flag is ON
# and onboarding is complete.
#
# Two phases:
#   ON  — flag set + onboarding done → indefinite assertion held within ~10s
#   OFF — flag cleared → no assertion held even after 5s
#
# No triggers are seeded so any assertion observed is necessarily from the
# launch path (not a coincidental trigger fire).

set -euo pipefail
source "$HARNESS_LIB/log.sh"

# --- Phase 1: flag ON should hold an indefinite assertion at launch ---
bash "$HARNESS_LIB/reset_prefs.sh" "$SMOKE_BUNDLE_ID" >/dev/null
defaults write "$SMOKE_BUNDLE_ID" latte.firstRunCompleted -bool true
defaults write "$SMOKE_BUNDLE_ID" latte.activateOnLaunch -bool true

bash "$HARNESS_LIB/launch_app.sh" "$SMOKE_APP_PATH" "$SMOKE_BUNDLE_ID" 20 >/dev/null

held=0
# Capture-then-test (see 15-pause-all.sh for the SIGPIPE-pipefail rationale).
for i in 1 2 3 4 5 6 7 8; do
  matched="$(pmset -g assertions 2>/dev/null | grep -E "pid [0-9]+\(Latte\):" | head -1 || true)"
  if [[ -n "$matched" ]]; then
    held=1; break
  fi
  sleep 1
done

if (( held == 0 )); then
  smoke_error "activate-on-launch: flag ON did not produce an assertion within ~10s"
  bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
  exit 1
fi
smoke_ok "activate-on-launch: flag ON held assertion"

# Capture Settings → General to surface the new toggle for owner review.
bash "$HARNESS_LIB/open_settings.sh" latte general >/dev/null
sleep 3
bash "$HARNESS_LIB/capture_window.sh" "$SMOKE_SCREENSHOTS_DIR/19-activate-on-launch.png" "Latte" "Latte Settings"
bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
sleep 1

# --- Phase 2: flag OFF must NOT hold an assertion ---
bash "$HARNESS_LIB/reset_prefs.sh" "$SMOKE_BUNDLE_ID" >/dev/null
defaults write "$SMOKE_BUNDLE_ID" latte.firstRunCompleted -bool true
defaults write "$SMOKE_BUNDLE_ID" latte.activateOnLaunch -bool false

bash "$HARNESS_LIB/launch_app.sh" "$SMOKE_APP_PATH" "$SMOKE_BUNDLE_ID" 20 >/dev/null
sleep 5

still_held="$(pmset -g assertions 2>/dev/null | grep -E "pid [0-9]+\(Latte\):" | head -1 || true)"
if [[ -n "$still_held" ]]; then
  smoke_error "activate-on-launch: flag OFF unexpectedly produced an assertion ($still_held)"
  bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
  exit 1
fi
bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
smoke_ok "activate-on-launch: flag OFF correctly produced no assertion"

# --- Phase 3: flag ON but onboarding INCOMPLETE → no assertion (gating). ---
# The onboarding gate prevents fresh installs from auto-awaking before the
# user finishes the wizard. firstRunCompleted=false simulates a brand-new
# install where someone has tried to set the flag externally.
bash "$HARNESS_LIB/reset_prefs.sh" "$SMOKE_BUNDLE_ID" >/dev/null
defaults write "$SMOKE_BUNDLE_ID" latte.firstRunCompleted -bool false
defaults write "$SMOKE_BUNDLE_ID" latte.activateOnLaunch -bool true

bash "$HARNESS_LIB/launch_app.sh" "$SMOKE_APP_PATH" "$SMOKE_BUNDLE_ID" 20 >/dev/null
sleep 5

onboard_held="$(pmset -g assertions 2>/dev/null | grep -E "pid [0-9]+\(Latte\):" | head -1 || true)"
if [[ -n "$onboard_held" ]]; then
  smoke_error "activate-on-launch: onboarding-incomplete gate failed to suppress activation ($onboard_held)"
  bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
  exit 1
fi
bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
smoke_ok "activate-on-launch: onboarding-incomplete gate correctly suppressed activation"

smoke_record "$SMOKE_REPORT" 19-activate-on-launch "passed" "Activate at launch: ON / OFF / onboarding-incomplete gate all correct"
smoke_ok "scenario 19-activate-on-launch PASSED"
