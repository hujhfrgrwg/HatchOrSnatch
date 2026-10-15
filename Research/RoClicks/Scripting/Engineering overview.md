---
tags: [research, roclicks]
source: https://roclicks.gg/resources/scripting/overview
retrieved: 2026-10-15
---
# Engineering overview

Systems and workflow for making a Roblox game with one or more AI agents driving Studio through MCP. Every rule names the bug it prevents.

Systems and workflow for making a Roblox game with one or more AI agents driving Studio through MCP. Every rule names the bug it prevents. The examples come from real projects (a kids' strategy tycoon, idle games, an obby), generalised for any game.

## Contents

| Doc                                                                    | Read it when                                                                                                  |
|------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------|
| [[Driving Roblox Studio through MCP|studio-mcp.md]]                       | An agent reads, writes or tests a live Studio place                                                           |
| [[Many agents, one Studio|multi-agent.md]]                     | Several agents (or an agent and a human) work on one place                                                    |
| [[Data and saves|data-and-saves.md]]               | You write or review DataStore saves and product receipts                                                      |
| [[Solo in a shared server games|multiplayer-isolation.md]] | A solo game runs several players per server                                                                   |
| [[Performance|performance.md]]                     | Anything hitches, pops in, or loses taps                                                                      |
| [[Input|input.md]]                                 | Clicks, touch, cameras and hotkeys                                                                            |
| [[Open Cloud creating developer products from a script|open-cloud.md]]                       | You want to create developer products from a script                                                           |
| [[Fix brief template|fix-brief-template.md]]       | You launch parallel fix or review agents                                                                      |
| [[Engineering tools|tools/]]                                   | Stage/apply, snapshot export and diff, game_check, SessionStore + mock-DataStore test, Scheduler, devproducts |

## The ten lessons that paid for themselves

1.  **Never push code through `set_script_source`.** It turns `\n` in string literals into real newlines and the script stops compiling. Write `.rbxmx` to disk and `import_rbxm` it.
2.  **Studio is the source of truth once anyone edits live.** Pull byte-exact before every edit, and push with a base-compare apply that refuses (all-or-nothing) if the script changed since you pulled it.
3.  **Assert the place on line 1 of every mutating script.** The MCP's target window can flip silently.
4.  **`require` in `execute_luau` is cached across calls.** It returns the pre-edit module; read `.Source` or require a clone to verify an edit.
5.  **BindToClose must wait for in-flight saves**, and saves need a session lock in the same key. Without both, the most common session ending (last player leaves) and a fast rejoin both lose progress.
6.  **A transient `502` is not "DataStore is off".** Only Studio's 403 means memory-only; a failed load kicks with a message instead of starting a silent fresh game.
7.  **Solo games in shared servers: build the world on the client, lift server arenas per player, and use `FireClient` only.** Then prove it with a 2-client count of what leaked (should be zero).
8.  **Budget heavy work per frame, and never cancel a release.** Cancelled half-releases orphan models for the whole session.
9.  **Don't rebuild GUIs on a timer.** Re-cloned buttons lose taps; update labels in place.
10. **On a stalled playtest bridge ("queued; not_executed"), retry once and ask for a Studio restart.** Never kill Studio processes you did not start.

## Quick start for a new project

- Name one Studio MCP server in the agent instructions (and the upload exception).
- Pick a landmark for the place and use it in every mutating `execute_luau`.
- Copy `tools/` into the project; wire `game_check.py` into the push loop.
- Start saves from `tools/SessionStore.luau` and keep its test passing.
- Decide early whether the game is "solo in a shared server"; if so, read [[Solo in a shared server games|multiplayer-isolation.md]] before writing the world.
- Keep one append-only change log that every agent re-reads before writing.

Next: [[Driving Roblox Studio through MCP]]
