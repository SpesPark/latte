#!/bin/bash
#
# scripts/latte-resume.sh
#
# Cold-start ritual for resuming Latte work in a new Claude Code session.
# Bundles the SESSION_HANDOFF.md cold-start commands into one invocation
# with a tight status summary.
#
# Usage:
#   bash scripts/latte-resume.sh             # from project root
#   latte                                    # if aliased (see footer)
#
# Exit codes:
#   0 = all green (tests not run, but state is healthy)
#   1 = critical drift (Pages 404, dirty tree on main, missing remote)

set +e  # don't fail-fast — we want to report state, not abort on first miss

PROJECT="$HOME/Documents/Claude/Projects/Latte"
if [ ! -d "$PROJECT" ]; then
    echo "❌ $PROJECT not found. Clone first:"
    echo "   git clone https://github.com/SpesPark/latte.git $PROJECT"
    exit 1
fi
cd "$PROJECT" || exit 1

# Colors (TTY-aware)
if [ -t 1 ]; then
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    OK=$'\033[32m'
    WARN=$'\033[33m'
    FAIL=$'\033[31m'
    RESET=$'\033[0m'
else
    BOLD=""; DIM=""; OK=""; WARN=""; FAIL=""; RESET=""
fi

exit_code=0

echo "${BOLD}🍵 Latte resume${RESET}  ${DIM}($PROJECT)${RESET}"
echo

# ── 1. Zombie cleanup ─────────────────────────────────────────────────────
killed=$(pgrep -f "Latte.app" 2>/dev/null | wc -l | tr -d ' ')
if [ "$killed" -gt 0 ]; then
    pkill -9 -f "Latte.app" 2>/dev/null
    echo "${OK}✓${RESET} Killed $killed zombie Latte process(es)"
else
    echo "${DIM}-${RESET} No zombie Latte processes"
fi

# ── 2. Git state ──────────────────────────────────────────────────────────
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
status=$(git status --short)
echo
echo "${BOLD}Branch:${RESET} $branch"
if [ -z "$status" ]; then
    echo "${OK}✓${RESET} Working tree clean"
else
    echo "${WARN}⚠${RESET} Uncommitted changes:"
    echo "$status" | head -10 | sed 's/^/    /'
fi

echo
echo "${BOLD}Recent commits:${RESET}"
git log --oneline -5 | sed 's/^/  /'

# ── 3. Remote + Pages ─────────────────────────────────────────────────────
echo
remote=$(git remote get-url origin 2>/dev/null)
if [ -z "$remote" ]; then
    echo "${FAIL}✗${RESET} No origin remote configured"
    exit_code=1
else
    echo "${OK}✓${RESET} origin: $remote"
fi

landing=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 https://spespark.github.io/latte/)
privacy=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 https://spespark.github.io/latte/privacy.html)
if [ "$landing" = "200" ] && [ "$privacy" = "200" ]; then
    echo "${OK}✓${RESET} Pages live: / = $landing, /privacy.html = $privacy"
else
    echo "${FAIL}✗${RESET} Pages drift: / = $landing, /privacy.html = $privacy"
    exit_code=1
fi

# ── 4. Xcode project ──────────────────────────────────────────────────────
echo
if [ -d Latte.xcodeproj ]; then
    echo "${OK}✓${RESET} Latte.xcodeproj present"
else
    echo "${WARN}⚠${RESET} Latte.xcodeproj missing — generating via xcodegen..."
    if command -v xcodegen >/dev/null 2>&1; then
        xcodegen generate >/dev/null 2>&1 && echo "${OK}✓${RESET} Generated"
    else
        echo "${FAIL}✗${RESET} xcodegen not installed (brew install xcodegen)"
        exit_code=1
    fi
fi

# ── 5. i18n catalog ───────────────────────────────────────────────────────
catalog="Resources/Localizable.xcstrings"
if [ -f "$catalog" ]; then
    keys=$(python3 -c "import json; print(len(json.load(open('$catalog'))['strings']))" 2>/dev/null || echo "?")
    ko_count=$(python3 -c "
import json
d = json.load(open('$catalog'))
n = sum(1 for k in d['strings'] if d['strings'][k].get('localizations', {}).get('ko', {}).get('stringUnit', {}).get('value'))
print(n)
" 2>/dev/null || echo "?")
    echo "${OK}✓${RESET} i18n catalog: $keys keys ($ko_count with ko)"
else
    echo "${DIM}-${RESET} i18n catalog not yet created"
fi

# ── 6. Owner-side pending (from SESSION_HANDOFF.md) ───────────────────────
echo
echo "${BOLD}Owner-side pending:${RESET}"
if [ -f docs/SESSION_HANDOFF.md ]; then
    awk '/^## Owner-side pending/,/^---$/' docs/SESSION_HANDOFF.md \
        | grep -E '^\| (S[0-9]|i18n|\*\*ko)' \
        | sed 's/^|/  /' \
        | sed 's/|/│/g' \
        | head -6
else
    echo "${DIM}  (SESSION_HANDOFF.md not found)${RESET}"
fi

# ── 7. Next entry points ──────────────────────────────────────────────────
echo
echo "${BOLD}Next-session entry points:${RESET}"
if [ -f docs/SESSION_HANDOFF.md ]; then
    awk '/^## Next-session entry points/,/^---$/' docs/SESSION_HANDOFF.md \
        | grep -E '^\*\*[0-9]' \
        | head -4 \
        | sed 's/^\*\*/  /' \
        | sed 's/\*\*//'
else
    echo "${DIM}  (SESSION_HANDOFF.md not found)${RESET}"
fi

# ── 8. Quick action menu ──────────────────────────────────────────────────
echo
echo "${BOLD}Quick actions:${RESET}"
cat <<EOF
  ${DIM}# Run full test suite (~9s)${RESET}
  xcodebuild test -scheme Latte -destination 'platform=macOS,arch=arm64' 2>&1 | grep "Executed"

  ${DIM}# Run smoke harness (~6-7min, SERIAL with xcodebuild)${RESET}
  ~/dev/smoke-harness/run.sh --project .

  ${DIM}# Start Claude Code in this directory${RESET}
  claude

  ${DIM}# Open project in Xcode${RESET}
  open Latte.xcodeproj

  ${DIM}# Re-read full handoff${RESET}
  cat docs/SESSION_HANDOFF.md | less
EOF

echo
if [ $exit_code -eq 0 ]; then
    echo "${OK}🍵 Ready.${RESET}"
else
    echo "${FAIL}🍵 Drift detected — see warnings above.${RESET}"
fi

exit $exit_code
