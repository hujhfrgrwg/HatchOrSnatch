---
tags: [research, roclicks]
source: https://roclicks.gg/resources/building/push-pull-check-tools
retrieved: 2026-10-15
---
# Tools: pushing, pulling and checking code

All tools are in tools/ and are game-agnostic: no paths are baked in.

- [[#Why not just "set script source"?]]
- [[#The loop]]
- [[#stage_rbxmx.py + stage_apply.luau]]
- [[#rbxm_src.py]]
- [[#luau_check.py]]
- [[#Other habits]]
- [[#Checklist]]

All tools are in `tools/` and are game-agnostic: no paths are baked in.

## Why not just "set script source"?

An agent can write a script's source through an MCP tool call. Three things go wrong:

1.  **Escapes get mangled.** Some transports turn the two characters `\n` inside a Luau string literal into a real newline. The script then fails with "Malformed string" at a line that looks fine, while the push reported success. The error only shows in the runtime log.
2.  **It overwrites live edits.** If a collaborator changed that script in Studio since you last read it, their work is gone without a word.
3.  **It costs context.** Every push sends the full source through the conversation again.

A model file (`.rbxmx`, plain XML) imported from disk avoids all three: bytes go disk → Studio untouched, and the import carries the base you edited on, so Studio can refuse a stale push.

## The loop

    pull     export the live scripts to .rbxm  →  rbxm_src.py  →  pulled/   (byte-exact)
    edit     copy pulled/X.luau to src/X.luau and edit it
    check    luau_check.py src/
    stage    stage_rbxmx.py Path.To.X=src/X.luau@pulled/X.luau ...  →  build/Stage.rbxmx
    import   import build/Stage.rbxmx into ServerStorage
    apply    run stage_apply.luau in Studio  →  "ok ..." or "CONFLICT, nothing applied"

On a conflict: pull again, merge your change onto the new live source, and repeat. Never force.

## stage_rbxmx.py + stage_apply.luau

`stage_rbxmx.py` packs any number of files into one folder model:

    python3 tools/stage_rbxmx.py -o build/Stage.rbxmx \
      ReplicatedStorage.Game.Shared.Layers=src/shared/Layers.luau@pulled/Layers.luau \
      StarterPlayer.StarterPlayerScripts.Game.Controllers.Picking=src/client/Picking.luau@NEW

- `@base.luau` = the live source you edited on top of.
- `@NEW` = the script must not exist yet (it is created as a ModuleScript).
- No `@` = blind overwrite. Only use it on scripts nobody else touches.

`stage_apply.luau` (run it with an `execute_luau` tool or the command bar):

- A target **conflicts** if its live source equals neither the base nor the new source.
- **Any conflict aborts the whole push.** A half-applied set of modules that require each other is worse than none.
- Reports `ok` / `same` per item and always deletes the stage folder.
- Applying the same stage twice is safe (`same`).

Remember: `require` caches. A playtest started after the apply sees the new code; a module already required in an edit-mode session doesn't. For edit-mode tests of an edited module, require a fresh clone or rename it (`Kit_v2`).

## rbxm_src.py

Pulls the exact source of every script out of a binary `.rbxm` / `.rbxl`.

    python3 tools/rbxm_src.py exports/Scripts.rbxm pulled/

- Output mirrors the instance tree: `pulled/ReplicatedStorage/Game/Shared/Layers.luau`.
- Duplicate sibling names get a `__refN` suffix instead of overwriting each other.
- Handles LZ4 chunks natively; zstd chunks need `pip install zstandard`.
- Use it as the "snapshot" for read-only reviewers too: reviewers read files on disk and make zero Studio calls, so many can run in parallel without touching the live session.

## luau_check.py

    python3 tools/luau_check.py src/

- Compiles every `.luau` with the standalone `luau` CLI after a `do return end` prefix, so nothing runs and Roblox globals don't matter.
- Catches syntax errors, unbalanced blocks, and **"Ambiguous syntax"** (a line starting with `(` right after a function call line; add a `;` to the previous line).
- Exit code 1 on any error: chain it before staging (`luau_check.py src && stage_rbxmx.py ...`).
- It does not type-check against Roblox APIs. Pair it with a short playtest and a read of the runtime log after every push.

## Other habits

- **Bundle builders as model files too.** A builder module plus its helpers goes in one `.rbxmx` folder in ServerStorage; run it with `require(...).build()`. Re-runnable builds are fixable builds.
- **Edit-mode tests with a mock player.** When playtests are slow or the bridge is wedged, `require` the services in edit mode and drive them with a mock player table (`GetAttribute`, `SetAttribute`, `FindFirstChild`, `Character`).
- **Plain-Luau tests for pure modules.** Keep formulas, world generation and scale math free of Roblox types so the `luau` CLI can run their tests on disk in milliseconds.
- **Keep execute_luau calls short** (\< ~15-20 s) and return compact strings; a long loop times out and the result is lost.
- **After a timeout, check the request status before retrying.** A timed-out call may still have run; retrying a non-idempotent build doubles it.
- **Don't launch fresh Studio instances from tools** if it has proven flaky: stray processes can survive and stop the real Studio from rendering or playtesting. Ask the developer to open a new place instead.
- **Remind the developer to save.** Pushes change the open place only. Note "File \> Save needed" in every report.

## Checklist

- Pulled the live source before editing anything a collaborator may have touched.
- `luau_check.py` clean.
- Staged with `@base` (or `@NEW`), applied with base-compare, no conflicts.
- Short playtest, runtime log read, no new errors.
- Developer told to save.

Previous: [[Verifying maps and models]] · Next: [[Stud-style surfaces that look intentional]]
