"""Write roblox/ui_retention/AssetIds.luau for the RetentionUI (HOS-RET-001).

    python tools/upload/retention_ids.py

Reads the upload ledger (Assets/asset_ids.json, decal ids) and Assets/UI/resolved_image_ids.txt
(decal=image lines, resolved in Studio). Icons the main UI already uses keep their ids from
roblox/ui/AssetIds.luau. Exits non-zero if any image is still missing.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
UI = ROOT / "ui_ret"
L = json.load(open(UI / "rbx/out/upload_list.json"))
ledger = json.load(open(ROOT / "Assets/asset_ids.json"))
resolved = {}
for line in (ROOT / "Assets/UI/resolved_image_ids.txt").read_text().split():
    if "=" in line:
        d, i = line.split("=", 1)
        resolved[d.strip()] = i.strip()
main = (ROOT / "roblox/ui/AssetIds.luau").read_text()
main_icons = dict(re.findall(r'\["([^"]+)"\] = "(rbxassetid://\d+)"', main.split("art = {")[0]))


def image_id(path):
    e = ledger.get(path) or {}
    d = str(e.get("assetId", "")) if isinstance(e, dict) else ""
    return f"rbxassetid://{resolved[d]}" if d in resolved else None


out, missing = {}, []
for a in L["art"]:
    v = image_id(f"Assets/UI/retention/{a}.png")
    (out.__setitem__(f"art:{a}", v) if v else missing.append(a))
for i in L["icons"]:
    v = image_id(f"Assets/UI/icons/{i}.png") if i == "gift_daily" else main_icons.get(i)
    (out.__setitem__(f"icon:{i}", v) if v else missing.append(i))
if missing:
    sys.exit("Not uploaded or not resolved yet: " + ", ".join(missing))
json.dump(out, open(UI / "rbx/out/uploaded.json", "w"), indent=1)
subprocess.run([sys.executable, str(ROOT / ".claude/skills/roblox-ui-maker/scripts/assets.py")], cwd=UI, check=True)
