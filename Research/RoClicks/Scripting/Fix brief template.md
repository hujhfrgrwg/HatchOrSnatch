---
tags: [research, roclicks]
source: https://roclicks.gg/resources/scripting/fix-brief-template
retrieved: 2026-10-15
---
# Fix brief template

A shared brief for parallel fix agents. Copy it into the project (e.g. reviews/FIXBRIEF.md), fill in the \<...\> parts, and give each agent a short prompt naming its owned files and bug ids plus "read...

A shared brief for parallel fix agents. Copy it into the project (e.g. `reviews/_FIX_BRIEF.md`), fill in the `<...>` parts, and give each agent a short prompt naming its owned files and bug ids plus "read `_FIX_BRIEF.md` first". The same shape works for review agents with the read-only rules in [[Many agents, one Studio|multi-agent.md]].

Why each rule exists is explained in [[Many agents, one Studio|multi-agent.md]] and [[Driving Roblox Studio through MCP|studio-mcp.md]].

------------------------------------------------------------------------

``` markdown
# Fix brief (shared by the <N> fix agents)

The developer approved fixing <which bugs: e.g. all critical and major bugs> from the review.
The ranked list is in `<reviews/00_SUMMARY.md>`; details (file, lines, repro, suggested fix) are in
`<reviews/NN_*.md>`. Line numbers refer to the snapshot in `<snapshot dir>`.

## Ownership
- Only edit the files listed in your prompt.
- If a fix needs a change in a file you don't own, don't make it. List it under "Needs another owner"
  in your report, with the exact change (file, function, code).

## Project
- Game source on disk: `<src/...>`. It may be STALE: Studio is the source of truth.
- Before you start, read: `<project notes / memory files / agent instructions>`.

## Studio
- MCP server: `<robloxstudio>` only. Call get_connected_instances and pass instance_id on every call.
- Place: "<place name>". First line of every mutating execute_luau:
  `assert(game.Name == "<place name>" and <landmark check>, "wrong place")`
- A collaborator may be editing live in Team Create. Never revert their changes (scripts, lighting, balance).

## Mandatory workflow
1. **Pull before editing.** For every script you will edit, pull its Studio source byte-exact
   (export_rbxm + `tools/rbxm_extract.py`). Write it over the disk copy and keep the pulled copy as your
   base in your scratchpad. Never push a disk file you didn't refresh first.
2. Edit on top of the pulled source. Match the surrounding style and comment density.
3. Run `python3 <tools>/game_check.py <src>` until it reports 0 errors.
4. **Stage and push:**
   - `python3 <tools>/stage.py --name Stage_<YourName>_<n> "<StudioPath>=<file>@<base>" ...`
     (`@NEW` for new scripts). Use a new `<n>` for every push.
   - import_rbxm the file into game.ServerStorage.
   - Run `<tools>/stage_apply.luau` with STAGE_NAME set to your folder.
   - On CONFLICT nothing was applied: re-pull, re-merge, retry.
   - Never use set_script_source. Never rebuild and import whole bundles.
5. **Playtest lock.** Before a playtest set workspace attributes `PlayLock` = your name and
   `PlayLockT` = os.time(). If another agent holds a lock younger than 5 min, wait and retry; never steal.
   - Keep runs under 5 min; stop the playtest; release the lock.
   - The developer's machine is <weak/OK>: prefer short eval_server_runtime / eval_client_runtime checks
     over long play.
   - If peers time out ("queued; not_executed"), stop, wait, retry ONCE, then report it. Do not kill
     Studio processes.
6. **Camera lock** (`CamLock`, `CamLockT`): save and restore CFrame, Focus and FOV. Never touch
   `<developer-only toggles, e.g. intro flag, UseDataStore>` or Lighting.
7. **Log.** Append a short section to `<CHANGELOG / IMPROVEMENTS.md>`: what changed, how you verified
   it, what was NOT verified and why, files with Studio paths. Re-read the file right before appending;
   other agents write to it too.

## Report back
- Each bug fixed: what, where, how you verified it.
- Bugs skipped, and why.
- "Needs another owner" items, with the exact change.
- Anything the developer must decide (prices, design calls, settings only they can change).
- Files changed, with their Studio paths.
```

------------------------------------------------------------------------

## Per-agent prompt (example)

``` markdown
You are fix agent B (world, map, combat). Read <path>/_FIX_BRIEF.md first and follow it exactly.
You own: <list of files with Studio paths>.
Fix these bugs from the review: 02 B1, 03 B2, 05 B1-B4, 13 B1, B2, B6.
Your stage names: Stage_FixB_<n>. Your playtest/camera lock name: "FixB".
```

## Tips for the coordinator

- Split by **file set**, not by bug type, so no two agents own one file.
- Put the bug ids in the prompt; put the rules in the brief. Agents re-read the brief, not the chat.
- Give every agent a distinct lock name and stage prefix.
- After all agents report, route the "Needs another owner" items in one follow-up pass.
- Collect "not verified" lines into one list for the next live playtest.

Previous: [[Many agents, one Studio]] · Next: [[Data and saves]]
