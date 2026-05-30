#!/usr/bin/env bash
# Non-destructive marketing capture: backs up Latte defaults, captures 5 window
# shots (English UI incl. the onboarding language picker), then RESTORES defaults.
set -uo pipefail

APP="/Users/parkbyeongjun/Library/Developer/Xcode/DerivedData/Latte-cgxustegptpqtqaarpshkphoradn/Build/Products/Debug/Latte.app"
BID="com.parkbyeongjun.latte"
LIB="$HOME/dev/smoke-harness/lib"
OUT="/tmp/latte-shots"
BACKUP="/tmp/latte-defaults-backup.plist"
mkdir -p "$OUT"

quit() { osascript -e "tell application \"Latte\" to quit" >/dev/null 2>&1; pkill -x Latte >/dev/null 2>&1; sleep 1; }
cap() { # <title> <out>
  local wid; wid="$(bash "$LIB/find_window.sh" "Latte" "$1" 2>/dev/null || true)"
  if [[ -n "$wid" ]]; then
    screencapture -l "$wid" -o -x -t png "$2" 2>/dev/null
    local dim; dim="$(sips -g pixelWidth -g pixelHeight "$2" 2>/dev/null | awk '/pixel/{printf "%s ", $2}')"
    echo "  OK  $1 -> $(basename "$2")  [$dim]"
  else
    echo "  MISS  window '$1' not found"
  fi
}

echo "== backup current defaults =="
quit
defaults export "$BID" "$BACKUP" && echo "  backed up -> $BACKUP"

echo "== Shot A: onboarding LANGUAGE window (English, first-run) =="
quit
defaults delete "$BID" latte.firstRunCompleted 2>/dev/null
defaults write "$BID" AppleLanguages -array en
defaults write "$BID" latte.coffeeAccent -string caramel
open -a "$APP"; sleep 5
cap "Welcome to Latte" "$OUT/A-language.png"
quit

echo "== Shots 1/2/3/5: cup + settings (English, first-run done, some triggers on) =="
defaults write "$BID" latte.firstRunCompleted -bool true
defaults write "$BID" AppleLanguages -array en
defaults write "$BID" latte.coffeeAccent -string caramel
defaults write "$BID" latte.calendarTrigger.enabled -bool true
defaults write "$BID" latte.appTrigger.enabled -bool true
defaults write "$BID" latte.wifiTrigger.enabled -bool true

# Shot 1 — demo cup
quit; open -a "$APP"; sleep 3
open -a "$APP" "latte://demo/cup?fill=0.55&accent=caramel&awake=true"; sleep 4
cap "Latte Demo Cup" "$OUT/1-cup.png"

# Shot 2 — General (relaunch so initialTab is honored)
quit; open -a "$APP"; sleep 2
open -a "$APP" "latte://settings/general"; sleep 4
cap "Latte Settings" "$OUT/2-general.png"

# Shot 3 — Triggers
quit; open -a "$APP"; sleep 2
open -a "$APP" "latte://settings/triggers"; sleep 4
cap "Latte Settings" "$OUT/3-triggers.png"

# Shot 5 — About
quit; open -a "$APP"; sleep 2
open -a "$APP" "latte://settings/about"; sleep 4
cap "Latte Settings" "$OUT/5-about.png"

quit

echo "== RESTORE defaults =="
defaults delete "$BID" >/dev/null 2>&1
defaults import "$BID" "$BACKUP" && echo "  restored from $BACKUP"

echo "== raw captures =="
ls -la "$OUT"/*.png 2>/dev/null
