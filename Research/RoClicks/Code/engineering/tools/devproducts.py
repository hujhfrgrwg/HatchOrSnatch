#!/usr/bin/env python3
"""List and create Roblox developer products with an Open Cloud API key, without ever printing the key.

Usage:
  python3 devproducts.py list   --universe <universeId>
  python3 devproducts.py create --universe <universeId> --spec products.json [--dry-run]

The key is read from a file (default ~/.roblox_api_key, override with --key-file or $ROBLOX_KEY_FILE).
The file must be chmod 600; the script refuses otherwise. The key is never taken from argv (it would land in
shell history and `ps`), never printed, and never written into logs.

products.json:
  [ {"name": "Coins Pack S", "description": "1,000 coins", "price": 49, "image": "icons/coins_s.png"}, ... ]
Products whose name already exists in the universe are skipped, so re-running is safe.
The output is a name -> productId map: paste it into your Products config (an unconfigured id stays 0 = inert).

Endpoints (Open Cloud, header x-api-key):
  GET  https://apis.roblox.com/developer-products/v2/universes/{universeId}/developer-products/creator?pageSize=50
       (follow nextPageToken via &pageToken=...)
  POST https://apis.roblox.com/developer-products/v2/universes/{universeId}/developer-products
       multipart/form-data: name, description, price, isForSale, imageFile (optional)
The key needs developer-product read + write for that universe (for a group game, create the key under the group).
"""
import argparse
import json
import mimetypes
import os
import stat
import sys
import urllib.error
import urllib.request
import uuid
from pathlib import Path

BASE = "https://apis.roblox.com/developer-products/v2/universes/{u}/developer-products"


def read_key(path: str) -> str:
    p = Path(os.path.expanduser(path))
    if not p.exists():
        sys.exit(f"no key file at {p} (create it, then chmod 600)")
    mode = stat.S_IMODE(p.stat().st_mode)
    if mode & 0o077:
        sys.exit(f"{p} is readable by others (mode {oct(mode)}); run: chmod 600 {p}")
    key = p.read_text().strip()
    if not key:
        sys.exit(f"{p} is empty")
    return key


def request(method, url, key, body=None, ctype=None):
    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("x-api-key", key)
    if ctype:
        req.add_header("Content-Type", ctype)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        # print the status and Roblox's message only; the request (and key) is never echoed
        sys.exit(f"{method} failed: HTTP {e.code} {e.read()[:400].decode('utf-8', 'replace')}")


def list_products(universe, key):
    out, token = [], ""
    while True:
        url = BASE.format(u=universe) + "/creator?pageSize=50" + (f"&pageToken={token}" if token else "")
        page = request("GET", url, key)
        out += page.get("developerProducts", [])
        token = page.get("nextPageToken")
        if not token:
            return out


def multipart(fields: dict, file_path=None):
    boundary = uuid.uuid4().hex
    parts = []
    for k, v in fields.items():
        parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode())
    if file_path:
        data = Path(file_path).read_bytes()
        mt = mimetypes.guess_type(file_path)[0] or "application/octet-stream"
        parts.append((f'--{boundary}\r\nContent-Disposition: form-data; name="imageFile"; '
                      f'filename="{Path(file_path).name}"\r\nContent-Type: {mt}\r\n\r\n').encode() + data + b"\r\n")
    parts.append(f"--{boundary}--\r\n".encode())
    return b"".join(parts), f"multipart/form-data; boundary={boundary}"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("cmd", choices=["list", "create"])
    ap.add_argument("--universe", required=True)
    ap.add_argument("--spec")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--key-file", default=os.environ.get("ROBLOX_KEY_FILE", "~/.roblox_api_key"))
    a = ap.parse_args()
    key = read_key(a.key_file)

    existing = list_products(a.universe, key)
    by_name = {p.get("name"): p.get("productId") for p in existing}
    if a.cmd == "list":
        for p in existing:
            print(f'{p.get("productId")}\t{p.get("price") or p.get("priceInformation")}\t{p.get("name")}')
        return 0

    if not a.spec:
        sys.exit("create needs --spec products.json")
    result = {}
    for spec in json.loads(Path(a.spec).read_text()):
        name = spec["name"]
        if name in by_name:
            result[name] = by_name[name]
            print(f"exists  {name} -> {by_name[name]}")
            continue
        if a.dry_run:
            print(f"would create {name} ({spec['price']} Robux)")
            continue
        body, ctype = multipart({"name": name, "description": spec.get("description", ""),
                                 "price": str(int(spec["price"])), "isForSale": "true"}, spec.get("image"))
        made = request("POST", BASE.format(u=a.universe), key, body, ctype)
        result[name] = made.get("productId")
        print(f"created {name} -> {result[name]}")
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
