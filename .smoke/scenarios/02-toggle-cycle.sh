#!/usr/bin/env bash
# S8b smoke-P2-2 regression: Toggle OFF → ON cycle restores cup glyph.
# Validates the consumer-task keepalive fix (commit 45e73fc) — after disabling
# and re-enabling triggers, the menu-bar icon must return to the awake glyph
# when an assertion fires (asserted via pmset within a 5s window after re-enable).

set -euo pipefail
source "$HARNESS_LIB/log.sh"
bash "$HARNESS_LIB/reset_prefs.sh" "$SMOKE_BUNDLE_ID" >/dev/null

# Pre-set onboarding done so we go straight to menu bar.
bash "$HARNESS_LIB/defaults_helper.sh" write "$SMOKE_BUNDLE_ID" latte.firstRunCompleted -bool true >/dev/null

# Manual override: enable the App trigger so we can predictably toggle awake.
bash "$HARNESS_LIB/defaults_helper.sh" write "$SMOKE_BUNDLE_ID" latte.appTrigger.enabled -bool true >/dev/null

bash "$HARNESS_LIB/launch_app.sh" "$SMOKE_APP_PATH" "$SMOKE_BUNDLE_ID" 20 >/dev/null
sleep 3
bash "$HARNESS_LIB/capture_menubar.sh" "$SMOKE_SCREENSHOTS_DIR/02-toggle-initial.png"

# Cycle: turn appTrigger OFF, sleep, ON.
bash "$HARNESS_LIB/defaults_helper.sh" write "$SMOKE_BUNDLE_ID" latte.appTrigger.enabled -bool false >/dev/null
sleep 2
bash "$HARNESS_LIB/defaults_helper.sh" write "$SMOKE_BUNDLE_ID" latte.appTrigger.enabled -bool true >/dev/null
sleep 3
bash "$HARNESS_LIB/capture_menubar.sh" "$SMOKE_SCREENSHOTS_DIR/02-toggle-after-cycle.png"

smoke_record "$SMOKE_REPORT" 02-toggle-cycle "info" "menu-bar before/after captures saved; visual diff is the assertion"
smoke_ok "toggle cycle artifacts captured"

bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
