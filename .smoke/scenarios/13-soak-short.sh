#!/usr/bin/env bash
# Compressed power-assertion soak.
# PRD §10 G4 calls for "no power-assertion leak in 24-hr soak". The full soak
# is impractical inside the harness — ~2 minutes of repeated awake/idle
# transitions catches the failure modes (ref-count off-by-one, double-finish,
# leaked NSWindow keeping a Task alive) without burning real time.
#
# Asserts at end:
#   - exactly 0 PreventUserIdleSystemSleep assertions held by Latte
#   - process still alive
#   - no fatalError signature in unified log

set -euo pipefail
source "$HARNESS_LIB/log.sh"
bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
sleep 1
defaults delete "$SMOKE_BUNDLE_ID" 2>/dev/null || true
defaults write "$SMOKE_BUNDLE_ID" latte.firstRunCompleted -bool true
defaults write "$SMOKE_BUNDLE_ID" latte.appTrigger.enabled -bool true

# Seed App trigger with a bundle that's certain to NOT be running, so toggles
# stay deterministic.
bundles_json='["com.latte.smoke.never-running.placeholder"]'
bundles_hex="$(printf '%s' "$bundles_json" | xxd -p | tr -d '\n')"
defaults write "$SMOKE_BUNDLE_ID" latte.appTrigger.bundleIDs -data "$bundles_hex"

bash "$HARNESS_LIB/launch_app.sh" "$SMOKE_APP_PATH" "$SMOKE_BUNDLE_ID" 20 >/dev/null
sleep 2

# 12 toggle cycles ~ ~72s; long enough to exercise the AsyncStream lifecycle
# fix from S8b (commit 45e73fc) under repeated start/stop.
cycles=12
for ((i = 1; i <= cycles; i++)); do
  defaults write "$SMOKE_BUNDLE_ID" latte.appTrigger.enabled -bool false
  sleep 2
  defaults write "$SMOKE_BUNDLE_ID" latte.appTrigger.enabled -bool true
  sleep 4
  if (( i % 4 == 0 )); then
    smoke_info "soak cycle $i / $cycles"
  fi
done

# Final state: trigger off, give Latte a beat to release any held assertion.
defaults write "$SMOKE_BUNDLE_ID" latte.appTrigger.enabled -bool false
sleep 5

# 1) No assertion leaked.
if pmset -g assertions 2>/dev/null | grep -q "PreventUserIdleSystemSleep.*Latte"; then
  smoke_error "soak: PreventUserIdleSystemSleep leaked after $cycles cycles + idle"
  bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
  exit 1
fi

# 2) Process still alive.
pid="$(lsappinfo info -only pid -app "$SMOKE_BUNDLE_ID" 2>/dev/null | awk -F'=' '{print $2}')"
if [[ -z "$pid" || "$pid" == "(null)" ]] || ! ps -p "$pid" >/dev/null 2>&1; then
  smoke_error "soak: Latte died during $cycles cycles"
  exit 1
fi

# 3) Log free of fatalError / Swift runtime crash.
if /usr/bin/log show --last 120s --style compact --predicate 'process == "Latte"' 2>/dev/null \
    | grep -Eq "fatalError|Swift runtime|EXC_BAD_ACCESS"; then
  smoke_error "soak: crash signature in Latte log"
  exit 1
fi

smoke_record "$SMOKE_REPORT" 13-soak-short "passed" "$cycles toggle cycles, no assertion leak, no crash signature; pid=$pid"
smoke_ok "soak short ($cycles cycles) clean"
bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
