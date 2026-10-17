---
tags: [hub]
updated: 2026-10-16
---
# Hatch or Snatch Home

Start page for the project. Agents read this first (see `CLAUDE.md`).

## The game
*Not written yet.* The one-paragraph pitch, core loop and target players go here, then a `Hatch or Snatch Game Plan.md` and a `Hatch or Snatch Decisions.md` (one line per decision Hunter makes, with the date).

## Studio place
| | |
|---|---|
| Place name | Hatch or Snatch |
| Place id / universe id | 128015050187408 / *(fill in)* |
| Owner | Group 228184582 |

## Setup
- **Studio MCP:** `.mcp.json` points at Hunter's ngrok tunnel; cloud sessions need `ROBLOX_MCP_TOKEN` in their environment. On the PC: `tools\mcp\start_mcp_server.ps1` (server and Studio plugin must be the same version, 3.2.1).
- **Uploads:** `tools\upload\upload_assets.py` (Open Cloud; key and creator from the environment). On the PC, Hunter's `ROBLOX_OPEN_CLOUD_API_KEY` works for the group (pass it as `HOS_ROBLOX_API_KEY` for the one process, group 228184582). Open Cloud returns Decal ids: resolve the Image id with `InsertService:LoadAsset(decalId)` before using it in a GUI.
- **Skills and research:** [[RoClicks Index]].

## Design
- [[Emote Light Constructs]]: Destiny-style glowing props for the 13 emotes that mime one (scythe, surfboard, toilet, cart, ...). In the place since 2026-10-16: templates `ReplicatedStorage.EOS_EmoteFX`, client `Controllers.EmoteFX`; playtest owed.

## UI
- [[Emote Crate Spin]]: emote crate opening animation (HTML in `UI/web/`, client script in `UI/roblox/`). In the place since 2026-10-16 as `StarterGui.EmoteCrateUI`, played by EmoteController.

## Folders
| Folder | For |
|---|---|
| `Design/`, `Dev/`, `Assets/`, `UI/` | Design notes, technical notes, asset lists, UI notes |
| `Research/` | Reference material (RoClicks guides and code) |
| `docs/` | Delivery reports, reference images; `docs/backups/` for pre-edit backups |
| `ScriptHistory/` | Read-only snapshots of the place's scripts |
| `tools/` | MCP and upload scripts |
