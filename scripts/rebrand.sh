#!/usr/bin/env bash
# rebrand.sh — bundle-ID prefix rewire tool (S52 rebrand-prep kit).
#
# The first publish makes the bundle ID permanent, so the owner is holding the
# release until the 상호 (brand) is chosen. When it is, this script swaps the
# `com.parkbyeongjun` prefix across every FUNCTIONAL file in one pass while
# leaving historical documents (ROADMAP, SESSION_HANDOFF, QA_LOG) untouched.
#
# Usage:
#   scripts/rebrand.sh <new-prefix>            # DRY-RUN: show what would change
#   scripts/rebrand.sh <new-prefix> --apply    # perform the replacement
#   scripts/rebrand.sh --check                 # verify no old prefix remains
#                                              # outside the history allowlist
#                                              # (fails BEFORE rebrand by design)
#
# <new-prefix> is the reverse-DNS prefix WITHOUT the app segment, e.g.
# `com.acmebrand` — the script derives `com.acmebrand.latte`,
# `com.acmebrand.latte.tests`, and `iCloud.com.acmebrand.latte`.
#
# After --apply, the printed manual checklist still applies (xcodegen, signed
# build, TCC re-grants, defaults migration). See docs/rebrand-checklist.md.

set -euo pipefail

OLD_PREFIX="com.parkbyeongjun"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Functional files that hardcode the prefix. Keep in sync with
# docs/rebrand-checklist.md (inventory table). Discovery command:
#   grep -rln "com.parkbyeongjun" . --exclude-dir=.git
TARGETS=(
  # build + signing
  "project.yml"
  "Configuration/Latte.icloud.entitlements"
  # sources (os_log subsystem + CloudKit container)
  "Sources/Core/LanguagePreference.swift"
  "Sources/Core/Logging.swift"
  "Sources/Core/CloudKitSyncEngine.swift"
  "Sources/Core/LaunchAtLoginManager.swift"
  "Sources/Core/PowerAssertion.swift"
  "Sources/Core/SettingsStore.swift"
  "Sources/UI/Onboarding/OnboardingState.swift"
  # tests
  "Tests/LanguagePreferenceTests.swift"
  # smoke harness
  ".smoke/config.yml"
  ".smoke/scenarios/04-launch-at-login.sh"
  ".smoke/scenarios/05-calendar-picker.sh"
  # store tooling + published pages source
  "docs/store/screenshot-guide.md"
  "docs/store/screenshots/_scripts/capture.sh"
  "docs/site/privacy.html"
  # contributor surfaces
  ".github/ISSUE_TEMPLATE/bug_report.md"
  # living design docs (NOT session history)
  "docs/design/01-PRD.md"
  "docs/design/02-architecture.md"
  "docs/design/04-data-model.md"
  "docs/design/07-shortcut-recorder.md"
  "docs/design/09-c3-activity-history.md"
  "docs/design/10-c3-icloud-sync-rfc.md"
  "docs/v2-backlog.md"
)

# Historical records keep the old prefix as an audit trail — never rewritten,
# ignored by --check.
HISTORY_ALLOWLIST=(
  "ROADMAP.md"
  "docs/SESSION_HANDOFF.md"
  "docs/QA_LOG.md"
  "docs/rebrand-checklist.md"   # references the old prefix in migration examples
)

