#!/usr/bin/env python3
"""Extract the exact Source of every script in a binary Roblox model (.rbxm) or place (.rbxl).

Why: when a collaborator edits scripts live in Studio, Studio is the source of truth. Reading a
script back through an MCP "get source" call can reformat it, truncate it, or flood the agent's
context. Instead, export the subtree to a binary .rbxm (an export tool, or right-click > Save to
File), then run this. You get byte-exact files on disk to diff, edit, and use as the "base" for
stage_rbxmx.py.

Usage: python3 rbxm_src.py file.rbxm outdir
Writes outdir/<Parent>/<Child>/<Script>.luau for every instance with a Source property.
Pure Python; chunks compressed with zstd need `pip install zstandard` (LZ4 is built in).

Format notes (Roblox binary format): a 32-byte header, then chunks of
  name[4] compressedLen[u32] uncompressedLen[u32] reserved[4] body
INST maps a class id to its instance referents, PROP holds one property for every instance of a
class, PRNT holds (child, parent) referent pairs. Integer arrays are byte-interleaved, zigzag
encoded, and referents are delta-accumulated.
"""
import os
import struct
import sys

try:
    import zstandard
except ImportError:
    zstandard = None


def lz4_block(src: bytes) -> bytes:
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


def interleaved_ints(raw: bytes, count: int):
    vals = []
    for k in range(count):
        b = bytes([raw[k], raw[count + k], raw[2 * count + k], raw[3 * count + k]])
        v = int.from_bytes(b, "big")
        vals.append((v >> 1) ^ -(v & 1))  # zigzag
    return vals


def referents(raw: bytes, count: int):
    acc, out = 0, []
    for v in interleaved_ints(raw, count):
        acc += v
        out.append(acc)
    return out


def read_chunks(data: bytes):
    if data[:8] != b"<roblox!":
        sys.exit("not a binary Roblox file (XML .rbxmx files are plain text: just read them)")
    p = 32
    while p < len(data):
        name = data[p:p + 4]
        clen, ulen = struct.unpack("<II", data[p + 4:p + 12])
        p += 16
        if clen == 0:
            body = data[p:p + ulen]; p += ulen
        else:
            raw = data[p:p + clen]; p += clen
            if raw[:4] == b"\x28\xb5\x2f\xfd":
                if not zstandard:
                    sys.exit("this file uses zstd chunks: pip install zstandard")
                body = zstandard.ZstdDecompressor().decompress(raw, max_output_size=ulen)
            else:
                body = lz4_block(raw)
        if name == b"END\0":
            break
        yield name, body


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    data = open(sys.argv[1], "rb").read()
    classes, names, sources, parents = {}, {}, {}, {}

    for name, body in read_chunks(data):
        if name == b"INST":
            cid, ln = struct.unpack("<II", body[:8])
            q = 8 + ln + 1  # class name, then the "is service" byte
            cnt, = struct.unpack("<I", body[q:q + 4]); q += 4
            classes[cid] = referents(body[q:q + 4 * cnt], cnt)
        elif name == b"PRNT":
            cnt, = struct.unpack("<I", body[1:5]); q = 5
            kids = referents(body[q:q + 4 * cnt], cnt); q += 4 * cnt
            pars = referents(body[q:q + 4 * cnt], cnt)
            parents.update(zip(kids, pars))
        elif name == b"PROP":
            cid, ln = struct.unpack("<II", body[:8])
            pname = body[8:8 + ln].decode()
            q = 8 + ln
            ptype = body[q]; q += 1
            if pname not in ("Name", "Source") or ptype != 1:  # 1 = string
                continue
            target = names if pname == "Name" else sources
            for r in classes.get(cid, []):
                sl, = struct.unpack("<I", body[q:q + 4]); q += 4
                target[r] = body[q:q + sl]; q += sl

    def path(r):
        parts = []
        while r is not None and r >= 0 and r in names:
            parts.append(names[r].decode(errors="replace").replace("/", "_"))
            r = parents.get(r)
        return "/".join(reversed(parts))

    seen = set()
    for r, src in sources.items():
        rel = path(r) or f"ref{r}"
        if rel in seen:  # two siblings with the same name: keep both
            rel = f"{rel}__ref{r}"
        seen.add(rel)
        fn = os.path.join(sys.argv[2], rel + ".luau")
        os.makedirs(os.path.dirname(fn), exist_ok=True)
        with open(fn, "wb") as f:
            f.write(src)
        print(f"{len(src):>8}  {fn}")
    print(f"{len(sources)} script(s)")


if __name__ == "__main__":
    main()
