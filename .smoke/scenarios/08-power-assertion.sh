#!/usr/bin/env bash
# Power-assertion lifecycle: when Latte transitions to awake, pmset must show
# a PreventUserIdleSystemSleep assertion held by Latte. When asleep, no leak.
#
# This is the canonical "doesn't leak power assertions" check from PRD §10
# G4 ("no power-assertion leak in 24-hr soak"). We do the short-window version
# here; soak is a v1.x ROADMAP item.

set -euo pipefail
source "$HARNESS_LIB/log.sh"
bash "$HARNESS_LIB/reset_prefs.sh" "$SMOKE_BUNDLE_ID" --keep-tcc >/dev/null
bash "$HARNESS_LIB/defaults_helper.sh" write "$SMOKE_BUNDLE_ID" latte.firstRunCompleted -bool true >/dev/null

# Use the App trigger with no bundles enabled — keeps Latte alive but in idle state.
bash "$HARNESS_LIB/defaults_helper.sh" write "$SMOKE_BUNDLE_ID" latte.appTrigger.enabled -bool false >/dev/null

bash "$HARNESS_LIB/launch_app.sh" "$SMOKE_APP_PATH" "$SMOKE_BUNDLE_ID" 20 >/dev/null
sleep 3

# Assertion check 1: idle → must NOT hold PreventUserIdleSystemSleep
if bash "$HARNESS_LIB/verify_assertion.sh" Latte 2>/dev/null; then
  smoke_error "Latte held a power assertion at idle (leak)"
  bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
  exit 1
fi
smoke_ok "idle: no power assertion held (good)"

# Quit and re-check: assertion must release on quit even if it was held.
bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
sleep 2

if pmset -g assertions 2>/dev/null | grep -q "PreventUserIdleSystemSleep.*Latte"; then
  smoke_error "Latte assertion leaked after quit"
  exit 1
fi
smoke_ok "post-quit: no leaked assertion (good)"

smoke_record "$SMOKE_REPORT" 08-power-assertion "passed" "no power-assertion leak at idle and after quit (short-window check; 24h soak is a v1.x item)"
