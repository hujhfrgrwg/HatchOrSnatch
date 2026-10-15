---
tags: [research, roclicks]
source: https://roclicks.gg/resources/scripting/multi-agent
retrieved: 2026-10-15
---
# Many agents, one Studio

How to run several AI agents (and a human collaborator) against one live place without anyone overwriting anyone.

How to run several AI agents (and a human collaborator) against one live place without anyone overwriting anyone. This setup let a 15-reviewer audit plus 4 parallel fix agents finish in an afternoon with zero clobbered files.

- [[#Ownership: one file, one owner]]
- [[#Studio is the source of truth]]
- [[#Base-compare apply]]
- [[#Unique stage names]]
- [[#Locks on workspace attributes]]
- [[#Read-only reviewers on a snapshot]]
- [[#Splitting a long job into parallel owners]]
- [[#Shared logs]]
- [[#Checklist]]

## Ownership: one file, one owner

Give every agent a written list of the files, Studio folders and world regions it may change. Everything else is read-only to it.

| Kind                                                | How to split it                                                            |
|-----------------------------------------------------|----------------------------------------------------------------------------|
| Scripts                                             | By file. Two agents never own the same module.                             |
| Shared helper modules                               | One owner; others may only request *additive* changes.                     |
| Shared containers (e.g. `ReplicatedStorage.Assets`) | Each agent replaces only its own subfolder, never the whole folder.        |
| World space for showcases or builds                 | Fixed boxes per agent (x/z ranges); check the box is empty first.          |
| Build output files                                  | One output name per agent (see [[#Unique stage names]]). |

- If a fix needs a change in a file the agent does not own, it **does not make it**. It writes the exact change under "Needs another owner" in its report, and the coordinator routes it.
- **Why:** two agents editing the same module in parallel silently lose one agent's work, and neither notices because each verifies only its own change.

## Studio is the source of truth

Once a collaborator edits scripts or lighting live in Studio (Team Create), the disk copy goes stale without warning. In one project, 19 disk files had drifted, and the disk copy of the shop called two functions the disk copy of the save service no longer had. Pushing disk would have broken every purchase.

- **Pull before every edit**: get the script's current Studio source byte-exact ([[Driving Roblox Studio through MCP|studio-mcp.md]]) and keep that pulled copy as your *base*.
- Edit on top of the pulled copy, never on top of an older disk file.
- Never push a file you did not refresh from Studio first. Never rebuild and import whole bundles once a collaborator works live; push per module.
- Keep a dated **snapshot export** of all scripts (`tools/rbxm_extract.py`). It is the rollback point and the reviewers' input.
- Other agents push their disk copies too, so an in-progress disk edit can go live unannounced. Do not leave half-finished edits in files other agents might stage.
- Never revert a collaborator's tuning (lighting, balance numbers) without asking. If their change breaks your target, report it.

## Base-compare apply

The push refuses to overwrite anything that changed since you pulled it.

1.  Stage each file with its base: `python3 tools/stage.py --name Stage_<agent>_<n> "<StudioPath>=<edited>@<base>" ...` (`@NEW` for a script that must not exist yet).
2.  `import_rbxm` the staged file into `ServerStorage`.
3.  Run `tools/stage_apply.luau` (with `STAGE_NAME` set) in `execute_luau`. For every target it checks:
    - live source == base, or live source == the new source (already applied): OK;
    - `@NEW` target already exists: conflict;
    - target missing: conflict;
    - anything else: conflict.
4.  If **any** item conflicts, **nothing** is applied and the stage is destroyed. Re-pull, re-merge, retry.

``` text
CONFLICT (nothing applied): ServerScriptService.Game.Services.Data
```

- All-or-nothing matters: a half-applied push leaves module A calling a function module B does not have yet.
- Normalise `\r\n` to `\n` before comparing, or every Windows-saved script conflicts.

## Unique stage names

A staging tool that always writes `build/Stage.rbxmx` with a root folder named `Stage` is a race: two agents stage, one imports the other's file, and the apply pushes code neither reviewed.

- Name the output file **and** the root folder per agent and per push: `Stage_FixA_3`.
- The apply script takes the folder name as a parameter and destroys only that folder.

## Locks on workspace attributes

Shared resources (the playtest, the one viewport camera) are locked with attributes on `workspace`, which every agent can read and write with `execute_luau`.

**Playtest lock**

``` lua
-- take
local holder, t = workspace:GetAttribute("PlayLock"), workspace:GetAttribute("PlayLockT")
if holder and holder ~= ME and os.time() - (t or 0) < 300 then return "BUSY " .. holder end
workspace:SetAttribute("PlayLock", ME); workspace:SetAttribute("PlayLockT", os.time())
-- ... start playtest, verify with short eval calls, stop ...
-- release
workspace:SetAttribute("PlayLock", nil); workspace:SetAttribute("PlayLockT", nil)
```

- Runs stay under 5 minutes. Verify with targeted runtime evals, not long play.
- **Never steal a younger lock**, even a stale-looking one: ask the coordinator for a slot. (Set the attribute in edit mode, since playtest instance changes revert on Stop.)

**Camera lock**

1.  If `CamLock` is held by someone else and younger than 30 s, wait (in a background shell, not inside `execute_luau`).
2.  Take it. The first holder saves `CamCF`, `CamFocus`, `CamFov` (and `CameraType` if you must change it).
3.  Set `cam.CFrame` and `cam.Focus` directly. Do not use "select and view", which changes the human's selection.
4.  Capture, restore everything, clear the lock.
5.  Never send a capture in the same batch as a lock attempt that might return BUSY.

**Why:** the human is using the same editor camera. An agent that leaves it somewhere else, or captures another agent's angle and judges the wrong build, wastes everyone's time.

Leave the developer's own toggles (intro skip flags, a "use real DataStore" flag, Lighting) alone. Clear only your own lock attributes in cleanup code.

## Read-only reviewers on a snapshot

To audit a big game on a weak machine:

- Export a snapshot of every script to disk (`export_rbxm` + `tools/rbxm_extract.py`), laid out by DataModel path.
- Reviewers are **read-only**: no Studio calls at all, no playtests, no edits. One report file each, at a fixed path, in a fixed format (bugs with file:line, trigger, severity, confidence, code-level fix; then improvements; then a summary).
- Line numbers in reports refer to the snapshot, so fix agents know which version they mean.
- **Why:** 15 reviewers calling Studio in parallel would freeze the machine; 15 reviewers reading files cost it nothing. Reviewers also spot snapshot-vs-disk drift, which no Studio-side check does.

## Splitting a long job into parallel owners

A long serial job (a 20-round improvement loop, a 100-model asset pass) finishes much faster split by area, as long as the areas do not share files.

- Merge the review findings into one ranked list, then cut it into owners by **file set**, not by bug type (e.g. A: saves/shop, B: map/combat, C: UI/tutorial, D: controls/FX).
- One shared brief for the rules (the [[Fix brief template|fix brief template]]); a short per-agent prompt for the owned files and bug ids.
- Playtests and the camera are the bottleneck; the locks serialise them, so keep each agent's runs few and short.
- Each agent reports "needs another owner" items; the coordinator does one follow-up pass for them.

## Shared logs

- One append-only change log (e.g. `IMPROVEMENTS.md`) with a dated section per agent. **Re-read it right before appending**; several agents write to it.
- Each section lists what changed, how it was verified, what was **not** verified (and why), and the files with their Studio paths.

## Checklist

- Every agent has a written list of owned files, folders and world boxes.
- Pull from Studio before each edit; keep the base copy.
- Push with base-compare apply, unique stage names, all-or-nothing.
- Playtest and camera locks on workspace attributes; never steal.
- Reviewers read a snapshot and never touch Studio.
- Shared log re-read before every append.

Previous: [[Driving Roblox Studio through MCP]] · Next: [[Fix brief template]]
