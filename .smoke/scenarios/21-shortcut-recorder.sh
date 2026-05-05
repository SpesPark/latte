#!/usr/bin/env bash
# S12 / B1.2 — Custom keyboard-shortcut recorder basic functional check.
#
# Pure SwiftUI key capture isn't scriptable from a smoke harness without
# Accessibility permission, so the automated branch verifies:
#   - Default state: shortcutChord key is absent (silent default per
#     spec §8 Q4 — coordinator falls back to .default in-memory).
#   - Settings → General opens, capture window for owner visual review
#     of the recorder row + Reset button.
#
# The "click field, press chord, persisted" path is owner manual smoke
# territory (handoff step 6 covers the new flow).

set -euo pipefail
source "$HARNESS_LIB/log.sh"

# Feature-presence guard (S28). Asserts the chord-recorder coordinator is
# compiled into the Release binary; absent this type, the silent-default
# check would still pass on a binary that lacks the recorder UI (S27
# stale-binary discovery).
bash "$HARNESS_LIB/assert_binary_type.sh" \
  "$SMOKE_APP_PATH/Contents/MacOS/Latte" \
  '\bLatte\.KeyboardShortcutCoordinator\b' \
  "21-shortcut-recorder" >/dev/null

bash "$HARNESS_LIB/reset_prefs.sh" "$SMOKE_BUNDLE_ID" >/dev/null

# Seed: onboarding done. Enable the toggle so the recorder field is in
# the meaningful state for the capture (toggle OFF → recorder still
# visible but Reset button disabled w/ default chord, less visually
# informative for an owner reviewing the screenshot).
defaults write "$SMOKE_BUNDLE_ID" latte.firstRunCompleted -bool true
defaults write "$SMOKE_BUNDLE_ID" latte.keyboardShortcut.enabled -bool true

bash "$HARNESS_LIB/launch_app.sh" "$SMOKE_APP_PATH" "$SMOKE_BUNDLE_ID" 20 >/dev/null
sleep 4  # AppEnvironment + KeyboardShortcutCoordinator init pass

# Phase 1: silent-default migration. shortcutChord must be absent on a
# fresh install — the coordinator hydrates .default from memory, never
# touching the store. (`defaults read … <key>` exits non-zero when key
# is missing; that's the assertion.)
if defaults read "$SMOKE_BUNDLE_ID" latte.keyboardShortcut.chord >/dev/null 2>&1; then
  smoke_error "shortcut-recorder: shortcutChord present on fresh install (silent-default broke)"
  bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
  exit 1
fi
smoke_ok "shortcut-recorder: silent-default migration (no chord persisted on fresh install)"

# Phase 2: capture Settings → General so owner can review the new
# recorder row + Reset button alongside the existing toggle.
bash "$HARNESS_LIB/open_settings.sh" latte general >/dev/null
sleep 3
bash "$HARNESS_LIB/capture_window.sh" \
  "$SMOKE_SCREENSHOTS_DIR/21-shortcut-recorder.png" \
  "Latte" "Latte Settings"

bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null

smoke_record "$SMOKE_REPORT" 21-shortcut-recorder "passed" "Shortcut recorder: silent-default migration + Settings capture"
smoke_ok "scenario 21-shortcut-recorder PASSED"