check_mode() {
  local leftovers
  # Latte.xcodeproj is GENERATED — xcodegen regenerates it from the rewired
  # project.yml (manual step 1), so it must not gate the post-apply check.
  leftovers=$(grep -rln "$OLD_PREFIX" . \
      --exclude-dir=.git --exclude-dir=build --exclude-dir=.claude \
      --exclude-dir=Latte.xcodeproj \
      --exclude="$(basename "$0")" 2>/dev/null | sed 's|^\./||' || true)
  local bad=()
  for f in $leftovers; do
    local allowed=0
    for h in "${HISTORY_ALLOWLIST[@]}"; do
      [[ "$f" == "$h" ]] && allowed=1 && break
    done
    [[ $allowed -eq 0 ]] && bad+=("$f")
  done
  if [[ ${#bad[@]} -gt 0 ]]; then
    echo "✗ old prefix '$OLD_PREFIX' still present outside the history allowlist:"
    printf '    %s\n' "${bad[@]}"
    exit 1
  fi
  echo "✓ no '$OLD_PREFIX' outside the history allowlist (${HISTORY_ALLOWLIST[*]})"
  exit 0
}

[[ "${1:-}" == "--check" ]] && check_mode

NEW_PREFIX="${1:-}"
MODE="${2:-dry-run}"

if [[ -z "$NEW_PREFIX" ]]; then
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
fi
if ! [[ "$NEW_PREFIX" =~ ^[a-z0-9]+(\.[a-z0-9-]+)+$ ]]; then
  echo "✗ '$NEW_PREFIX' is not a valid reverse-DNS prefix (lowercase a-z0-9, dot-separated, ≥2 segments)" >&2
  exit 2
fi
if [[ "$NEW_PREFIX" == *".latte" ]]; then
  echo "✗ pass the PREFIX only (got '$NEW_PREFIX' — drop the trailing .latte; the script appends app segments itself)" >&2
  exit 2
fi
if [[ "$NEW_PREFIX" == "$OLD_PREFIX" ]]; then
  echo "✗ new prefix equals the old prefix" >&2
  exit 2
fi

echo "Rebrand: $OLD_PREFIX → $NEW_PREFIX"
echo "  app bundle ID:    $NEW_PREFIX.latte"
echo "  tests bundle ID:  $NEW_PREFIX.latte.tests"
echo "  iCloud container: iCloud.$NEW_PREFIX.latte"
echo

total=0
for f in "${TARGETS[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "✗ target missing: $f (inventory drifted — update TARGETS + docs/rebrand-checklist.md)" >&2
    exit 1
  fi
  n=$(grep -c "$OLD_PREFIX" "$f" 2>/dev/null || true)
  if [[ "$n" -eq 0 ]]; then
    echo "  · $f — 0 occurrences (already clean?)"
    continue
  fi
  total=$((total + n))
  if [[ "$MODE" == "--apply" ]]; then
    perl -pi -e "s/\Q$OLD_PREFIX\E/$NEW_PREFIX/g" "$f"
    echo "  ✓ $f — $n occurrence(s) replaced"
  else
    echo "  → $f — $n occurrence(s):"
    grep -n "$OLD_PREFIX" "$f" | sed 's/^/      /'
  fi
done
echo
echo "Total: $total occurrence(s) across ${#TARGETS[@]} target files."

if [[ "$MODE" != "--apply" ]]; then
  echo
  echo "DRY-RUN — nothing written. Re-run with --apply to perform the replacement."
  exit 0
fi

echo
echo "Verifying no leftovers outside the history allowlist…"
"$0" --check

cat <<'CHECKLIST'

── Manual steps after --apply (see docs/rebrand-checklist.md for detail) ──
 1. xcodegen generate                       # regenerate the Xcode project
 2. Signed build + entitlements verify:
      xcodebuild build -scheme Latte -destination 'platform=macOS,arch=arm64'
      codesign -d --entitlements - <built .app>
 3. scripts/run_tests.sh                    # expect full suite green
 4. ⚠ TCC RESETS with the new bundle ID — re-grant on the owner machine:
      Calendar / Location(Wi-Fi) for the app; Screen Recording + Accessibility
      for the screenshot pipeline; then re-verify smoke + capture.sh.
 5. Owner defaults migrate (old domain keeps settings, new domain starts empty):
      defaults export com.parkbyeongjun.latte /tmp/latte.plist
      defaults import <new-prefix>.latte /tmp/latte.plist
    (sandbox container moves to ~/Library/Containers/<new-prefix>.latte/)
 6. Redeploy gh-pages privacy.html (source updated in docs/site/).
 7. ASC: register the new App ID; iCloud container only at Phase-2 activation.
CHECKLIST
