"""Upload sounds, images and models to Roblox with Open Cloud. Run on Hunter's PC.

    python tools/upload/upload_assets.py Assets/Audio/Hatch_Pop.ogg Assets/Images/Egg_Icon.png
    python tools/upload/upload_assets.py --list Assets/upload_list.json   # a JSON list of file paths

Settings come from the environment (never printed or saved):
    HOS_ROBLOX_API_KEY   Open Cloud key with asset read/write for the creator below
    HOS_ROBLOX_GROUP_ID  upload to this group, or
    HOS_ROBLOX_USER_ID   upload to this user (used when no group is set)
Results go to Assets/asset_ids.json (file path -> assetId, or the pending operation), so a re-run
only finishes what is missing. Roblox moderates new uploads; ids work in Studio once approved.
Roblox limits audio uploads per month, so upload what was picked, not everything.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
IDS = ROOT / "Assets" / "asset_ids.json"
BASE = "https://apis.roblox.com/assets/v1/"
TYPES = {  # extension -> (assetType, content type)
    ".ogg": ("Audio", "audio/ogg"), ".mp3": ("Audio", "audio/mpeg"), ".wav": ("Audio", "audio/wav"),
    ".flac": ("Audio", "audio/flac"),
    ".png": ("Decal", "image/png"), ".jpg": ("Decal", "image/jpeg"), ".jpeg": ("Decal", "image/jpeg"),
    ".bmp": ("Decal", "image/bmp"), ".tga": ("Decal", "image/tga"),
    ".fbx": ("Model", "model/fbx"), ".rbxm": ("Model", "model/x-rbxm"),
}

key = os.environ.get("HOS_ROBLOX_API_KEY", "").strip()
group = os.environ.get("HOS_ROBLOX_GROUP_ID", "").strip()
user = os.environ.get("HOS_ROBLOX_USER_ID", "").strip()
if not key:
    raise SystemExit("Set HOS_ROBLOX_API_KEY for this process first.")
if not (group or user):
    raise SystemExit("Set HOS_ROBLOX_GROUP_ID (group game) or HOS_ROBLOX_USER_ID (your own account).")
CREATOR = {"groupId": group} if group else {"userId": user}


def call(url, body=None, content_type=None):
    headers = {"x-api-key": key}
    if content_type:
        headers["Content-Type"] = content_type
    try:
        with urllib.request.urlopen(urllib.request.Request(url, data=body, headers=headers), timeout=60) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace").replace(key, "[REDACTED]")
        raise RuntimeError(f"HTTP {e.code}: {detail}") from None


def upload(path):
    asset_type, mime = TYPES[path.suffix.lower()]
    boundary = "HatchOrSnatch" + uuid.uuid4().hex
    meta = {"assetType": asset_type, "displayName": path.stem[:50],
            "description": f"Hatch or Snatch: {path.stem}"[:1000],
            "creationContext": {"creator": CREATOR}}
    body = (f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\nContent-Type: application/json\r\n\r\n'.encode()
            + json.dumps(meta).encode()
            + f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="{path.name}"\r\n'
              f'Content-Type: {mime}\r\n\r\n'.encode()
            + path.read_bytes() + f"\r\n--{boundary}--\r\n".encode())
    return call(BASE + "assets", body, "multipart/form-data; boundary=" + boundary)


def finish(op):
    for _ in range(30):
        r = call(BASE + op)
        if r.get("done"):
            return r
        time.sleep(2)
    return None


def main():
    args = sys.argv[1:]
    if args[:1] == ["--list"] and len(args) == 2:
        files = json.loads((ROOT / args[1]).read_text())
    else:
        files = args
    if not files:
        raise SystemExit(__doc__)
    ids = json.loads(IDS.read_text()) if IDS.exists() else {}
    for f in files:
        path = (ROOT / f).resolve()
        name = str(path.relative_to(ROOT)).replace("\\", "/")
        if not path.exists() or path.suffix.lower() not in TYPES:
            print(f"skip {f}: missing or unsupported type")
            continue
        entry = ids.get(name, {})
        if entry.get("assetId"):
            continue
        try:
            if not entry.get("operation"):
                entry = {"operation": upload(path).get("path", "")}
                ids[name] = entry
                IDS.parent.mkdir(parents=True, exist_ok=True)
                IDS.write_text(json.dumps(ids, indent=1))
            done = finish(entry["operation"]) if entry.get("operation", "").startswith("operations/") else None
            if done and done.get("response", {}).get("assetId"):
                entry["assetId"] = done["response"]["assetId"]
                entry.pop("operation", None)
                print(f"{name}: {entry['assetId']}")
            else:
                print(f"{name}: still processing, re-run later to collect the id")
        except RuntimeError as e:
            print(f"{name}: {e}")
            if "429" in str(e) or "quota" in str(e).lower():
                print("Upload limit hit; stopping. Re-run after the limit resets.")
                break
        ids[name] = entry
        IDS.parent.mkdir(parents=True, exist_ok=True)
        IDS.write_text(json.dumps(ids, indent=1))
        time.sleep(1)
    print(f"Saved to {IDS.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
