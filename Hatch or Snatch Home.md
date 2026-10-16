---
tags: [hub]
updated: 2026-10-16
---
# Hatch or Snatch Home

Start page for the project. Agents read this first (see `CLAUDE.md`).

## The game
The game is now called **Evolve or Steal**. This repo, its notes and the `HOS-` ticket ids keep the Hatch or Snatch name.

Evolve or Steal is an 8–16 player infection chase. Runners carry eggs that level up with every safe crossing. Catchers steal those eggs, and every Runner they catch joins them. After each match, players earn one egg material and craft materials into pets, and each pet grants one in-match ability. Gold is the earn-only cosmetic currency and Gems are the premium one. Pets and abilities are never sold.

- **Design doc:** [[Evolve or Steal GDD v0.4 Summary]] (full PDF: `Design/GDD/Evolve or Steal GDD v0.4.pdf`)
- **Decisions:** [[Evolve or Steal Decisions]]
- **UI:** round 3 "sport" is built and wired in Studio (images wait on the asset upload): [[UI Redesign]], [[UI Wiring Map]] (buttons, remotes, data), [[UI Runtime Changes]] (what the controller changes and animates at runtime), [[Emotes Servers Spectate]] (emote wheel and crate, server list, spectate), [[XP and Passes]] (account level, VIP and 2x XP passes)
- **What's built:** [[Studio Place State 2026-10-15]] (latest audit of the Studio place against the GDD)

## Studio place
| | |
|---|---|
| Place name | Hatch or Snatch (current, since 15 Oct 2026; Studio has the Rojo plugin) |
| Place id / universe id | 128015050187408 / 10771117139 |
| Old place | Evolve or Steal Prototype, 92934789398619 / 10770957265 (retired; the audit below was taken there, same EOS code) |
| Owner | *(group or Hunter's account; not checked)* |

## Setup
- **Studio MCP:** `.mcp.json` points at Hunter's ngrok tunnel; cloud sessions need `ROBLOX_MCP_TOKEN` in their environment. On the PC: `tools\mcp\start_mcp_server.ps1` (server and Studio plugin must be the same version, 3.2.1). How-to for someone else: [[Cloud Session to Roblox Studio]] (docs/handoff).
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
