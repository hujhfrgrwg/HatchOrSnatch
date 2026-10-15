# ScriptHistory

Read-only copies of every script in the Hatch or Snatch place, so Git shows what each ticket changed. Never edit these files; Studio is the source of truth.

## Taking a snapshot (after any ticket that edits scripts)
1. Through the Studio MCP, run `execute_luau` on the Hatch or Snatch place to list every `Script`, `LocalScript` and `ModuleScript` (skip `CoreGui`, `CorePackages` and plugin folders) with its full path and `Source`.
2. Write each one to `ScriptHistory/<Service>/<path>.lua`, one folder per parent (e.g. `ServerScriptService/Services/EggService.lua`). Delete files whose script no longer exists.
3. Commit with the ticket id: `HOS-XXX-000: script snapshot`.
