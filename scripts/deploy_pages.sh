#!/usr/bin/env bash
# Latte — Pages deploy script (S26 / S8d).
#
# Syncs `docs/site/{index,privacy}.html` to the pre-staged gh-pages
# worktree (`../latte-gh-pages-staging/`), commits, and pushes if a
# remote is configured. If no remote is set yet the script stops at
# the local commit and prints the one-liner the owner needs to add
# the remote — matches the workflow described in docs/site/README.md.
#
# Usage:
#   scripts/deploy_pages.sh                 # auto: dirty-detect, commit, push
#   scripts/deploy_pages.sh --dry-run       # show what would change, no writes
#   scripts/deploy_pages.sh --message "..." # custom commit message
#
# Exit codes:
#   0  success (or no-op if nothing changed)
#   1  precondition failed (worktree missing, files missing, etc.)
#   2  git operation failed
#
# Owner steps the FIRST time only (one-time setup):
#   gh repo create bj-park/latte --public --source=. --remote=origin --push  # main
#   cd ../latte-gh-pages-staging
#   git remote add origin git@github.com:bj-park/latte.git
#   git push -u origin gh-pages
#   # GitHub repo Settings → Pages → Source = gh-pages branch / root.
#
# Subsequent deploys (after edits in docs/site/):
#   scripts/deploy_pages.sh
#   scripts/validate_pages.sh   # curl 200 check on live URL

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SITE_SRC="$REPO_ROOT/docs/site"
STAGING="$REPO_ROOT/../latte-gh-pages-staging"

DRY_RUN=0
MESSAGE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --message|-m) MESSAGE="${2:-}"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

# --- preconditions ---
if [[ ! -d "$STAGING" ]]; then
  echo "[deploy] gh-pages worktree missing at: $STAGING" >&2
  echo "[deploy] rebuild with: git worktree add --detach ../latte-gh-pages-staging && cd ../latte-gh-pages-staging && git checkout --orphan gh-pages && git rm -rf . && cp $SITE_SRC/{index,privacy}.html . && git add . && git commit -m 'site: rebuild'" >&2
  exit 1
fi

for f in index.html privacy.html; do
  if [[ ! -f "$SITE_SRC/$f" ]]; then
    echo "[deploy] missing source file: $SITE_SRC/$f" >&2
    exit 1
  fi
done

# --- diff source vs staging ---
CHANGES=()
for f in index.html privacy.html; do
  if ! diff -q "$SITE_SRC/$f" "$STAGING/$f" >/dev/null 2>&1; then
    CHANGES+=("$f")
  fi
done

if [[ ${#CHANGES[@]} -eq 0 ]]; then
  echo "[deploy] no changes between docs/site/ and gh-pages staging — nothing to deploy"
  exit 0
fi

echo "[deploy] changed files: ${CHANGES[*]}"

if [[ $DRY_RUN -eq 1 ]]; then
  for f in "${CHANGES[@]}"; do
    echo "--- $f ---"
    diff "$STAGING/$f" "$SITE_SRC/$f" || true
  done
  echo "[deploy] dry-run: no writes, no commit, no push"
  exit 0
fi

# --- copy + commit ---
for f in "${CHANGES[@]}"; do
  cp "$SITE_SRC/$f" "$STAGING/$f"
done

COMMIT_MSG="${MESSAGE:-site: sync ${CHANGES[*]} from docs/site/}"

cd "$STAGING"
git add -- "${CHANGES[@]}"
if ! git commit -m "$COMMIT_MSG"; then
  echo "[deploy] git commit failed" >&2
  exit 2
fi
echo "[deploy] committed: $COMMIT_MSG"

# --- push if remote configured ---
if git remote get-url origin >/dev/null 2>&1; then
  if git push origin gh-pages; then
    echo "[deploy] pushed to origin/gh-pages"
    REMOTE_URL="$(git remote get-url origin)"
    # Best-effort URL guess from origin URL.
    if [[ "$REMOTE_URL" =~ github.com[:/]([^/]+)/([^./]+)(\.git)?$ ]]; then
      OWNER="${BASH_REMATCH[1]}"
      REPO="${BASH_REMATCH[2]}"
      echo "[deploy] live URL (allow ~1-2 min for Pages CDN): https://${OWNER}.github.io/${REPO}/"
      echo "[deploy] verify with: $REPO_ROOT/scripts/validate_pages.sh https://${OWNER}.github.io/${REPO}/"
    fi
  else
    echo "[deploy] git push failed — local commit landed but not pushed" >&2
    exit 2
  fi
else
  echo "[deploy] no 'origin' remote on gh-pages worktree — skipping push"
  echo "[deploy] one-time owner setup:"
  echo "  cd ../latte-gh-pages-staging"
  echo "  git remote add origin git@github.com:bj-park/latte.git"
  echo "  git push -u origin gh-pages"
fi
