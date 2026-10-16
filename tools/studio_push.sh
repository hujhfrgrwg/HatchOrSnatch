#!/bin/sh
# Bundle the UI for Studio and push it so import_rbxm can load it from GitHub (raw URL by commit sha).
#   tools/studio_push.sh "commit message"     -> prints the commit sha
set -e
cd "$(dirname "$0")/../ui"
SK=../.claude/skills/roblox-ui-maker
python3 $SK/scripts/bundle.py >/dev/null
cp rbx/out/EOSUIBuild.rbxmx ../roblox/build/
python3 $SK/scripts/luau_to_rbxmx.py ../roblox/game/UIController.luau ../roblox/build/UIController.rbxmx UIController ModuleScript >/dev/null
cd ..
git add -A roblox tools ui/build.py ui/styles ui/rbx.json ui/tools Dev docs ScriptHistory Assets >/dev/null 2>&1 || true
git commit -q -m "$1" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RfKJiKr9ePhA7FoxdhhxZp" || true
git push -q origin claude/nifty-carson-ml33ob
git rev-parse HEAD
