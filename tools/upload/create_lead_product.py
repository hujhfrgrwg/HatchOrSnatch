#!/usr/bin/env python3
r"""HOS-LEAD-001: create the "Lead Catcher" developer product (29 Robux) in Hatch or Snatch (universe 10771117139).

Run on Hunter's PC:  python tools\upload\create_lead_product.py
Reads the Open Cloud key from the ROBLOX_OPEN_CLOUD_API_KEY user environment variable (group 228184582 key).
The key is never printed, logged or passed on the command line. Safe to re-run: if a product named
"Lead Catcher" already exists, it prints that id and creates nothing.
Based on Research\RoClicks\Code\engineering\tools\devproducts.py (Open Cloud developer-products v2).
"""
import json
import os
import sys
import urllib.error
import urllib.request
import uuid

UNIVERSE = "10771117139"
NAME = "Lead Catcher"
PRICE = 29
DESCRIPTION = ("Be this match's Lead Catcher. Only one per match; if someone beats you to it, "
               "it's saved for your next match.")
BASE = f"https://apis.roblox.com/developer-products/v2/universes/{UNIVERSE}/developer-products"


def request(method, url, key, body=None, ctype=None):
    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("x-api-key", key)
    if ctype:
        req.add_header("Content-Type", ctype)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        # status and Roblox's message only; the request (and key) is never echoed
        sys.exit(f"{method} failed: HTTP {e.code} {e.read()[:400].decode('utf-8', 'replace')}")


def existing(key):
    out, token = [], ""
    while True:
        page = request("GET", BASE + "/creator?pageSize=50" + (f"&pageToken={token}" if token else ""), key)
        out += page.get("developerProducts", [])
        token = page.get("nextPageToken")
        if not token:
            return out


def main() -> int:
    key = os.environ.get("ROBLOX_OPEN_CLOUD_API_KEY", "").strip()
    if not key:
        sys.exit("ROBLOX_OPEN_CLOUD_API_KEY is not set in this environment")
    for p in existing(key):
        if p.get("name") == NAME:
            print(f"exists  {NAME} -> productId {p.get('productId')}")
            return 0
    boundary = uuid.uuid4().hex
    fields = {"name": NAME, "description": DESCRIPTION, "price": str(PRICE), "isForSale": "true"}
    body = b"".join(f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode()
                    for k, v in fields.items()) + f"--{boundary}--\r\n".encode()
    made = request("POST", BASE, key, body, f"multipart/form-data; boundary={boundary}")
    print(f"created {NAME} ({PRICE} Robux) -> productId {made.get('productId')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
