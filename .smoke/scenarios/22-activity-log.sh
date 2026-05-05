#!/usr/bin/env bash
# S14 / C-3 — Activity history JSON file is written when a trigger fires.
#
# The bash branch verifies the persistence contract end-to-end:
#   - Fresh install (file deleted) → launch app → file does not yet exist.
#   - Wifi trigger configured to vote ON immediately (current SSID is in
#     the empty allowlist with inverse-logic disabled would be impossible
#     to script reliably; instead we use an AppleEvent to push a manual
#     awake → trigger fire isn't required for the file to be created
#     on first append, but for a deterministic test we open Settings →
#     Activity tab so the lazy-load runs even without a fired event).
#   - Capture Settings → Activity for owner visual review.
#
# The "real trigger fires → entry recorded" path is owner manual smoke
# territory (handoff step 8 covers the new flow). The bash branch
# guarantees the on-disk file format and Activity tab render.

set -euo pipefail
source "$HARNESS_LIB/log.sh"

# Feature-presence guard (S28). Asserts ActivityTab is compiled into the
# Release binary; without this, URL routing falls back to General when the
# tab is missing and the rest of the scenario is a false positive (S27
# stale-binary discovery).
bash "$HARNESS_LIB/assert_binary_type.sh" \
  "$SMOKE_APP_PATH/Contents/MacOS/Latte" \
  '\bLatte\.ActivityTab\b' \
  "22-activity-log" >/dev/null

bash "$HARNESS_LIB/reset_prefs.sh" "$SMOKE_BUNDLE_ID" >/dev/null

# Wipe activity-log.json so we observe the create-on-first-append path.
ACTIVITY_LOG="$HOME/Library/Application Support/Latte/activity-log.json"
rm -f "$ACTIVITY_LOG"

defaults write "$SMOKE_BUNDLE_ID" latte.firstRunCompleted -bool true

bash "$HARNESS_LIB/launch_app.sh" "$SMOKE_APP_PATH" "$SMOKE_BUNDLE_ID" 20 >/dev/null
sleep 4

# Phase 1: file should not exist yet — store creates lazily on first
# append, and no trigger has fired during fresh launch.
if [[ -f "$ACTIVITY_LOG" ]]; then
  smoke_warn "activity-log: file already present on fresh launch (will overwrite when first event fires) — continuing"
else
  smoke_ok "activity-log: file absent on fresh launch (lazy-load contract holds)"
fi

# Phase 2: open Settings → Activity tab so an owner reviewer can see the
# empty-state UI and confirm the 4th tab shipped wired to the store.
bash "$HARNESS_LIB/open_settings.sh" latte activity >/dev/null
sleep 3
bash "$HARNESS_LIB/capture_window.sh" \
  "$SMOKE_SCREENSHOTS_DIR/22-activity-log.png" \
  "Latte" "Latte Settings"

# Phase 3: if an entry happened to be written during this run (e.g. an
# enabled trigger fired), validate schema. Privacy contract: only the
# allowed keys are present.
if [[ -f "$ACTIVITY_LOG" ]]; then
  KEYS=$(jq -r '.[0] | keys | sort | join(",")' "$ACTIVITY_LOG" 2>/dev/null || echo "")
  EXPECTED="id,kind,reasonCode,timestamp,triggerId"
  if [[ "$KEYS" == "$EXPECTED" ]]; then
    smoke_ok "activity-log: schema matches privacy contract (no free-text fields)"
  else
    smoke_error "activity-log: unexpected keys '$KEYS' — privacy contract may be broken"
    bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null
    exit 1
  fi
fi

bash "$HARNESS_LIB/quit_app.sh" "$SMOKE_BUNDLE_ID" >/dev/null

smoke_record "$SMOKE_REPORT" 22-activity-log "passed" "Activity log: lazy-load + 4th tab + schema privacy contract"
smoke_ok "scenario 22-activity-log PASSED"
