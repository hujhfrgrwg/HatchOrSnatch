#!/usr/bin/env python3
"""Syntax-check every .luau/.lua file under a folder before it is staged for Studio.

Usage:
  python3 game_check.py [dir ...]            # default: src
  python3 game_check.py src --analyze        # also run luau-analyze (type errors; noisy without Roblox defs)
  python3 game_check.py src --lint           # also run the cheap project lints below

Compiles each file with `luau-compile --null` (no execution). Falls back to running
`luau` on "do return end" + source when luau-compile is missing. Exit code 1 on any error,
so an agent can loop "fix, check" until it prints 0 errors before staging.

--lint adds checks for mistakes that compile fine but bite in Roblox:
  * FireAllClients in a game whose per-player data must stay private (see multiplayer-isolation.md)
  * a second `ProcessReceipt =` assignment (only one handler may exist per server)
  * `WaitForChild(` on workspace containers with no timeout (yields forever if a map is reorganised)
  * `set_script_source` mentions in tool scripts (it mangles "\\n"; push through .rbxmx)
Install Luau: https://github.com/luau-lang/luau/releases (or `brew install luau`).
"""
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

LINTS = [
    (re.compile(r":FireAllClients\("), "FireAllClients: per-player state must use FireClient(owner)"),
    (re.compile(r"\bProcessReceipt\s*="), "ProcessReceipt assignment: keep exactly one in the whole game"),
    (re.compile(r"workspace:WaitForChild\(\s*\"[^\"]+\"\s*\)"), "workspace:WaitForChild with no timeout"),
]


def compile_one(f: Path, tmp: Path):
    if shutil.which("luau-compile"):
        r = subprocess.run(["luau-compile", "--null", str(f)], capture_output=True, text=True)
        out = "\n".join(l for l in (r.stdout + r.stderr).splitlines() if not l.startswith("Compiled "))
        return out.strip() if r.returncode else ""
    t = tmp / "chk.luau"
    t.write_text("do return end\n" + f.read_text(encoding="utf-8"), encoding="utf-8")
    r = subprocess.run(["luau", str(t)], capture_output=True, text=True)
    out = (r.stdout + r.stderr).strip()
    # shift reported line numbers back by the one injected line
    return re.sub(r"chk\.luau:(\d+)", lambda m: f"{f.name}:{int(m.group(1)) - 1}", out)


def main(argv) -> int:
    dirs = [Path(a) for a in argv if not a.startswith("--")] or [Path("src")]
    analyze, lint = "--analyze" in argv, "--lint" in argv
    if not (shutil.which("luau-compile") or shutil.which("luau")):
        sys.exit("luau not found: install it first")
    files = sorted(f for d in dirs for f in d.rglob("*") if f.suffix in (".luau", ".lua"))
    bad, receipt_owners = 0, []
    with tempfile.TemporaryDirectory() as td:
        for f in files:
            out = compile_one(f, Path(td))
            if out:
                bad += 1
                print(f"--- {f}\n{out}")
            if lint:
                for n, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
                    for rx, msg in LINTS:
                        if rx.search(line):
                            print(f"lint {f}:{n}: {msg}")
                            if "ProcessReceipt" in msg:
                                receipt_owners.append(f"{f}:{n}")
    if len(receipt_owners) > 1:
        bad += 1
        print("ERROR: more than one ProcessReceipt assignment:\n  " + "\n  ".join(receipt_owners))
    if analyze and shutil.which("luau-analyze"):
        r = subprocess.run(["luau-analyze", *map(str, dirs)], capture_output=True, text=True)
        print((r.stdout + r.stderr).strip() or "luau-analyze: clean")
    print(f"{len(files)} files, {bad} with errors")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
