---
tags: [hub]
updated: 2026-10-18
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
| `tools/` | MCP and upload scripts |

## Delivery reports
- [[HOS-LOBBY-001 Plaza]]: lobby Ground_Plaza made one checkered, studded brick (2026-10-18).
