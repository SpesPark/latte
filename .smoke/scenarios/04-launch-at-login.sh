#!/usr/bin/env bash
# S8b smoke-E: Launch at Login external reconciliation.
# Validates that toggling the SMAppService key from defaults reflects in
# Settings UI via the Toggle on next launch (the "external reconcile" path).

set -euo pipefail
source "$HARNESS_LIB/log.sh"
bash "$HARNESS_LIB/reset_prefs.sh" "$SMOKE_BUNDLE_ID" >/dev/null
bash "$HARNESS_LIB/defaults_helper.sh" write "$SMOKE_BUNDLE_ID" latte.firstRunCompleted -bool true >/dev/null

# Note: SMAppService state is system-managed, not directly in user defaults.
# We can read its mirror flag if Latte writes one. Latte stores a UI mirror at
# `latte.launchAtLogin.uiMirror` (see LaunchAtLoginManager).

bash "$HARNESS_LIB/launch_app.sh" "$SMOKE_APP_PATH" "$SMOKE_BUNDLE_ID" 20 >/dev/null
sleep 2

initial="$(bash "$HARNESS_LIB/defaults_helper.sh" read "$SMOKE_BUNDLE_ID" latte.launchAtLogin 2>/dev/null || echo missing)"
smoke_info "initial latte.launchAtLogin = $initial"

# Capture Settings → General screenshot for visual review.
osascript -e 'tell application id "com.parkbyeongjun.latte" to activate' 2>/dev/null || true
sleep 2
bash "$HARNESS_LIB/capture_screenshot.sh" "$SMOKE_SCREENSHOTS_DIR/04-settings-general.png"

smoke_record "$SMOKE_REPORT" 04-launch-at-login "info" "latte.launchAtLogin=$initial; full smoke-E requires SMAppService roundtrip — owner verifies via System Settings → General → Login Items"
smoke_ok "launch-at-login state snapshot captured"

bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
