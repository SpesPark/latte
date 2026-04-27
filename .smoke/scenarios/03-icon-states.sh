#!/usr/bin/env bash
# S8b smoke-D: Capture menu-bar icon under all 3 styles × {light, dark}.
# Owner verifies visually that filled / outline / clock are distinct in both modes.
#
# 6 artifacts: 03-{filled,outline,clock}-{light,dark}.png

set -euo pipefail
source "$HARNESS_LIB/log.sh"
bash "$HARNESS_LIB/reset_prefs.sh" "$SMOKE_BUNDLE_ID" >/dev/null
bash "$HARNESS_LIB/defaults_helper.sh" write "$SMOKE_BUNDLE_ID" latte.firstRunCompleted -bool true >/dev/null

# Remember current appearance to restore it.
orig_dark="$(osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode' 2>/dev/null || echo false)"

styles=(filled outline clock)

for style in "${styles[@]}"; do
  bash "$HARNESS_LIB/defaults_helper.sh" write "$SMOKE_BUNDLE_ID" latte.menuBarIconStyle -string "$style" >/dev/null

  for mode in light dark; do
    bash "$HARNESS_LIB/appearance.sh" "$mode" >/dev/null
    sleep 1
    bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
    sleep 1
    bash "$HARNESS_LIB/launch_app.sh" "$SMOKE_APP_PATH" "$SMOKE_BUNDLE_ID" 20 >/dev/null
    sleep 2
    bash "$HARNESS_LIB/capture_menubar.sh" "$SMOKE_SCREENSHOTS_DIR/03-${style}-${mode}.png"
  done
done

# Restore original appearance.
if [[ "$orig_dark" == "true" ]]; then
  bash "$HARNESS_LIB/appearance.sh" dark >/dev/null
else
  bash "$HARNESS_LIB/appearance.sh" light >/dev/null
fi

smoke_record "$SMOKE_REPORT" 03-icon-states "passed" "6 artifacts captured: filled/outline/clock × light/dark"
smoke_ok "icon-states matrix captured"
bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
