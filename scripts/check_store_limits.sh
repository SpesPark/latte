#!/usr/bin/env bash
# Assert App Store Connect listing fields stay under Apple's character limits.
#
# Background (S45 lesson): `description-en.md` had silently grown ~690 chars
# OVER Apple's 4000-char cap across several sessions before anyone counted.
# App Store Connect rejects over-limit fields at submit time — but only the
# owner sees that, long after the copy was written. This codifies the
# per-locale char-count audit so over-cap drift fails CI instead of
# surfacing at submission.
#
# Counting convention (matches Apple): Unicode code points, with trailing
# newlines stripped (the trailing newline is not part of the pasted field).
# Korean syllables count as 1 character each, so byte counts (`wc -c`) would
# overcount — we count code points via python3.
#
# Usage:
#   scripts/check_store_limits.sh           # report-only (always exit 0)
#   scripts/check_store_limits.sh --strict  # exit 1 on any over-limit/missing field
#
# Run from repo root.

set -uo pipefail

STRICT=0
[[ "${1:-}" == "--strict" ]] && STRICT=1

python3 - "$STRICT" <<'PY'
import sys, os

strict = sys.argv[1] == "1"
STORE = "docs/store"

# field file -> Apple character limit (per locale). Fields with no char limit
# (category, pricing, URLs, privacy, age-rating, review-notes) are not checked.
limits = {
    "app-name.txt": 30,
    "subtitle-en.txt": 30, "subtitle-ko.txt": 30,
    "promotional-text-en.txt": 170, "promotional-text-ko.txt": 170,
    "keywords-en.txt": 100, "keywords-ko.txt": 100,
    "description-en.md": 4000, "description-ko.md": 4000,
    "whats-new-en.md": 4000, "whats-new-ko.md": 4000,
}

over = 0
missing = 0
print("== App Store field char limits ==")
for fname, lim in limits.items():
    path = os.path.join(STORE, fname)
    if not os.path.exists(path):
        print(f"  ✗ {fname:26} MISSING")
        missing += 1
        continue
    with open(path, encoding="utf-8") as fh:
        n = len(fh.read().rstrip("\n"))
    if n > lim:
        print(f"  ✗ {fname:26} {n:>5}/{lim}  OVER by {n - lim}")
        over += 1
    else:
        print(f"  ✓ {fname:26} {n:>5}/{lim}")

print("== Summary ==")
if over == 0 and missing == 0:
    print("  all fields within Apple limits ✓")
    sys.exit(0)
print(f"  {over} over-limit, {missing} missing")
sys.exit(1 if strict else 0)
PY