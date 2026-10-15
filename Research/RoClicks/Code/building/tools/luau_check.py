#!/usr/bin/env python3
"""Syntax-check every .luau file under a folder with the standalone `luau` CLI, without running it.

Why: pushing a script with a syntax error into Studio fails quietly (the push "succeeds"; the error
only shows in the output log when something requires it). Checking on disk first takes a second and
catches typos, unbalanced `end`s, and Luau's "Ambiguous syntax" error when a line starts with `(`.

How it works: each file is copied to a temp file with `do return end` prepended, so the CLI parses
and compiles the whole file but executes nothing (no Roblox globals needed). Line numbers in the
output are shifted back by one to match your file. A leading `--!` directive line is kept first
(errors on that line itself would be reported as line 1 either way).

Install the CLI from https://github.com/luau-lang/luau/releases (or `brew install luau`).
Usage: python3 luau_check.py [folder ...]     (default: current folder)
Exit code 1 if any file has errors, so it can gate a push script or CI.
"""
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def main():
    if not shutil.which("luau"):
        sys.exit("the `luau` CLI is not on PATH")
    roots = [Path(a) for a in sys.argv[1:]] or [Path(".")]
    files = sorted(f for r in roots for f in (r.rglob("*.luau") if r.is_dir() else [r]))
    bad = 0
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td) / "check.luau"
        for f in files:
            lines = f.read_text().split("\n")
            # keep a --! directive on line 1 (e.g. --!strict) so it still applies
            if lines and lines[0].startswith("--!"):
                text = lines[0] + "\ndo return end\n" + "\n".join(lines[1:])
            else:
                text = "do return end\n" + "\n".join(lines)
            shift = 1
            tmp.write_text(text)
            r = subprocess.run(["luau", str(tmp)], capture_output=True, text=True)
            out = (r.stdout + r.stderr).strip()
            if not out:
                continue
            bad += 1
            out = out.replace(str(tmp), str(f))
            out = re.sub(rf"{re.escape(str(f))}:(\d+)",
                         lambda m: f"{f}:{max(1, int(m.group(1)) - shift)}", out)
            out = re.sub(r"\bline (\d+)", lambda m: f"line {max(1, int(m.group(1)) - shift)}", out)
            print(f"--- {f}\n{out}")
    print(f"{len(files)} file(s), {bad} with errors")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
