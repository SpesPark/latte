#!/usr/bin/env bash
# Latte — Pages live-URL validation (S26 / S8d).
#
# Verifies a deployed GitHub Pages site is reachable and serves both
# the marketing landing page AND the privacy policy. App Store
# submission blocks if the privacy URL is unreachable.
#
# Usage:
#   scripts/validate_pages.sh https://bj-park.github.io/latte/
#   scripts/validate_pages.sh        # auto-derive from gh-pages worktree origin
#
# Checks per URL:
#   1. HTTP 2xx
#   2. content-type starts with text/html
#   3. body contains a non-empty `<title>` tag (sanity check)
#
# Exit codes:
#   0  all checks passed
#   1  precondition failed (no URL, no curl, etc.)
#   2  validation failed (HTTP error, wrong content-type, etc.)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v curl >/dev/null 2>&1; then
  echo "[validate] curl not found in PATH" >&2
  exit 1
fi

BASE_URL="${1:-}"

if [[ -z "$BASE_URL" ]]; then
  STAGING="$REPO_ROOT/../latte-gh-pages-staging"
  if [[ -d "$STAGING" ]]; then
    REMOTE_URL="$(cd "$STAGING" && git remote get-url origin 2>/dev/null || true)"
    if [[ -n "$REMOTE_URL" && "$REMOTE_URL" =~ github.com[:/]([^/]+)/([^./]+)(\.git)?$ ]]; then
      BASE_URL="https://${BASH_REMATCH[1]}.github.io/${BASH_REMATCH[2]}/"
      echo "[validate] auto-derived URL: $BASE_URL"
    fi
  fi
fi

if [[ -z "$BASE_URL" ]]; then
  echo "[validate] usage: $0 <base-url>" >&2
  echo "[validate] e.g.  $0 https://bj-park.github.io/latte/" >&2
  exit 1
fi

# Normalise: ensure trailing slash for base URL joining
BASE_URL="${BASE_URL%/}/"

PAGES=("" "privacy.html")
FAILED=0

for page in "${PAGES[@]}"; do
  url="${BASE_URL}${page}"
  printf '[validate] %s ... ' "$url"

  # -s silent, -L follow redirects, -o stdout body, -w status format
  body="$(mktemp)"
  trap 'rm -f "$body"' EXIT
  status_line="$(curl -sSL --max-time 15 \
                       -o "$body" \
                       -w '%{http_code} %{content_type}' \
                       "$url" 2>/dev/null || echo 'ERR')"

  if [[ "$status_line" == "ERR" ]]; then
    echo "FAIL (curl error)"
    FAILED=$((FAILED+1))
    continue
  fi

  http_code="${status_line%% *}"
  content_type="${status_line#* }"

  if [[ "$http_code" != 2* ]]; then
    echo "FAIL (HTTP $http_code)"
    FAILED=$((FAILED+1))
    continue
  fi

  if [[ "$content_type" != text/html* ]]; then
    echo "FAIL (content-type=$content_type, want text/html)"
    FAILED=$((FAILED+1))
    continue
  fi

  if ! grep -qE '<title>[^<[:space:]]' "$body"; then
    echo "FAIL (empty or missing <title>)"
    FAILED=$((FAILED+1))
    continue
  fi

  echo "OK ($http_code, $content_type)"
done

rm -f "$body" 2>/dev/null || true

if [[ $FAILED -gt 0 ]]; then
  echo "[validate] $FAILED check(s) failed" >&2
  exit 2
fi

echo "[validate] all checks passed — Pages site is App Store submission ready"
