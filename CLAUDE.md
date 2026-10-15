# Hatch or Snatch! Agent Notes

This folder is Hatch or Snatch, a Roblox game. It is separate from Faceoff (the duel shooter) and HOOKED! / Fishing with Pets (`C:\Hooked!`). Don't read or edit Faceoff or HOOKED files or Studio places from Hatch or Snatch sessions.

- Start at `Hatch or Snatch Home.md`. It links the game plan, decisions and the notes for each area. Keep it current when you add notes.
- The game's Roblox Studio place is edited through the Roblox Studio MCP (`.mcp.json`). The same MCP server serves every Studio window on Hunter's PC, so always call `get_connected_instances` first and pick the Hatch or Snatch place. Never edit the Faceoff place ("Face Off Workspace") or the HOOKED place. The place's name and id go in the Home note once it exists.
- If the MCP is unreachable, Hunter starts it on his PC with `powershell -ExecutionPolicy Bypass -File tools\mcp\start_mcp_server.ps1` plus his ngrok tunnel. Never ask him to paste tokens or keys into chat.
- Pre-edit backups go to `docs\backups\<TICKET>_<date>\` in this folder. Ticket ids start with `HOS-` (e.g. `HOS-EGG-001`).
- Delivery reports and concept/reference images go in `docs\` in this folder.
- Script history: after a ticket that edits scripts, take a snapshot into `ScriptHistory\` (read-only copy of the place's scripts; steps in `ScriptHistory\README.md`).
- Uploads (sounds, images, models) run on Hunter's PC with `tools\upload\upload_assets.py`, using `HOS_ROBLOX_API_KEY` and `HOS_ROBLOX_GROUP_ID` / `HOS_ROBLOX_USER_ID` from his environment.
- Audio: Hunter rejects synthesised and AI-generated sound effects. Use real recordings (CC0 packs, Roblox's licensed library) unless he says otherwise.
- Skills in `.claude/skills/` include third-party ones from RoClicks and others (list and setup in `Research/RoClicks/RoClicks Index.md`). `studify` and `roblox-ui-maker` default to stud style. Until Hatch or Snatch has its own style guide, ask Hunter before committing to a look; once it has one, its look rules override theirs. Keep their process and checks.
