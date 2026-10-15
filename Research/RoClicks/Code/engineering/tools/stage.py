#!/usr/bin/env python3
"""Stage source files for a base-compare push into Roblox Studio.

Usage:
  python3 stage.py --name Stage_FixA_3 [--out build] "<StudioPath>=<file>[@<baseFile>|@NEW]" ...

  StudioPath  slash-separated DataModel path of the target script, e.g.
              ServerScriptService/Game/Services/Data
  file        the edited source on disk
  @baseFile   the Studio source you pulled and edited on top of (apply refuses if live != base)
  @NEW        the script must not exist yet (apply creates it; class from the file suffix:
              *.server.luau -> Script, *.client.luau -> LocalScript, else ModuleScript)
  no @        overwrite without a base check (only for files nobody else edits)

Writes <out>/<name>.rbxmx: a Folder <name> holding one ModuleScript per target, named by its path.
A target with a base gets a child ModuleScript "Base"; a new one gets a StringValue "New" whose Value is the class.
Import the file with import_rbxm into ServerStorage, then run stage_apply.luau with STAGE_NAME = <name>.

Use a unique --name per agent and per push: a shared "Stage" folder lets agents apply each other's files.
"""
import argparse
import sys
from pathlib import Path


def esc(s: str) -> str:
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")


def cdata(s: str) -> str:
    # "]]>" cannot appear inside CDATA: split it across two sections
    return "<![CDATA[" + s.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def class_for(path: Path) -> str:
    n = path.name
    if n.endswith(".server.luau") or n.endswith(".server.lua"):
        return "Script"
    if n.endswith(".client.luau") or n.endswith(".client.lua"):
        return "LocalScript"
    return "ModuleScript"


class Refs:
    def __init__(self):
        self.n = 0

    def next(self) -> str:
        self.n += 1
        return f"RBX{self.n}"


def module(refs: Refs, name: str, source: str, kids: str = "") -> str:
    return (f'<Item class="ModuleScript" referent="{refs.next()}"><Properties>'
            f'<string name="Name">{esc(name)}</string>'
            f'<ProtectedString name="Source">{cdata(source)}</ProtectedString>'
            f'</Properties>{kids}</Item>')


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--name", required=True, help="unique stage folder name, e.g. Stage_<agent>_<n>")
    ap.add_argument("--out", default="build", help="output directory (default: build)")
    ap.add_argument("items", nargs="+")
    a = ap.parse_args()

    refs = Refs()
    root_ref = refs.next()
    items = []
    for arg in a.items:
        if "=" not in arg:
            sys.exit(f"bad item (want Path=file[@base]): {arg}")
        target, rest = arg.split("=", 1)
        file_part, _, base = rest.partition("@")
        src_path = Path(file_part)
        source = src_path.read_text(encoding="utf-8")
        kid = ""
        if base == "NEW":
            kid = (f'<Item class="StringValue" referent="{refs.next()}"><Properties>'
                   f'<string name="Name">New</string><string name="Value">{class_for(src_path)}</string>'
                   f'</Properties></Item>')
        elif base:
            kid = module(refs, "Base", Path(base).read_text(encoding="utf-8"))
        items.append(module(refs, target, source, kid))

    out_dir = Path(a.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    out = out_dir / f"{a.name}.rbxmx"
    out.write_text(
        f'<roblox version="4"><Item class="Folder" referent="{root_ref}"><Properties>'
        f'<string name="Name">{esc(a.name)}</string></Properties>' + "".join(items) + "</Item></roblox>\n",
        encoding="utf-8")
    print(f"staged {len(items)} file(s) -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
