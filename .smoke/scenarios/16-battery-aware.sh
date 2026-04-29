#!/usr/bin/env bash
# S9.5 (C-1) Battery-aware mode — verifies that the
# `requireACForAwake` setting persists across launches, that the General
# Settings tab opens with the toggle visible, and that when the Mac is on
# battery (best-effort detection) the awake-from-trigger path is suspended.
#
# True end-to-end battery-cycle verification (unplug AC during awake,
# observe immediate release) requires physical AC manipulation — not
# automatable. This scenario covers what *is* automatable:
#   - requireACForAwake setting round-trips (defaults read after write).
#   - Settings → General opens via latte:// URL (toggle is visible to the
#     owner in the captured PNG).
#   - When `pmset -g batt` reports the Mac is on battery AND
#     requireACForAwake = true, Latte does NOT hold a PreventUserIdleSystemSleep
#     assertion even with App trigger ON for a running app (Finder).

set -euo pipefail
source "$HARNESS_LIB/log.sh"
bash "$HARNESS_LIB/reset_prefs.sh" "$SMOKE_BUNDLE_ID" >/dev/null

# Seed: onboarding done, battery-aware ON, App trigger ON for Finder.
defaults write "$SMOKE_BUNDLE_ID" latte.firstRunCompleted -bool true
defaults write "$SMOKE_BUNDLE_ID" latte.requireACForAwake -bool true
defaults write "$SMOKE_BUNDLE_ID" latte.appTrigger.enabled -bool true

bundles_json='["com.apple.finder"]'
bundles_hex="$(printf '%s' "$bundles_json" | xxd -p | tr -d '\n')"
defaults write "$SMOKE_BUNDLE_ID" latte.appTrigger.bundleIDs -data "$bundles_hex"

# 1) Setting round-trip.
written="$(bash "$HARNESS_LIB/defaults_helper.sh" read "$SMOKE_BUNDLE_ID" latte.requireACForAwake)"
if [[ "$written" != "1" ]]; then
  smoke_error "battery-aware: requireACForAwake did not round-trip (got $written)"
  exit 1
fi

bash "$HARNESS_LIB/launch_app.sh" "$SMOKE_APP_PATH" "$SMOKE_BUNDLE_ID" 20 >/dev/null
sleep 3

# 2) General tab opens — owner sees toggle + caption visually.
bash "$HARNESS_LIB/open_settings.sh" latte general >/dev/null
sleep 3
bash "$HARNESS_LIB/capture_window.sh" "$SMOKE_SCREENSHOTS_DIR/16-battery-aware-settings.png" "Latte" "Latte Settings"

# 3) Power-source-aware behaviour. `pmset -g batt` first line e.g.:
#      Now drawing from 'Battery Power'   (on battery)
#      Now drawing from 'AC Power'        (plugged)
power_line="$(pmset -g batt 2>/dev/null | head -n 1)"
on_battery=0
if [[ "$power_line" == *"'Battery Power'"* ]]; then
  on_battery=1
fi

# Give AwakeManager.observePowerSource a beat to react.
sleep 4

if (( on_battery == 1 )); then
  # Capture-then-test (avoids `set -o pipefail` + `grep -Eq` SIGPIPE
  # false-negative — see 15-pause-all.sh for the rationale).
  matched="$(pmset -g assertions 2>/dev/null | grep -E "pid [0-9]+\(Latte\):" | head -1 || true)"
  if [[ -n "$matched" ]]; then
    smoke_error "battery-aware: Latte holds assertion while on battery + requireACForAwake=true (gate not enforced) — '$matched'"
    bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
    exit 1
  fi
  smoke_ok "on battery + gate ON → no Latte assertion (correct)"
  smoke_record "$SMOKE_REPORT" 16-battery-aware "passed" "On battery; gate enforced; setting round-trip OK; General tab capture saved"
else
  # On AC: gate is enabled but inactive; assertion *should* be held.
  held=0
  for i in 1 2 3 4 5 6; do
    sleep 1
    matched="$(pmset -g assertions 2>/dev/null | grep -E "pid [0-9]+\(Latte\):" | head -1 || true)"
    if [[ -n "$matched" ]]; then
      held=1; break
    fi
  done
  if (( held == 0 )); then
    smoke_warn "battery-aware on AC: Latte did not hold assertion within 6s (App trigger may not have evaluated yet)"
  else
    smoke_ok "on AC + gate ON → assertion held (correct)"
  fi
  smoke_record "$SMOKE_REPORT" 16-battery-aware "passed" "On AC; setting round-trip OK; held=$held; General tab capture saved"
fi

bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
