#!/usr/bin/env python3
"""Extract every script's source from a binary .rbxm, byte-exact, laid out by instance path.

Usage:
  python3 rbxm_extract.py <file.rbxm> <outdir>

Get the .rbxm with the robloxstudio MCP's export_rbxm (one call per top-level folder you care about,
e.g. ServerScriptService/Game, ReplicatedStorage/Game, StarterPlayer/StarterPlayerScripts/Game).
Output names follow the common convention: Script -> Name.server.luau, LocalScript -> Name.client.luau,
ModuleScript -> Name.luau. Siblings with the same name get a "~2", "~3" suffix so nothing is overwritten.

This is the snapshot exporter: run it for every folder into snapshot/<date>/ and you have the rollback
point, the reviewers' input and the base files for a base-compare push. No Studio round trip touches the
source text, so escapes and newlines survive exactly (unlike returning .Source through execute_luau).

Handles LZ4 chunks natively and ZSTD chunks if the `zstandard` package is installed.
"""
import os
import struct
import sys


def lz4_block(src: bytes, size: int) -> bytes:
    out = bytearray()
    i = 0
    while i < len(src):
        tok = src[i]; i += 1
        lit = tok >> 4
        if lit == 15:
            while True:
                b = src[i]; i += 1; lit += b
                if b != 255:
                    break
        out += src[i:i + lit]; i += lit
        if i >= len(src):
            break
        off = src[i] | (src[i + 1] << 8); i += 2
        m = tok & 15
        if m == 15:
            while True:
                b = src[i]; i += 1; m += b
                if b != 255:
                    break
        m += 4
        start = len(out) - off
        for k in range(m):
            out.append(out[start + k])
    return bytes(out)


def decompress(raw: bytes, ulen: int) -> bytes:
    if raw[:4] == b"\x28\xb5\x2f\xfd":
        try:
            import zstandard
        except ImportError:
            sys.exit("this .rbxm uses ZSTD chunks: pip install zstandard")
        return zstandard.ZstdDecompressor().decompress(raw, max_output_size=ulen)
    return lz4_block(raw, ulen)


def read_ints(raw: bytes, count: int, accumulate: bool):
    """Interleaved, zigzag-encoded big-endian int32 array (the binary format's referent encoding)."""
    vals = []
    for k in range(count):
        b = bytes([raw[k], raw[count + k], raw[2 * count + k], raw[3 * count + k]])
        v = int.from_bytes(b, "big")
        vals.append((v >> 1) ^ -(v & 1))
    if not accumulate:
        return vals
    acc, out = 0, []
    for v in vals:
        acc += v
        out.append(acc)
    return out


def parse(data: bytes):
    if not data.startswith(b"<roblox!"):
        sys.exit("not a binary .rbxm (an .rbxmx is XML: read it directly)")
    p = 32
    class_of = {}   # referent -> class name
    ids_of = {}     # class id -> referents
    names, sources, parents = {}, {}, {}
    while p < len(data):
        chunk = data[p:p + 4]
        clen, ulen = struct.unpack("<II", data[p + 4:p + 12])
        p += 16
        if clen == 0:
            body = data[p:p + ulen]; p += ulen
        else:
            body = decompress(data[p:p + clen], ulen); p += clen
        if chunk == b"END\0":
            break
        if chunk == b"INST":
            cid, ln = struct.unpack("<II", body[:8])
            cname = body[8:8 + ln].decode()
            q = 8 + ln + 1
            cnt, = struct.unpack("<I", body[q:q + 4]); q += 4
            refs = read_ints(body[q:q + 4 * cnt], cnt, True)
            ids_of[cid] = refs
            for r in refs:
                class_of[r] = cname
        elif chunk == b"PRNT":
            cnt, = struct.unpack("<I", body[1:5])
            q = 5
            kids = read_ints(body[q:q + 4 * cnt], cnt, True); q += 4 * cnt
            pars = read_ints(body[q:q + 4 * cnt], cnt, True)
            parents.update(zip(kids, pars))
        elif chunk == b"PROP":
            cid, ln = struct.unpack("<II", body[:8])
            pname = body[8:8 + ln].decode()
            q = 8 + ln
            ptype = body[q]; q += 1
            if pname in ("Name", "Source") and ptype == 0x01:  # String (Source is a ProtectedString, same layout)
                for r in ids_of[cid]:
                    sl, = struct.unpack("<I", body[q:q + 4]); q += 4
                    (names if pname == "Name" else sources)[r] = body[q:q + sl]; q += sl
    return class_of, names, sources, parents


SUFFIX = {"Script": ".server.luau", "LocalScript": ".client.luau"}


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    class_of, names, sources, parents = parse(open(sys.argv[1], "rb").read())

    def segments(r):
        segs = []
        while r is not None and r >= 0 and r in names:
            segs.append(names[r].decode("utf-8", "replace").replace("/", "_"))
            r = parents.get(r)
        return list(reversed(segs))

    used = set()
    n = 0
    for r, src in sorted(sources.items()):
        segs = segments(r)
        base = os.path.join(sys.argv[2], *segs[:-1], segs[-1])
        fn = base + SUFFIX.get(class_of.get(r, ""), ".luau")
        k = 2
        while fn in used:
            fn = f"{base}~{k}" + SUFFIX.get(class_of.get(r, ""), ".luau"); k += 1
        used.add(fn)
        os.makedirs(os.path.dirname(fn), exist_ok=True)
        with open(fn, "wb") as f:
            f.write(src)
        n += 1
    print(f"extracted {n} script(s) into {sys.argv[2]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
