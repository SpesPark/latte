#!/usr/bin/env bash
# S35 / pre-flight — Verify critical Apple-bundle resources are present in
# the built Release .app before any UI-driving scenario runs.
#
# Why this exists (S33 → S35):
#   S33 surfaced a P0 class of bug where a refactor shipped a binary that
#   BUILT fine, PASSED unit tests, but was missing 10 .lproj/ directories
#   from Contents/Resources/. App ran in English only regardless of host
#   locale. BundleIntegrityTests (S34) catch this at the test layer, but
#   that layer relies on Bundle.main resolving to the host Latte.app of
#   the xctest plug-in. If the test suite is ever skipped (--skip-testing
#   during owner manual triage, or a CI misconfiguration) the smoke
#   harness scenarios would still PASS against a stripped binary — URL
#   routing falls back, window-capture only introspects window owner/
#   title. This pre-flight scenario closes that gap independently.
#
# Runs first (`00-` prefix sorts before all other scenarios) and is fast
# (~50 ms) — file-system inspection only, no app launch, no UI.

set -euo pipefail
source "$HARNESS_LIB/log.sh"

# Latte ships 11 .lproj directories: en (source) + ko + ja + zh-Hans
# + zh-Hant + es + de + fr + pt-BR + it + ru. Matches project.yml
# knownRegions and Localizable.xcstrings catalog.
bash "$HARNESS_LIB/assert_bundle_resources.sh" \
  "$SMOKE_APP_PATH" \
  11 \
  "00-bundle-integrity" >/dev/null

smoke_record "$SMOKE_REPORT" 00-bundle-integrity "passed" "Bundle integrity: 11 .lproj + Assets.car + Info.plist"
smoke_ok "scenario 00-bundle-integrity PASSED"
