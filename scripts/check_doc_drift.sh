#!/usr/bin/env bash
# Detect documentation drift — stale test counts, URLs, version strings.
#
# Background (S33 lesson): README claimed "586/586 tests passing" from
# S20-era while the actual count was 607. `bj-park.github.io` carried over
# from S29's username decision until S33 manually fixed it. These drift
# silently across sessions; a periodic check catches them before they
# accumulate.
#
# Usage:
#   scripts/check_doc_drift.sh           # report-only
#   scripts/check_doc_drift.sh --strict  # exit 1 on any drift
#
# Run from repo root.

set -uo pipefail

STRICT=0
[[ "${1:-}" == "--strict" ]] && STRICT=1

DRIFT=0
note() { printf '  ✓ %s\n' "$1"; }
warn() { printf '  ✗ %s\n' "$1"; DRIFT=$((DRIFT + 1)); }

echo "== Test count drift =="
# Static count: `func test…` methods in XCTestCase + `@Test` attributes for
# Swift Testing. Note: xcodebuild's runtime count may differ when XCTest
# auto-generates parameterised tests — the static count is an order-of-
# magnitude check, not exact. When in doubt, run `xcodebuild test` and
# update README from "Executed NNN tests".
STATIC_FUNC=$(grep -rE '^\s*func test[A-Z]' Tests/ 2>/dev/null | wc -l | tr -d ' ')
STATIC_ATTR=$(grep -rE '^\s*@Test' Tests/ 2>/dev/null | wc -l | tr -d ' ')
STATIC_TOTAL=$((STATIC_FUNC + STATIC_ATTR))
echo "  static count (func test… + @Test): $STATIC_TOTAL"

README_CLAIM=$(grep -oE '[0-9]+/[0-9]+ tests passing' README.md 2>/dev/null | head -1)
if [[ -n "$README_CLAIM" ]]; then
    README_NUM=$(echo "$README_CLAIM" | cut -d/ -f1)
    DIFF=$((README_NUM - STATIC_TOTAL))
    [[ $DIFF -lt 0 ]] && DIFF=$((0 - DIFF))
    # Warn only if static < README significantly. Static is a lower bound
    # because XCTest auto-generates extra tests; static > README would be
    # very strong evidence of drift, < would be ambiguous.
    if [[ $STATIC_TOTAL -gt $README_NUM ]]; then
        warn "README.md says '$README_CLAIM' but static count is $STATIC_TOTAL — README is stale (under-reporting)"
    elif [[ $DIFF -gt 50 ]]; then
        warn "README.md claims $README_NUM but static count is only $STATIC_TOTAL — verify by running xcodebuild test"
    else
        note "README.md test count plausible ($README_CLAIM vs static $STATIC_TOTAL)"
    fi
else
    note "README.md has no 'NNN/NNN tests passing' claim to check"
fi

echo "== URL drift =="
# Pages live at spespark.github.io after S29; bj-park.github.io is stale.
# Only flag in surfaces that present URLs as CURRENT facts. Historical
# session logs (ROADMAP / SESSION_HANDOFF / v2-backlog) intentionally
# preserve the original incorrect URLs as audit trail.
CURRENT_SURFACES="README.md project.yml scripts/ .github/"
STALE_URLS=$(grep -rnE 'bj-park\.github\.io' $CURRENT_SURFACES 2>/dev/null | grep -vE 'check_doc_drift\.sh' || true)
if [[ -n "$STALE_URLS" ]]; then
    warn "stale 'bj-park.github.io' references in current surfaces:"
    echo "$STALE_URLS" | sed 's/^/    /'
else
    note "no stale Pages URL references in current surfaces"
fi

