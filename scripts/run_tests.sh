#!/usr/bin/env bash
#
# run_tests.sh — `xcodebuild test` runner that retries the trap #8 no-assertion
# stall, and ONLY that stall.
#
# trap #8 (see docs/SESSION_HANDOFF.md + the project_latte_status memory): the
# full suite intermittently stalls on a main-actor hop with NO assertion text and
# 0 failures, surfacing as `** TEST FAILED **`. It is a harness-level,
# load-dependent stall, NOT a product bug — the S46 static task-spawn audit found
# no remaining uncancelled long-lived Task leak (the S41/S44 leak fixes are in).
# The documented mitigation has always been "re-run on a no-assertion FAILED".
# This script codifies that manual step so CI and local runs are deterministic.
#
# CRITICAL SAFETY PROPERTY: a *real* failure is NEVER retried — only the
# zero-assertion stall is. The classifier fails fast (exit 1, no retry) on any
# individual `Test Case ... failed`, a nonzero failure summary, a build failure,
# or a pty-exhaustion launch error (trap #9, which a reboot fixes — retrying it
# would only burn more ptys). Masking a real red would be far worse than the
# flake it is meant to absorb.
#
# Decisions are made from the authoritative `** TEST SUCCEEDED/FAILED **` line in
# the captured log, NOT from a pipe's exit code (pipefail + tee would report tee).
#
# Usage:
#   scripts/run_tests.sh [extra xcodebuild args...]
#   scripts/run_tests.sh --classify <logfile>   # self-test: print PASS|FAIL|STALL|PTY
#
# Env:
#   LATTE_SCHEME         (default: Latte)
#   LATTE_DESTINATION    (default: platform=macOS,arch=arm64)
#   LATTE_TEST_ATTEMPTS  (default: 3) — max attempts; bounded well under the ~25
#                        back-to-back runs that exhaust ptys (trap #9).

set -uo pipefail

SCHEME="${LATTE_SCHEME:-Latte}"
DESTINATION="${LATTE_DESTINATION:-platform=macOS,arch=arm64}"
MAX_ATTEMPTS="${LATTE_TEST_ATTEMPTS:-3}"

# classify_log <logfile> → echoes one of: PASS | FAIL | STALL | PTY
#   PASS  — `** TEST SUCCEEDED **`.
#   FAIL  — a real, deterministic failure (assertion / nonzero failure count /
#           build failure). Never retried.
#   PTY   — pty exhaustion (trap #9): the runner could not launch. A reboot or
#           re-login fixes it; retrying only burns more ptys, so never retried.
#   STALL — `** TEST FAILED **` (or a killed/absent result line) with zero
#           assertion evidence = the trap #8 no-assertion stall. Safe to retry.
classify_log() {
    local log="$1"
    [[ -f "$log" ]] || { echo STALL; return; }

    if grep -q '\*\* TEST SUCCEEDED \*\*' "$log"; then
        echo PASS; return
    fi
    # trap #9: runner failed to launch (orphaned /dev/ttys nodes). Reboot, not retry.
    if grep -qE 'Pseudo Terminal Setup Error|Device not configured|openpty' "$log"; then
        echo PTY; return
    fi
    # Deterministic build failure — never retry.
    if grep -qE '\*\* BUILD FAILED \*\*|Testing cancelled because the build failed|^[^ ].*error: ' "$log"; then
        echo FAIL; return
    fi
    # A genuine assertion failure (per-case or nonzero summary) — never retry.
    if grep -qE "Test Case '.*' failed" "$log"; then
        echo FAIL; return
    fi
    if grep -qE 'Executed [0-9]+ test.*, with [1-9][0-9]* failure' "$log"; then
        echo FAIL; return
    fi
    # `** TEST FAILED **` with no assertion evidence (or no result line at all)
    # = the trap #8 no-assertion stall.
    echo STALL
}

# --classify mode: pure log classification, no build. Used by the self-test and
# handy for debugging a CI artifact.
if [[ "${1:-}" == "--classify" ]]; then
    if [[ $# -ne 2 ]]; then
        echo "usage: $0 --classify <logfile>" >&2
        exit 2
    fi
    classify_log "$2"
    exit 0
fi

# --- live run --------------------------------------------------------------

# Pre-flight pty check: if exhausted, fail immediately with the fix (reboot), do
# not even attempt (the launch would error and waste a pty).
if ! python3 -c "import os;[os.close(x) for x in os.openpty()]" 2>/dev/null; then
    echo "✗ pty exhausted (trap #9) — reboot or log out/in before running tests." >&2
    echo "  killing testmanagerd / sysctl does NOT help (orphaned /dev/ttys nodes)." >&2
    exit 1
fi

LOG="$(mktemp -t latte-test.XXXXXX.log)"
trap 'rm -f "$LOG"' EXIT

attempt=1
while (( attempt <= MAX_ATTEMPTS )); do
    echo "── test attempt ${attempt}/${MAX_ATTEMPTS} ──"
    # Pre-flight: kill any stale Latte before each attempt (PRE-FLIGHT protocol).
    pkill -9 -f "Latte.app" 2>/dev/null || true
    sleep 1

    # A stale result bundle makes the next xcodebuild error with "already exists",
    # which would turn a retry into a spurious failure. Clear the path passed via
    # -resultBundlePath before each attempt so retries stay clean.
    prev=""
    for a in "$@"; do
        [[ "$prev" == "-resultBundlePath" ]] && rm -rf "$a"
        prev="$a"
    done

    set -o pipefail
    xcodebuild test \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        "$@" 2>&1 | tee "$LOG" | tail -8
    set +o pipefail

    verdict="$(classify_log "$LOG")"
    case "$verdict" in
        PASS)
            echo "✓ TEST SUCCEEDED (attempt ${attempt})"
            exit 0
            ;;
        FAIL)
            echo "✗ TEST FAILED — real failure (assertion or build). Not retrying." >&2
            exit 1
            ;;
        PTY)
            echo "✗ pty exhausted mid-run (trap #9) — reboot/relogin, not retry." >&2
            exit 1
            ;;
        STALL)
            echo "⚠ no-assertion stall (trap #8) on attempt ${attempt}." >&2
            if (( attempt < MAX_ATTEMPTS )); then
                echo "  retrying…" >&2
            fi
            ;;
    esac
    (( attempt++ ))
done

echo "✗ no-assertion stall persisted across ${MAX_ATTEMPTS} attempts (trap #8)." >&2
echo "  this exceeds the historical flake rate — investigate, do not just re-run." >&2
exit 1
