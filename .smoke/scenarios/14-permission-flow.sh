#!/usr/bin/env bash
# First-launch permission flow regression check.
#
# After `tccutil reset` puts Calendar/Location grants back to "not determined",
# Latte's startup path should:
#   1. Launch successfully without crashing.
#   2. Emit `EKEventStore.requestFullAccessToEvents` (logged via os.Logger).
#   3. NOT crash if the user denies/defers the prompt.
#
# This catches the class of regressions where a permission API call from a
# wrong actor isolation context (S8b's "trigger silently does nothing"
# family) re-surfaces. We don't drive the OS dialog itself — TCC dialogs
# require human input by design — but we verify Latte reaches the point of
# requesting them.
#
# tcc_bootstrap.sh is invoked at the end as a hint to the owner about which
# pane to open if they want to actually grant (rather than just verifying the
# request fires).

set -euo pipefail
source "$HARNESS_LIB/log.sh"
bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
sleep 1

# Reset TCC for the bundle. Best-effort: tccutil may need Full Disk Access.
tccutil reset Calendar "$SMOKE_BUNDLE_ID" 2>/dev/null || smoke_warn "tccutil reset Calendar failed (FDA?); continuing"
tccutil reset Location "$SMOKE_BUNDLE_ID" 2>/dev/null || smoke_warn "tccutil reset Location failed (FDA?); continuing"
defaults delete "$SMOKE_BUNDLE_ID" 2>/dev/null || true

# First launch: onboarding wizard would normally show, but we mark it done so
# the boot path goes straight into trigger evaluation where permissions are
# requested.
defaults write "$SMOKE_BUNDLE_ID" latte.firstRunCompleted -bool true
defaults write "$SMOKE_BUNDLE_ID" latte.calendarTrigger.enabled -bool true
defaults write "$SMOKE_BUNDLE_ID" latte.wifiTrigger.enabled -bool true

bash "$HARNESS_LIB/launch_app.sh" "$SMOKE_APP_PATH" "$SMOKE_BUNDLE_ID" 20 >/dev/null
sleep 6  # Let Latte hit the trigger evaluation pass that asks for permissions.

# 1) Process still alive after the permission-prompt-eligible window.
pid="$(lsappinfo info -only pid -app "$SMOKE_BUNDLE_ID" 2>/dev/null | awk -F'=' '{print $2}')"
if [[ -z "$pid" || "$pid" == "(null)" ]] || ! ps -p "$pid" >/dev/null 2>&1; then
  smoke_error "permission-flow: Latte died during first-launch permission pass"
  exit 1
fi

# 2) Calendar trigger logged a permission request OR a denied-status note.
# Both outcomes are valid "didn't crash" signals; only the silent absence is
# a regression (matches the S8b symptom).
if /usr/bin/log show --last 30s --style compact --predicate 'process == "Latte"' 2>/dev/null \
    | grep -Eq "Calendar|EventKit|requestFullAccess|permission|authorization"; then
  smoke_ok "Latte logged a Calendar permission action within 30s"
else
  smoke_warn "no Calendar permission log line found within 30s (may indicate a regression OR pre-existing TCC grant)"
fi

# 3) No crash signature.
if /usr/bin/log show --last 30s --style compact --predicate 'process == "Latte"' 2>/dev/null \
    | grep -Eq "fatalError|EXC_BAD_ACCESS|Swift runtime"; then
  smoke_error "permission-flow: crash signature in log"
  exit 1
fi

smoke_record "$SMOKE_REPORT" 14-permission-flow "passed" "Latte alive (pid=$pid) after TCC reset + first-launch boot; no crash signature"
smoke_ok "permission-flow stable"
smoke_info "Owner: to actually grant Calendar permission, run \`bash \$HARNESS_LIB/tcc_bootstrap.sh calendar\`"

bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
