#!/usr/bin/env python3
"""Compare script trees: a Studio snapshot against the disk copy, or a Studio fingerprint against either.

Usage:
  python3 snapshot_diff.py <dirA> <dirB> [--diff]
      Compare two source trees (e.g. snapshot/2026-10-04 vs src). Lists changed / only-in-A / only-in-B.
      --diff prints a unified diff for each changed file.
  python3 snapshot_diff.py --fingerprint <studio_fp.txt> <dir>
      Compare the output of fingerprint.luau (path, bytes, fnv1a32 per script) with a local tree. Tells you
      which scripts changed in Studio since your last pull, without downloading any source.
  python3 snapshot_diff.py --print-fingerprint <dir>
      Print the same fingerprint format for a local tree.

Comparison normalises CRLF to LF. Exit code 1 if anything differs, so it can gate a push script.

Typical use: before editing, fingerprint Studio and diff it against your base copies. Any "changed" file
was edited live by a collaborator; pull it again (export_rbxm + rbxm_extract.py) before you touch it.
"""
import difflib
import sys
from pathlib import Path

EXTS = (".luau", ".lua")


def norm(b: bytes) -> bytes:
    return b.replace(b"\r\n", b"\n")


def fnv1a32(b: bytes) -> int:
    h = 2166136261
    for x in b:
        h ^= x
        h = (h * 16777619) & 0xFFFFFFFF
    return h


def tree(root: Path) -> dict:
    return {p.relative_to(root).as_posix(): norm(p.read_bytes())
            for p in sorted(root.rglob("*")) if p.is_file() and p.suffix in EXTS}


def fingerprint_lines(files: dict):
    return [f"{k}\t{len(v)}\t{fnv1a32(v):08x}" for k, v in sorted(files.items())]


def report(changed, only_a, only_b, label_a, label_b) -> int:
    for k in changed:
        print(f"changed      {k}")
    for k in only_a:
        print(f"only in {label_a:<5}{k}")
    for k in only_b:
        print(f"only in {label_b:<5}{k}")
    print(f"{len(changed)} changed, {len(only_a)} only in {label_a}, {len(only_b)} only in {label_b}")
    return 1 if (changed or only_a or only_b) else 0


def main(argv) -> int:
    if len(argv) >= 2 and argv[0] == "--print-fingerprint":
        print("\n".join(fingerprint_lines(tree(Path(argv[1])))))
        return 0
    if len(argv) >= 3 and argv[0] == "--fingerprint":
        studio = {}
        for line in Path(argv[1]).read_text(encoding="utf-8").splitlines():
            parts = line.strip().split("\t")
            if len(parts) == 3:
                studio[parts[0]] = (int(parts[1]), parts[2].lower())
        local = {k: (len(v), f"{fnv1a32(v):08x}") for k, v in tree(Path(argv[2])).items()}
        changed = [k for k in sorted(studio) if k in local and studio[k] != local[k]]
        return report(changed, sorted(set(studio) - set(local)), sorted(set(local) - set(studio)), "studio", "local")
    if len(argv) >= 2 and not argv[0].startswith("--"):
        a, b = tree(Path(argv[0])), tree(Path(argv[1]))
        changed = [k for k in sorted(a) if k in b and a[k] != b[k]]
        rc = report(changed, sorted(set(a) - set(b)), sorted(set(b) - set(a)), "A", "B")
        if "--diff" in argv:
            for k in changed:
                sys.stdout.writelines(difflib.unified_diff(
                    a[k].decode("utf-8", "replace").splitlines(True), b[k].decode("utf-8", "replace").splitlines(True),
                    f"A/{k}", f"B/{k}"))
        return rc
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
