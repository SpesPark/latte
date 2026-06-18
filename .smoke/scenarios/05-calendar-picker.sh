#!/usr/bin/env bash
# S8b smoke-F: Calendar picker delete edge case.
# When user enables Calendar trigger but no calendars are selected (or all are
# subsequently deselected), the trigger must not crash and Settings must reflect
# the empty state without re-prompting.

set -euo pipefail
source "$HARNESS_LIB/log.sh"
bash "$HARNESS_LIB/reset_prefs.sh" "$SMOKE_BUNDLE_ID" --keep-tcc >/dev/null
bash "$HARNESS_LIB/defaults_helper.sh" write "$SMOKE_BUNDLE_ID" latte.firstRunCompleted -bool true >/dev/null
bash "$HARNESS_LIB/defaults_helper.sh" write "$SMOKE_BUNDLE_ID" latte.calendarTrigger.enabled -bool true >/dev/null
# Empty selection — `latte.calendarTrigger.calendarIDs` is intentionally absent.

bash "$HARNESS_LIB/launch_app.sh" "$SMOKE_APP_PATH" "$SMOKE_BUNDLE_ID" 20 >/dev/null
sleep 3

osascript -e 'tell application id "com.araforge.latte" to activate' 2>/dev/null || true
sleep 2
bash "$HARNESS_LIB/capture_screenshot.sh" "$SMOKE_SCREENSHOTS_DIR/05-calendar-empty-selection.png"

# Verify process is still alive via LaunchServices (process name is "Latte" not the bundle id).
pid="$(lsappinfo info -only pid -app "$SMOKE_BUNDLE_ID" 2>/dev/null | awk -F'=' '{print $2}')"
if [[ -n "$pid" && "$pid" != "(null)" ]] && ps -p "$pid" >/dev/null 2>&1; then
  smoke_record "$SMOKE_REPORT" 05-calendar-picker "passed" "Latte alive (pid=$pid) with calendarTrigger.enabled=true and no selection (no crash)"
  smoke_ok "calendar empty-selection edge case stable (pid=$pid)"
else
  smoke_error "Latte died after enabling calendarTrigger with no selection (pid=$pid)"
  exit 1
fi

bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