echo "== Catalog vs project.yml knownRegions =="
EXPECTED_LANGS=$(awk '/^  knownRegions:/,/^settings:/ {if ($0 ~ /^    - /) print $2}' project.yml | sort -u)
EXPECTED_COUNT=$(echo "$EXPECTED_LANGS" | grep -c .)
CATALOG_LANGS=$(python3 -c '
import json
d = json.load(open("Resources/Localizable.xcstrings"))
langs = set()
for v in d["strings"].values():
    langs.update((v.get("localizations") or {}).keys())
print("\n".join(sorted(langs)))
' 2>/dev/null)
CATALOG_COUNT=$(echo "$CATALOG_LANGS" | grep -c .)
if [[ "$EXPECTED_COUNT" == "$CATALOG_COUNT" ]]; then
    note "catalog covers $CATALOG_COUNT languages (matches project.yml knownRegions)"
else
    warn "project.yml knownRegions has $EXPECTED_COUNT languages, catalog has $CATALOG_COUNT"
    echo "    expected: $(echo $EXPECTED_LANGS | tr '\n' ' ')"
    echo "    catalog:  $(echo $CATALOG_LANGS | tr '\n' ' ')"
fi

echo "== Core layering (02-architecture §3.2) =="
# Core must stay UI-framework-free so it can lift into a SwiftUI-agnostic
# layer for the OQ-04 SwiftData migration (docs/design/10 Phase 2).
CORE_SWIFTUI=$(grep -rln 'import SwiftUI' Sources/Core/ 2>/dev/null || true)
if [[ -n "$CORE_SWIFTUI" ]]; then
    warn "Sources/Core imports SwiftUI — Core must stay UI-free (§3.2):"
    echo "$CORE_SWIFTUI" | sed 's/^/    /'
else
    note "Sources/Core is SwiftUI-free"
fi

echo "== CloudKit isolation (docs/design/10 §10) =="
# CloudKit usage may appear ONLY in the single production adapter
# (CloudKitSyncEngine.swift). The conflict-bearing logic stays pure and
# unit-testable behind the CloudSyncEngine seam — any leak elsewhere is a
# latent "sync the blob" data-loss bug (§6). `import CloudKit` is the gating
# signal (L5, S49 audit): the prior CKContainer/CKDatabase-only grep was
# narrower than the rule — a stray file using CKRecord/CKQuery/CKRecordZone
# without those two tokens would slip through, but it cannot without the import.
CK_LEAK=$(grep -rln 'CKContainer\|CKDatabase\|import CloudKit' Sources/ 2>/dev/null | grep -v 'CloudKitSyncEngine.swift' || true)
if [[ -n "$CK_LEAK" ]]; then
    warn "CloudKit usage (CKContainer/CKDatabase/import CloudKit) outside CloudKitSyncEngine.swift — keep it in the one adapter (§10):"
    echo "$CK_LEAK" | sed 's/^/    /'
else
    note "CloudKit (CKContainer/CKDatabase/import CloudKit) confined to CloudKitSyncEngine.swift"
fi

echo "== Store copy ↔ binary truth (S51 Track C regression guard) =="
# S51 found the S45 metadata claiming features the binary doesn't ship — two
# near-certain 2.3.1 rejections (SIX triggers incl. Focus; CSV/JSON export
# removed in S24). This block pins the store copy to the binary so a future
# session can't "fix" it back. SUBMITTED = fields pasted into ASC.
SUBMITTED=$(ls docs/store/description-*.md docs/store/whats-new-*.md \
    docs/store/promotional-text-*.txt docs/store/keywords-*.txt \
    docs/store/subtitle-*.txt docs/store/app-name.txt 2>/dev/null)

# Binary truth: active (non-commented) trigger registrations. FocusTrigger is
# a commented-out line until V2-03b, so it doesn't count.
TRIG_COUNT=$(awk '/private func registerDefaultTriggers/,/^    \}/' \
    Sources/App/AppEnvironment.swift 2>/dev/null \
    | grep -cE '^\s*coordinator\.register\(' || true)
if [[ "$TRIG_COUNT" == "5" ]]; then
    note "binary registers 5 triggers (FocusTrigger commented out — V2-03b)"
else
    warn "binary registers $TRIG_COUNT triggers but store copy says FIVE — update docs/store/* AND this check together"
fi

# Wrong-count claims in submitted copy — the count word must be ADJACENT to
# the trigger word ("6가지 커피 톤" is legitimate accent-tone copy, not a claim).
SIX_CLAIM=$(grep -rinE '(six|6) ?(smart )?triggers?|(6가지|여섯 가지|여섯 개의?) ?(스마트 )?트리거|트리거 (6가지|여섯)' $SUBMITTED /dev/null 2>/dev/null || true)
if [[ -n "$SIX_CLAIM" ]]; then
    warn "submitted copy claims six triggers — binary ships five (Focus = V2-03b):"
    echo "$SIX_CLAIM" | sed 's/^/    /'
else
    note "no six-trigger claim in submitted copy"
fi

# Focus must not appear in SUBMITTED fields at all (privacy-data/review-notes
# may legitimately explain that Focus is NOT shipped — they are excluded).
FOCUS_CLAIM=$(grep -rinE 'focus|포커스|집중 모드' $SUBMITTED /dev/null 2>/dev/null || true)
if [[ -n "$FOCUS_CLAIM" ]]; then
    warn "Focus mentioned in submitted copy — FocusTrigger is NOT registered in v1.0 (V2-03b):"
    echo "$FOCUS_CLAIM" | sed 's/^/    /'
else
    note "no Focus claim in submitted copy"
fi

# Export was removed in S24 (0e13546) — any export claim is a 2.3.1 risk.
EXPORT_CLAIM=$(grep -rinE '\bcsv\b|\bjson\b|export|내보내기|내보내' $SUBMITTED /dev/null 2>/dev/null || true)
if [[ -n "$EXPORT_CLAIM" ]]; then
    warn "export (CSV/JSON) claimed in submitted copy — feature was removed in S24:"
    echo "$EXPORT_CLAIM" | sed 's/^/    /'
else
    note "no export claim in submitted copy"
fi

# 2.3.7 — third-party brands in keyword metadata, competitor app names in
# submitted copy + review-notes. "Zoom" in the description BODY (app-trigger
# explanation) is legitimate; the brand restriction bites in keywords.
# "caffeinated" as an English adjective is deliberately not matched.
BRAND_KW=$(grep -rinE 'zoom|teams|webex|slack|discord' docs/store/keywords-*.txt 2>/dev/null || true)
COMPETITOR=$(grep -rinE 'amphetamine|keepingyouawake' $SUBMITTED docs/store/review-notes.md /dev/null 2>/dev/null || true)
if [[ -n "$BRAND_KW" || -n "$COMPETITOR" ]]; then
    warn "third-party brand/competitor names in metadata (2.3.7):"
    { echo "$BRAND_KW"; echo "$COMPETITOR"; } | grep . | sed 's/^/    /'
else
    note "no third-party brands in keywords, no competitor names in submitted copy"
fi

# Unused-API usage string: NSFocusStatusUsageDescription must stay out of
# Info.plist until V2-03b actually calls INFocusStatusCenter.
if grep -q 'NSFocusStatusUsageDescription' Resources/Info.plist 2>/dev/null; then
    warn "NSFocusStatusUsageDescription present in Info.plist but INFocusStatusCenter is not called (re-add only with V2-03b)"
else
    note "Info.plist has no unused Focus usage string"
fi

echo "== App Store field char limits =="
# Apple rejects over-limit listing fields at submit time (S45: description-en
# had silently grown ~690 chars over the 4000 cap). Delegate to the dedicated
# checker so over-cap drift fails this gate instead of surfacing at submission.
if STORE_OUT=$(scripts/check_store_limits.sh --strict 2>&1); then
    note "all App Store fields within Apple character limits"
else
    warn "App Store field(s) over Apple's character limit (run scripts/check_store_limits.sh):"
    echo "$STORE_OUT" | grep -E '✗' | sed 's/^/    /'
fi

echo "== Summary =="
if [[ $DRIFT -eq 0 ]]; then
    echo "  no drift detected ✓"
    exit 0
fi
echo "  $DRIFT drift item(s) found"
if [[ $STRICT -eq 1 ]]; then
    exit 1
fi
exit 0
