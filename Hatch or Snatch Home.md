---
tags: [hub]
updated: 2026-10-16
---
# Hatch or Snatch Home

Start page for the project. Agents read this first (see `CLAUDE.md`).

## The game
*Not written yet.* The one-paragraph pitch, core loop and target players go here, then a `Hatch or Snatch Game Plan.md` and a `Hatch or Snatch Decisions.md` (one line per decision Hunter makes, with the date).

- **Economy decisions (16 Oct 2026):** [[Economy Decisions]] in `Design/`, the final calls from the audit.

- **Economy and design audit (16 Oct 2026):** [[Economy Audit 2026-10-16]] in `docs/economy-audit/`. Recommends the Snatch-back egg rule, exactly 3 crossings with 30 players, hour-sized hatch recipes and tighter Gold/Gems. The simulation that backs it is in `tools/sim/`.

## Studio place
| | |
|---|---|
| Place name | *(fill in)* |
| Place id / universe id | *(fill in)* |
| Owner | *(group or Hunter's account)* |

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
| `tools/` | MCP and upload scripts; `tools/sim/` is the economy simulation |
