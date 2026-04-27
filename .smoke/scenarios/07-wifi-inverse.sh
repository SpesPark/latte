#!/usr/bin/env bash
# Negative test: Wi-Fi inverse-logic edge cases.
#
#   Mode A — normal (inverse=false), SSID list empty   → vote: never
#   Mode B — normal (inverse=false), SSID matches      → vote: yes
#   Mode C — inverse (inverse=true),  SSID list empty  → vote: ALWAYS (sleep blocked everywhere)
#   Mode D — inverse (inverse=true),  SSID matches     → vote: NEVER on those nets
#
# We exercise A and C deterministically (no actual network mutation needed —
# Latte's WiFiTrigger evaluates against the current SSID; we just configure
# defaults and assert the app stays alive and doesn't crash on the empty case).

set -euo pipefail
source "$HARNESS_LIB/log.sh"
bash "$HARNESS_LIB/reset_prefs.sh" "$SMOKE_BUNDLE_ID" --keep-tcc >/dev/null
bash "$HARNESS_LIB/defaults_helper.sh" write "$SMOKE_BUNDLE_ID" latte.firstRunCompleted -bool true >/dev/null

# --- Mode A: normal + empty SSID list ---
bash "$HARNESS_LIB/defaults_helper.sh" write "$SMOKE_BUNDLE_ID" latte.wifiTrigger.enabled -bool true >/dev/null
bash "$HARNESS_LIB/defaults_helper.sh" write "$SMOKE_BUNDLE_ID" latte.wifiTrigger.inverseLogic -bool false >/dev/null
defaults delete "$SMOKE_BUNDLE_ID" latte.wifiTrigger.ssids 2>/dev/null || true

bash "$HARNESS_LIB/launch_app.sh" "$SMOKE_APP_PATH" "$SMOKE_BUNDLE_ID" 20 >/dev/null
sleep 3

pid="$(lsappinfo info -only pid -app "$SMOKE_BUNDLE_ID" 2>/dev/null | awk -F'=' '{print $2}')"
if [[ -z "$pid" || "$pid" == "(null)" ]] || ! ps -p "$pid" >/dev/null 2>&1; then
  smoke_error "Latte died in Mode A (normal + empty SSID list)"
  exit 1
fi
smoke_ok "Mode A stable (pid=$pid, normal + empty SSID list)"

bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
sleep 1

# --- Mode C: inverse + empty SSID list ---
bash "$HARNESS_LIB/defaults_helper.sh" write "$SMOKE_BUNDLE_ID" latte.wifiTrigger.inverseLogic -bool true >/dev/null

bash "$HARNESS_LIB/launch_app.sh" "$SMOKE_APP_PATH" "$SMOKE_BUNDLE_ID" 20 >/dev/null
sleep 3

pid="$(lsappinfo info -only pid -app "$SMOKE_BUNDLE_ID" 2>/dev/null | awk -F'=' '{print $2}')"
if [[ -z "$pid" || "$pid" == "(null)" ]] || ! ps -p "$pid" >/dev/null 2>&1; then
  smoke_error "Latte died in Mode C (inverse + empty SSID list)"
  exit 1
fi
smoke_ok "Mode C stable (pid=$pid, inverse + empty SSID list — would block sleep on all networks)"

smoke_record "$SMOKE_REPORT" 07-wifi-inverse "passed" "Mode A + Mode C both stable; inverse-logic edge cases don't crash"
bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
