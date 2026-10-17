---
tags: [dev, ui]
updated: 2026-10-17
ticket: HOS-RET-001
---
# HOS-RET-001 install steps (retention prompts)

Run on Hunter's PC in `C:\HatchOrSnatch`, branch `claude/project-thread-s21b8j`, against the Studio place **"Hatch or Snatch"** (place id 128015050187408) only. Design: [[Retention Prompts]].

Workflow rules (shared with other threads): claim shared scripts in `/mnt/project-files/workflow/edit-claims.md` (or tell the cloud thread to) before editing, small line edits only, one self-closing playtest at a time (claim `PLAYTEST`), never save or publish the place.

## 1. Upload the art
```
python tools/upload/upload_assets.py --list Assets/UI/retention_upload_list.json
```
29 panel images (`Assets/UI/retention/*.png`) plus Hunter's gift icon (`Assets/UI/icons/gift_daily.png`). Ids land in `Assets/asset_ids.json` (decal ids).

## 2. Resolve decal ids to image ids (in Studio)
For each new decal id, load it in Studio (`InsertService:LoadAsset(id)`, read the Decal's `Texture`) and append `decal=image` lines to `Assets/UI/resolved_image_ids.txt`. Then:
```
python tools/upload/retention_ids.py      # writes roblox/ui_retention/AssetIds.luau, fails if anything is missing
cd ui_ret && python ../.claude/skills/roblox-ui-maker/scripts/bundle.py   # -> ui_ret/rbx/out/RetentionUIBuild.rbxmx
```

## 3. Back up, then import
Back up to `docs/backups/HOS-RET-001_2026-10-17/`: `ServerScriptService.EOS.Bootstrap` and `StarterPlayer.StarterPlayerScripts.EOS.ClientMain` (the only shared scripts touched).

New instances (all new, nothing replaced):
| Source | Goes to | Class |
|---|---|---|
| `roblox/game/RetentionConfig.luau` | `ReplicatedStorage.EOS.Shared.RetentionConfig` | ModuleScript |
| `roblox/game/RetentionService.luau` | `ServerScriptService.EOS.Services.RetentionService` | ModuleScript |
| `roblox/game/RetentionController.luau` | `StarterPlayer.StarterPlayerScripts.EOS.Controllers.RetentionController` | ModuleScript |
| `RetentionUIBuild.rbxmx` | `ServerStorage` | Folder |

Wrap each `.luau` with `.claude/skills/roblox-ui-maker/scripts/luau_to_rbxmx.py` and `import_rbxm` it. Never `set_script_source`.

Build the gui: `require(game.ServerStorage.RetentionUIBuild.Builder).build()`, set `StarterGui.RetentionUI.Enabled = true`, run `.fit()` twice, then set `Enabled = false`.

## 4. Two one-line hooks
- Bootstrap, after `PassService.init()`: `require(Services.RetentionService).init() -- HOS-RET-001 welcome back gift, favorite / event / starter prompts`
- ClientMain, after `UIController.init()` (and after SpectateController sets `UIController.spectating`): `task.spawn(require(Controllers.RetentionController).init, UIController) -- HOS-RET-001`

## 5. Check
Self-closing playtests (one at a time), at 1920x1080, 1366x768 and 844x390:
- A fresh profile gets no gift on day one. After the first finished match, back in the lobby, the "Come back tomorrow" card shows with Roblox's favorite prompt on top.
- A profile with `retention.firstDay` set to an earlier day gets the CLAIM card a few seconds after spawning. CLAIM adds 250 Gold + 2 Gems once and flips the card to the countdown. A second claim is refused.
- A lobby player during CROSSING (not in the match, with a pet) sees the waiting card bottom right, cycling VIP and 2x XP. The X hides it for the session. Players in the match never see it.
- No prompt opens while another panel is open or the player is in a match.

Then take a ScriptHistory snapshot (`ScriptHistory/README.md`).
