# ScriptHistory

Read-only copies of every script in the Hatch or Snatch place, so Git shows what each ticket changed. Never edit these files; Studio is the source of truth.

## Taking a snapshot (after any ticket that edits scripts)
1. Through the Studio MCP, run `execute_luau` on the Hatch or Snatch place to list every `Script`, `LocalScript` and `ModuleScript` (skip `CoreGui`, `CorePackages` and plugin folders) with its full path and `Source`.
2. Write each one to `ScriptHistory/<Service>/<path>.lua`, one folder per parent (e.g. `ServerScriptService/Services/EggService.lua`). Delete files whose script no longer exists.
3. Commit with the ticket id: `HOS-XXX-000: script snapshot`.

## Coverage so far
- No full baseline yet: the place has 94 scripts (about 1.1 million characters), too much to copy through the Studio MCP in one go. Until a full snapshot is taken (in batches, or by exporting from Hunter's PC), each ticket snapshots only the scripts it changed.
- HOS-ABIL-001 (15 Oct 2026): `ServerStorage/EOSBuild/PetShowroom/FWPPetData.lua` (nine ability families). Pre-edit copy: `docs/backups/HOS-ABIL-001_2026-10-15/`.
- HOS-UI-IMPORT-001 (16 Oct 2026): `StarterPlayer/StarterPlayerScripts/EOS/Controllers/UIController.lua` (new UI controller; source of truth `roblox/game/UIController.luau`), `ServerScriptService/EOS/Services/PlayerService.lua` (accepts the `uiColour` setting), `ServerScriptService/EOS/Services/DataService.lua` (today's quests stored on load). Pre-edit copies: `docs/backups/HOS-UI-IMPORT-001_2026-10-16/`.
