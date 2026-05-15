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
