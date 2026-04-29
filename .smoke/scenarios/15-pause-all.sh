#!/usr/bin/env bash
# S9.5 (C-9) Pause-all triggers — verifies the AwakeManager input-boundary
# gate that drops trigger ON votes while `triggersPaused = true`.
#
# Strategy: seed App trigger with Finder (always running), so without pause
# the trigger would normally fire and Latte would acquire PreventUserIdleSystemSleep.
# With `triggersPaused = true` pre-set, that vote must be dropped — pmset must
# show no Latte assertion. Then quit Latte, write triggersPaused=false, relaunch
# (external `defaults write` does not propagate to a running app's @Published
# state — restart is the only safe way for a smoke harness to flip the gate).
#
# Asserts at end:
#   - paused state: NO Latte PreventUserIdleSystemSleep assertion
#   - unpaused state: Latte holds PreventUserIdleSystemSleep within 5s
#   - menu-bar capture before/after for owner visual review of the
#     "Pause triggers" / "Triggers paused" row state.

set -euo pipefail
source "$HARNESS_LIB/log.sh"
bash "$HARNESS_LIB/reset_prefs.sh" "$SMOKE_BUNDLE_ID" >/dev/null

# Seed: onboarding done, App trigger enabled, paused on launch.
defaults write "$SMOKE_BUNDLE_ID" latte.firstRunCompleted -bool true
defaults write "$SMOKE_BUNDLE_ID" latte.appTrigger.enabled -bool true
defaults write "$SMOKE_BUNDLE_ID" latte.triggersPaused -bool true

# Watch Finder — guaranteed to be running on any Mac with a logged-in user.
bundles_json='["com.apple.finder"]'
bundles_hex="$(printf '%s' "$bundles_json" | xxd -p | tr -d '\n')"
defaults write "$SMOKE_BUNDLE_ID" latte.appTrigger.bundleIDs -data "$bundles_hex"

bash "$HARNESS_LIB/launch_app.sh" "$SMOKE_APP_PATH" "$SMOKE_BUNDLE_ID" 20 >/dev/null
sleep 4  # AppEnvironment.bootTriggers + first evaluate pass

# 1) Pause is in effect — even with Finder running, no Latte assertion.
# pmset reports `kIOPMAssertionTypeNoDisplaySleep` (the default Latte mode
# when allowDisplaySleep=false) as `NoDisplaySleepAssertion`, not the
# friendly-sounding `PreventUserIdleSystemSleep` you'd expect. Match by
# owning-pid line instead so we are robust to label changes and to either
# assertion mode (.displayAndSystem or .systemOnly).
if pmset -g assertions 2>/dev/null | grep -Eq "pid [0-9]+\(Latte\):"; then
  smoke_error "pause-all: Latte holds assertion while triggersPaused=true (gate not enforced)"
  bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
  exit 1
fi
smoke_ok "paused: no Latte assertion (gate working)"
bash "$HARNESS_LIB/capture_menubar.sh" "$SMOKE_SCREENSHOTS_DIR/15-pause-all-paused.png"

# 2) Unpause — must restart Latte. External `defaults write` does not flow
#    into the live `@Published manager.triggersPaused`; only the toggle in the
#    popover (which calls the @Published setter, which writes UserDefaults
#    *and* updates the in-memory state) does. Restart picks up the new value
#    on AwakeManager.init via SettingsStore.
bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
sleep 1
defaults write "$SMOKE_BUNDLE_ID" latte.triggersPaused -bool false
bash "$HARNESS_LIB/launch_app.sh" "$SMOKE_APP_PATH" "$SMOKE_BUNDLE_ID" 20 >/dev/null

held=0
for i in 1 2 3 4 5 6 7 8; do
  sleep 1
  matched="$(pmset -g assertions 2>/dev/null | grep -E "pid [0-9]+\(Latte\):" | head -1 || true)"
  smoke_info "t+${i}s pmset-Latte: ${matched:-<none>}"
  if [[ -n "$matched" ]]; then
    held=1
    break
  fi
done

if (( held == 0 )); then
  smoke_error "pause-all unpause path: Latte did not acquire assertion within 8s after restart with triggersPaused=false (gate may not be honoring SettingsStore on init)"
  bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
  exit 1
fi
smoke_ok "unpaused (after restart): Latte acquired assertion within 8s"
bash "$HARNESS_LIB/capture_menubar.sh" "$SMOKE_SCREENSHOTS_DIR/15-pause-all-unpaused.png"

smoke_record "$SMOKE_REPORT" 15-pause-all "passed" "C-9 gate enforced both directions: paused → no assertion; restart with triggersPaused=false → assertion acquired"
bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
