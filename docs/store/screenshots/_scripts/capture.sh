#!/usr/bin/env bash
# Non-destructive marketing capture for Latte (S50). Produces 7 raw window
# PNGs in /tmp/latte-shots (English UI), then RESTORES all app state:
#   - defaults domain (backed up/restored)
#   - sandbox-container activity-log.json (backed up/restored)
# Needs Screen Recording + Accessibility for the capturing process.
set -uo pipefail

APP="/Users/parkbyeongjun/Library/Developer/Xcode/DerivedData/Latte-cgxustegptpqtqaarpshkphoradn/Build/Products/Debug/Latte.app"
BID="com.araforge.latte"
LIB="$HOME/dev/smoke-harness/lib"
OUT="/tmp/latte-shots"
DBAK="/tmp/latte-defaults-backup.plist"
CLOG="$HOME/Library/Containers/$BID/Data/Library/Application Support/Latte/activity-log.json"
CBAK="/tmp/latte-activitylog-container-backup.json"
mkdir -p "$OUT"

quit(){ osascript -e 'tell application "Latte" to quit' >/dev/null 2>&1; pkill -x Latte >/dev/null 2>&1; sleep 1; }
cap(){ # <title> <out>
  local wid; wid="$(bash "$LIB/find_window.sh" "Latte" "$1" 2>/dev/null || true)"
  [[ -n "$wid" ]] && screencapture -l "$wid" -o -x -t png "$2" 2>/dev/null && echo "  OK  $1 -> $(basename "$2")" || echo "  MISS $1"
}
# capture the menu-bar popover (empty title) by largest Latte window
cap_popover(){ # <out>
  local wid
  wid="$(swift - <<'SWIFT' 2>/dev/null
import AppKit
let raw = CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements], kCGNullWindowID) as! [[String:Any]]
for w in raw where ((w[kCGWindowOwnerName as String] as? String) ?? "")=="Latte" {
  let b=w[kCGWindowBounds as String] as? [String:Any] ?? [:]
  let wd=(b["Width"] as? Double) ?? 0, ht=(b["Height"] as? Double) ?? 0
  if wd>100 && ht>200 { print(w[kCGWindowNumber as String] as? Int ?? -1); break }
}
SWIFT
)"
  [[ -n "$wid" ]] && screencapture -l "$wid" -o -x -t png "$1" 2>/dev/null && echo "  OK  popover -> $(basename "$1")" || echo "  MISS popover"
}

echo "== backup defaults + container activity log =="
quit
defaults export "$BID" "$DBAK"
[[ -f "$CLOG" ]] && cp "$CLOG" "$CBAK"

echo "== A: onboarding language picker (English, first-run) =="
quit
defaults delete "$BID" latte.firstRunCompleted 2>/dev/null
defaults write "$BID" AppleLanguages -array en
defaults write "$BID" latte.coffeeAccent -string caramel
open -a "$APP"; sleep 5
cap "Welcome to Latte" "$OUT/A-language.png"; quit

echo "== settings + cup + menubar + activity (first-run done, English) =="
defaults write "$BID" latte.firstRunCompleted -bool true
defaults write "$BID" AppleLanguages -array en
defaults write "$BID" latte.coffeeAccent -string caramel
defaults write "$BID" latte.calendarTrigger.enabled -bool true
defaults write "$BID" latte.appTrigger.enabled -bool true
defaults write "$BID" latte.wifiTrigger.enabled -bool true

# cup hero + 6 accent cups (demo window updates its content in place)
quit; open -a "$APP"; sleep 3
open -a "$APP" "latte://demo/cup?fill=0.55&accent=caramel&awake=true"; sleep 4
cap "Latte Demo Cup" "$OUT/1-cup.png"
for ac in espresso caramel mocha latte matcha noir; do
  open -a "$APP" "latte://demo/cup?fill=0.7&accent=$ac&awake=true"; sleep 2.5
  cap "Latte Demo Cup" "$OUT/cup-$ac.png"
done

# settings tabs (relaunch per tab so initialTab is honored)
for tab in general triggers about; do
  quit; open -a "$APP"; sleep 2
  open -a "$APP" "latte://settings/$tab"; sleep 4
  cap "Latte Settings" "$OUT/$tab.png"
done
mv -f "$OUT/general.png"  "$OUT/2-general.png"
mv -f "$OUT/triggers.png" "$OUT/3-triggers.png"
mv -f "$OUT/about.png"    "$OUT/5-about.png"

# menu-bar popover in the ACTIVE (awake) state — activateOnLaunch makes the
# app hold the assertion on launch (indefinite), so the popover shows
# "Latte is awake" / Indefinitely ✓ / Turn off enabled. Needs an
# Accessibility status-item click to open.
quit
defaults write "$BID" latte.activateOnLaunch -bool true
open -a "$APP"; sleep 4
osascript -e 'tell application "System Events" to tell process "Latte" to click menu bar item 1 of menu bar 2' >/dev/null 2>&1
sleep 1.5
cap_popover "$OUT/M-menubar-awake.png"
quit
defaults write "$BID" latte.activateOnLaunch -bool false

# activity tab — seed synthetic, privacy-safe history into the CONTAINER log
quit
python3 - "$CLOG" <<'PY'
import json,os,sys,time,uuid,random
random.seed(42); F=sys.argv[1]; now=time.time(); DAY=86400; e=[]
def add(ts,t,k,r): e.append({"id":str(uuid.uuid4()).upper(),"timestamp":round(ts,3),"triggerId":t,"kind":k,"reasonCode":r})
def s(start,dur,t): add(start,t,"on","voteOn"); add(start+dur,t,"off","voteOff")
for d in range(14,-1,-1):
    b=now-d*DAY; dow=time.localtime(b).tm_wday; m=b-(b%DAY)
    if dow<5:
        s(m+9*3600+random.randint(-600,600),3*3600,"schedule")
        for h in (10,14,16):
            if random.random()<0.6: s(m+h*3600+random.randint(0,1800),random.choice([1800,2700,3600]),"calendar")
        if random.random()<0.7: s(m+13*3600,random.randint(1800,5400),"app")
    elif random.random()<0.5: s(m+20*3600,random.randint(3600,7200),"wifi")
s(now-3*3600,3600,"calendar"); s(now-6*3600,2*3600,"app"); add(now-1800,"wifi","on","voteOn")
e.sort(key=lambda x:x["timestamp"]); json.dump(e,open(F,"w")); print(f"  seeded {len(e)} activity entries")
PY
open -a "$APP"; sleep 2
open -a "$APP" "latte://settings/activity"; sleep 4
cap "Latte Settings" "$OUT/4b-activity.png"
quit

echo "== RESTORE app state =="
defaults delete "$BID" >/dev/null 2>&1; defaults import "$BID" "$DBAK"
[[ -f "$CBAK" ]] && cp "$CBAK" "$CLOG" || printf '[]' > "$CLOG"
echo "  defaults + activity log restored"
ls -la "$OUT"/*.png
