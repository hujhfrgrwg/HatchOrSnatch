#!/usr/bin/env python3
"""Stage Luau files for a safe per-module push into Roblox Studio.

Each argument is   <StudioPath>=<file.luau>[@<base.luau> | @NEW]

  StudioPath  dot path of the target script, e.g. ReplicatedStorage.Game.Shared.Layers
              (the first segment is a service name)
  file.luau   the new source you want live
  @base.luau  the Studio source you pulled and edited on top of (base-compare)
  @NEW        the script must NOT exist yet

Output: one .rbxmx holding Folder <stage name> with a ModuleScript per file. Its Name is the target
path; a child ModuleScript "Base" (or StringValue "New") carries the base. Import the file into
ServerStorage (an import-from-disk tool, or drag it in), then run stage_apply.luau in Studio. That
script refuses the WHOLE push if any live source has changed since its base, so you never overwrite
a collaborator's live edit.

Why a model file instead of a "set script source" tool call: some MCP transports turn the two
characters \\n inside string literals into real newlines, which breaks the script with
"Malformed string" while the push reports success. An .rbxmx goes from disk to Studio untouched,
and the source never passes through the agent's context a second time.

Usage:
  python3 stage_rbxmx.py [-o out.rbxmx] [-n StageName] Path.To.Script=src/x.luau@pulled/x.luau ...
"""
import argparse
import sys
from pathlib import Path
from xml.sax.saxutils import escape


def cdata(s: str) -> str:
    # "]]>" cannot appear inside CDATA; split it across two sections
    return "<![CDATA[" + s.replace("]]>", "]]]]><![CDATA[>") + "]]>"


class Refs:
    def __init__(self):
        self.n = 0

    def __call__(self) -> str:
        self.n += 1
        return f"RBX{self.n}"


def module(ref, name, source, children=""):
    return (f'<Item class="ModuleScript" referent="{ref()}"><Properties>'
            f'<string name="Name">{escape(name)}</string>'
            f'<ProtectedString name="Source">{cdata(source)}</ProtectedString>'
            f'</Properties>{children}</Item>')


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("items", nargs="+", help="StudioPath=file.luau[@base.luau|@NEW]")
    ap.add_argument("-o", "--out", default="build/Stage.rbxmx")
    ap.add_argument("-n", "--name", default="Stage", help="folder name; must match STAGE in stage_apply.luau")
    args = ap.parse_args()

    ref = Refs()
    root = ref()
    items = []
    for arg in args.items:
        if "=" not in arg:
            sys.exit(f"bad item (want Path=file): {arg}")
        target, spec = arg.split("=", 1)
        base = None
        if "@" in spec:
            spec, base = spec.split("@", 1)
        src = Path(spec).read_text()
        kid = ""
        if base == "NEW":
            kid = (f'<Item class="StringValue" referent="{ref()}"><Properties>'
                   f'<string name="Name">New</string></Properties></Item>')
        elif base:
            kid = module(ref, "Base", Path(base).read_text())
        items.append(module(ref, target, src, kid))

    out = (f'<roblox version="4"><Item class="Folder" referent="{root}"><Properties>'
           f'<string name="Name">{escape(args.name)}</string></Properties>'
           + "".join(items) + "</Item></roblox>")
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text(out)
    print(f"staged {len(items)} file(s) -> {args.out}")


if __name__ == "__main__":
    main()
