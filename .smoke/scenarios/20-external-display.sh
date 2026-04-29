#!/usr/bin/env bash
# S11 / V2-06 — External Display trigger basic functional check.
#
# CI hosts have no external monitor, so the natural "no assertion" branch
# is what we verify here:
#   - With externalDisplayEnabled=true and (necessarily) zero external
#     displays attached, the trigger must NOT cause Latte to hold an
#     awake assertion.
#   - Settings → Triggers visual capture confirms the new section
#     renders (owner reviews capture for label / status copy).
#
# Physical attach/detach can't be scripted in a CI box without external
# fixtures, so the "vote ON when monitor attached" path is verified at
# the unit-test level (ExternalDisplayTriggerTests) and during owner
# manual smoke (handoff step 7).

set -euo pipefail
source "$HARNESS_LIB/log.sh"

bash "$HARNESS_LIB/reset_prefs.sh" "$SMOKE_BUNDLE_ID" >/dev/null

# Seed: onboarding done, External-Display trigger enabled, NO other trigger
# armed (so any assertion that did appear would have to come from the
# display trigger).
defaults write "$SMOKE_BUNDLE_ID" latte.firstRunCompleted -bool true
defaults write "$SMOKE_BUNDLE_ID" latte.externalDisplayTrigger.enabled -bool true

bash "$HARNESS_LIB/launch_app.sh" "$SMOKE_APP_PATH" "$SMOKE_BUNDLE_ID" 20 >/dev/null
sleep 4  # AppEnvironment.bootTriggers + first evaluate pass

# Phase 1: with no external monitor (the smoke runner host has none), the
# trigger must vote OFF and Latte must NOT hold an assertion. Same pmset
# match technique as 15-pause-all.sh — match by owning-pid line.
if pmset -g assertions 2>/dev/null | grep -Eq "pid [0-9]+\(Latte\):"; then
  smoke_error "external-display: Latte holds an assertion despite no external display attached"
  bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
  exit 1
fi
smoke_ok "external-display: zero attached → no Latte assertion (correct)"

# Phase 2: capture Settings → Triggers so owner can review the new
# "External Display" section + status row copy. Schedule (4th trigger)
# previously sat below the default fold; ExternalDisplay is the 5th.
# resizable Settings (S10) gives owner room to scroll for visual review.
bash "$HARNESS_LIB/open_settings.sh" latte triggers >/dev/null
sleep 3
bash "$HARNESS_LIB/capture_window.sh" \
  "$SMOKE_SCREENSHOTS_DIR/20-external-display.png" \
  "Latte" "Latte Settings"

bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null

smoke_record "$SMOKE_REPORT" 20-external-display "passed" "External Display trigger: zero attached → no assertion; Settings capture shipped"
smoke_ok "scenario 20-external-display PASSED"
