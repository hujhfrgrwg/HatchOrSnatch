---
tags: [hub]
updated: 2026-10-17
---
# Hatch or Snatch Home

Start page for the project. Agents read this first (see `CLAUDE.md`).

## The game
*Not written yet.* The one-paragraph pitch, core loop and target players go here, then a `Hatch or Snatch Game Plan.md` and a `Hatch or Snatch Decisions.md` (one line per decision Hunter makes, with the date).

## Studio place
| | |
|---|---|
| Place name | Hatch or Snatch in Studio; the published place on Roblox is still called "Huss Evolution" |
| Place id / universe id | 128015050187408 / 10771117139 |
| Owner | Group "Eggs with Friends" (228184582) |

## Maps
Arena maps are built from code: `ServerStorage.EOSBuild.Maps` (`MapDefs` plus one `Build<Map>` per map on the shared `ArenaFrame`). Previews sit side by side in `Workspace._MapPreview` along z −390.
- **Haunted Graveyard** (HOS-MAP-001, Matthew): halloween arena, in the map rotation and vote (`ServerStorage.EOS_Maps.Arena_Graveyard`, copied from the workspace preview). See [[HOS-MAP-001 Haunted Graveyard map]].

## Lobby
- **Floating-island underside** (HOS-MAP-002, Matthew): cliff columns under the Halloween lobby, sloping in to a point. See [[HOS-MAP-002 Lobby underside]].
- **Pro altar** (HOS-LOBBY-002, Matthew): small trophy altar in the middle of the plaza (`Workspace.CentralAltar.ProAltar`), rebuildable from `tools/build/HOS-LOBBY-002_pro_altar.lua`. See [[HOS-LOBBY-002 Pro altar]].
- **Edge walls** (HOS-LOBBY-001, Matthew): invisible walls flush with the island's outer edge (`Workspace.LobbyEdgeWalls`) so players can walk to the edge without falling. See [[HOS-LOBBY-001 Lobby edge walls]].
- **Incubator** (HOS-INC-001, Matthew): animated; walking up opens the incubator screen; each player's egg is built from 18 cracked puzzle pieces over a hologram as it fills, earned shards fly in, and hatching bursts it. Egg piece meshes are in `ReplicatedStorage.IncubatorEggPieces`. See [[HOS-INC-001 Incubator]].
- **Leaderboards** (HOS-LB-001, Matthew): the four Halloween boards in `Workspace.Leaderboards` show live this-server stats and turn to face each player. See [[HOS-LB-001 Halloween leaderboards]].

## Setup
- **Studio MCP:** `.mcp.json` points at Hunter's ngrok tunnel; cloud sessions need `ROBLOX_MCP_TOKEN` in their environment. On the PC: `tools\mcp\start_mcp_server.ps1` (server and Studio plugin must be the same version, 3.2.1).
- **Uploads:** `tools\upload\upload_assets.py` (Open Cloud; key and creator from the environment).
- **Skills and research:** [[RoClicks Index]].

## Folders
| Folder | For |
|---|---|
| `Design/`, `Dev/`, `Assets/`, `UI/` | Design notes, technical notes, asset lists, UI notes |
| `Research/` | Reference material (RoClicks guides and code) |
| `docs/` | Delivery reports, reference images; `docs/backups/` for pre-edit backups |
| `ScriptHistory/` | Read-only snapshots of the place's scripts |
| `tools/` | MCP and upload scripts |
