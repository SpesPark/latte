#!/usr/bin/env bash
# S9 (V2-05) Schedule trigger — verifies the trigger runtime side of the
# new feature (an entry covering "now" produces a vote and Latte holds the
# assertion) and captures the Triggers tab in two states for visual review:
#
#   18a-schedule-now.png       : single entry covering current minute → form expanded
#   18b-schedule-cross-night.png: cross-midnight entry → "Crosses midnight" caption
#
# Runtime check uses pmset to confirm the assertion fires; this is the
# regression-relevant signal. Visual captures are owner-reviewable for layout.

set -euo pipefail
source "$HARNESS_LIB/log.sh"

# Feature-presence guard (S28). Asserts ScheduleTrigger is compiled into the
# Release binary; without this, the runtime "now-entry holds assertion"
# branch would fail with an unclear error rather than an actionable
# stale-binary diagnostic (S27 stale-binary discovery).
bash "$HARNESS_LIB/assert_binary_type.sh" \
  "$SMOKE_APP_PATH/Contents/MacOS/Latte" \
  '\bLatte\.ScheduleTrigger\b' \
  "18-schedule" >/dev/null

# --- helpers ---
write_entries () {
  # Write a JSON array of ScheduleEntry to defaults as raw -data.
  local json="$1"
  local hex
  hex="$(printf '%s' "$json" | xxd -p | tr -d '\n')"
  defaults write "$SMOKE_BUNDLE_ID" latte.scheduleTrigger.entries -data "$hex"
}

now_weekday_int () {
  # Calendar.weekday: Sunday=1 .. Saturday=7.
  # `date +%u`: Mon=1 .. Sun=7. Convert.
  local u
  u="$(date +%u)"
  if [[ "$u" == "7" ]]; then echo 1; else echo $((u + 1)); fi
}

# --- Variant A: entry that covers right now ---
bash "$HARNESS_LIB/reset_prefs.sh" "$SMOKE_BUNDLE_ID" >/dev/null
defaults write "$SMOKE_BUNDLE_ID" latte.firstRunCompleted -bool true
defaults write "$SMOKE_BUNDLE_ID" latte.scheduleTrigger.enabled -bool true

now_h="$(date +%-H)"
end_h="$((now_h + 1))"
if (( end_h > 23 )); then end_h=23; fi
weekday="$(now_weekday_int)"
uuid_a="$(uuidgen)"
entries_a="[{\"id\":\"$uuid_a\",\"weekdays\":[$weekday],\"start\":{\"hour\":$now_h,\"minute\":0},\"end\":{\"hour\":$end_h,\"minute\":59},\"label\":\"smoke-now\",\"isEnabled\":true}]"
write_entries "$entries_a"

bash "$HARNESS_LIB/launch_app.sh" "$SMOKE_APP_PATH" "$SMOKE_BUNDLE_ID" 20 >/dev/null
# ScheduleTrigger.start runs an immediate evaluate, so the assertion should
# land within seconds.
sleep 5

held=0
# Capture-then-test (see 15-pause-all.sh for the SIGPIPE-pipefail rationale).
for i in 1 2 3 4 5 6; do
  matched="$(pmset -g assertions 2>/dev/null | grep -E "pid [0-9]+\(Latte\):" | head -1 || true)"
  if [[ -n "$matched" ]]; then
    held=1; break
  fi
  sleep 1
done

if (( held == 0 )); then
  smoke_error "schedule: entry covering 'now' did not produce an assertion within ~10s"
  bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
  exit 1
fi
smoke_ok "schedule: 'now' entry held assertion"

bash "$HARNESS_LIB/open_settings.sh" latte triggers >/dev/null
sleep 3
# NOTE: Settings window is now resizable (commit 66e8628), but driving
# AppleScript-based window resize from the harness still requires
# Accessibility permission for the smoke runner — currently not granted.
# So 18a/18b open at the default 460×360 size and the Schedule row (4th
# trigger) sits below the fold; SwiftUI's Form auto-scrolls so it's
# manually reachable. The runtime check above (assertion fires for an
# entry covering 'now') is the primary regression signal. Future
# improvement: grant AX to the harness runner + add a resize_window
# helper to enable a single full-page Triggers capture.
smoke_info "18a/18b open at default size — Schedule below fold (AX permission needed for harness-driven resize)"
bash "$HARNESS_LIB/capture_window.sh" "$SMOKE_SCREENSHOTS_DIR/18a-schedule-now.png" "Latte" "Latte Settings"
bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
sleep 1

# --- Variant B: cross-midnight entry → "Crosses midnight" caption ---
bash "$HARNESS_LIB/reset_prefs.sh" "$SMOKE_BUNDLE_ID" >/dev/null
defaults write "$SMOKE_BUNDLE_ID" latte.firstRunCompleted -bool true
defaults write "$SMOKE_BUNDLE_ID" latte.scheduleTrigger.enabled -bool true

uuid_b="$(uuidgen)"
# 23:00 Mon → 02:00 Tue: end < start triggers the caption.
entries_b="[{\"id\":\"$uuid_b\",\"weekdays\":[2],\"start\":{\"hour\":23,\"minute\":0},\"end\":{\"hour\":2,\"minute\":0},\"label\":\"smoke-cross-midnight\",\"isEnabled\":true}]"
write_entries "$entries_b"

bash "$HARNESS_LIB/launch_app.sh" "$SMOKE_APP_PATH" "$SMOKE_BUNDLE_ID" 20 >/dev/null
sleep 2
bash "$HARNESS_LIB/open_settings.sh" latte triggers >/dev/null
sleep 3
bash "$HARNESS_LIB/capture_window.sh" "$SMOKE_SCREENSHOTS_DIR/18b-schedule-cross-night.png" "Latte" "Latte Settings"
bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null

smoke_record "$SMOKE_REPORT" 18-schedule "passed" "V2-05: now-entry held assertion; cross-midnight caption captured (visual)"
smoke_ok "schedule scenarios captured"
