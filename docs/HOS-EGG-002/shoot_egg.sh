#!/bin/sh
# HOS-EGG-002: render egg_*.html pages to ui/shots with headless Chrome (file:// URLs). Usage: sh shoot_egg.sh [page ...]
cd /c/HatchOrSnatch/ui
CH="/c/Program Files/Google/Chrome/Application/chrome.exe"
UD="C:/Users/hunte/AppData/Local/Temp/claude/C--HatchOrSnatch/09c8057a-706f-449e-aaa2-a0d782bdfd96/scratchpad/chrome_ud"
PAGES="${*:-egg_card_states egg_match egg_roll egg_incubator egg_incubator_focus egg_incubator_ready egg_incubator_hatching egg_incubator_legendary egg_first_pet egg_results egg_results_frames egg_lobby egg_phone egg_compare}"
for n in $PAGES; do
  h=$(grep -o "id='stage' style='height:[0-9]*" $n.html | grep -o '[0-9]*$')
  timeout 60 "$CH" --headless=new --user-data-dir="$UD" --allow-file-access-from-files --disable-gpu --hide-scrollbars --window-size=1920,$h --virtual-time-budget=5000 --screenshot="C:/HatchOrSnatch/ui/shots/$n.png" "file:///C:/HatchOrSnatch/ui/$n.html?raw" >/dev/null 2>&1
  echo "$n $h"
done
