---
tags: [research, roclicks]
source: https://roclicks.gg/resources/scripting/multiplayer-isolation
retrieved: 2026-10-15
---
# "Solo in a shared server" games

Many tycoons, idle games and PvE campaigns are really single-player, but Roblox servers hold several players.

Many tycoons, idle games and PvE campaigns are really single-player, but Roblox servers hold several players. The goal: up to N players share one server and **nothing** of one player's game (parts, sounds, remotes, raycasts, touches) reaches another. These rules come from turning a solo strategy game into a 6-player server and then proving with a 2-client test that a client received zero bytes of the other player's battle.

- [[#Pick the model: private layer, not far-apart coordinates]]
- [[#Client-only world]]
- [[#Server-built per-player arenas]]
- [[#Remotes: FireClient, never FireAllClients]]
- [[#Avatars]]
- [[#Per-player state and cleanup on leave]]
- [[#Order of removal handlers]]
- [[#Server CPU with N players]]
- [[#Checklist]]

## Pick the model: private layer, not far-apart coordinates

The obvious idea is a per-player origin: player 1 at x=0, player 2 at x=20,000, and so on. Prefer a **private layer at the same coordinates** instead:

| Concern                   | Far-apart origins                                                                                                                                                | Private layer                   |
|---------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------|
| Float precision           | Players far from the origin get float32 jitter: spacing ~0.004 studs at 30k studs, enough to make small z-fighting offsets flicker for player 6 but not player 1 | Everyone at the origin          |
| Code changes              | Every system that converts cells/world, places the camera, raycasts or spawns must add an offset; one missed offset puts a building in the wrong place           | None for the client-built parts |
| What players can perceive | Nothing extra                                                                                                                                                    | Nothing extra                   |

Use offsets only for the few things the **server** must simulate in Workspace (see arenas below), and lift those straight up, not sideways.

## Client-only world

If the map is generated from a seed plus the player's saved layout, **build it on that player's client only**. The server never creates world geometry, so nothing replicates and two players' maps at the same coordinates can never meet.

- The server holds only state (`State[player]`) and resolves everything through the player: `World.forPlayer(p)`, never a module-level "the world".
- A module-level API that assumes one world should still work when exactly one world exists, but warn once per caller when there are several. New code must pass the player.
- Server checks (can I build here? is this cell mine?) run on the server's own data model of the map, not on parts.

## Server-built per-player arenas

When the server must simulate something physical (a battle with walls and line-of-sight raycasts), build it in Workspace but make it reach only its owner:

- **Lift each player's arena straight up into its own slot**: `y = LIFT * slot` with `LIFT` around 5,000 studs. Server raycasts and overlap queries never reach another slot.
- Make it a Model with `ModelStreamingMode = PersistentPerPlayer` and call `model:AddPersistentPlayer(owner)`. The owner always receives all of it; streaming never sends it to anyone else, because every other avatar stands thousands of studs below.
- The owner's client **lowers it onto its map** by the `Lift` attribute (a pure Y translation, so x/z maths is unchanged). Make that idempotent ("already lowered" by height) and give it two independent adopters, so one failing controller does not leave the arena invisible.
- Tag every arena with an `OwnerId` attribute. Clients detach any foreign arena they somehow receive.
- **Do not put the arena under PlayerGui** (in a WorldModel). Roblox clears PlayerGui when the character respawns, so a player who presses Reset mid-battle deletes the running battle's walls.
- Server-side audit every second: warn if StreamingEnabled is off, if `StreamingTargetRadius` approaches `0.6 * LIFT`, or if an arena lacks OwnerId/persistence. Respawn any avatar found above `0.4 * LIFT` (the only way a player, e.g. an exploiter, could be streamed someone else's arena).
- Keep game-logic attributes (site, facing, raid target) in **map coordinates**, not lifted ones.

## Remotes: FireClient, never FireAllClients

- Every per-player event (`Battle.Begin`, snapshots, results, notifications, state deltas) goes to the owner with `FireClient(owner, ...)`. A single `FireAllClients` leaks a whole battle's snapshots (15 Hz) to every client, which costs bandwidth and renders foreign units.
- Search for it: `grep -rn FireAllClients src` should return only genuinely global events (server shutdown notice, global announcement). `tools/game_check.py --lint` flags it.
- Units, effects and sounds are rendered by the owner's client from the snapshots. The server arena holds no Sound objects.
- Replicate state per player (a snapshot on join, then deltas to that player). Never put per-player state in ReplicatedStorage values everyone can read.

## Avatars

Avatars must be real characters in Workspace, so hide them from each other:

- **Server:** put every character part in a collision group that does not collide with itself.
- **Client:** for every other player's character set `LocalTransparencyModifier = 1`, mute their sounds, turn off `CanQuery` and `CanTouch` locally (so clicks and raycasts pass through them), and hide name/health displays and bubble chat.
- The leaderboard (`leaderstats`) can stay shared on purpose; it is the one social touch.
- **Voice chat:** if it is ever enabled, everyone stands near the same origin and hears everyone at full volume. Keep spatial voice off or route it through a non-spatial channel.
- `Players.MaxPlayers` is a publish setting (Game Settings \> Places). Scripts cannot change it, so put it on the launch checklist.

## Per-player state and cleanup on leave

Every service table keyed by Player is a leak and a correctness bug if it outlives the player.

- Each service exposes `playerLoaded(p)` and `playerRemoving(p)`; one bootstrap calls them in a fixed order.
- Never re-create an entry for a player who is leaving. Guard caches with `if p.Parent == nil then return end` (and a `leaving[p]` flag), because a late event can call `forPlayer(p)` after cleanup and silently rebuild (and leak) a whole world.
- Prestige / New Campaign resets per-player tables too (AI timers, raid schedules, tutorial flags), not only on leave.
- Wrap every step of leave-time work in `pcall`, and cap its total time (a few seconds) so the leave save still fits in the 30 s shutdown budget ([[Data and saves|data-and-saves.md]]).
- A record that can lock a player ("Already in a battle") must be cleared even if `finish` throws.

## Order of removal handlers

Leave handlers depend on each other. In one game, `World.playerRemoving` cleared the player's world, then `Battle.playerRemoving` resolved the running battle, whose `Ended` handler called `World.forPlayer(p)`, which rebuilt the whole map (and leaked it) inside the final-save window.

Order them like this:

1.  **Mark** the player as leaving (no new work may start for them).
2.  **Finish activity**: resolve battles and raids, refund queues, credit results. Time-capped, pcall'd.
3.  **Save** (the final save, which clears the session lock).
4.  **Drop** state: world, caches, AI, per-player tables.

A simple way to get this right: services only *mark* in `playerRemoving`, and the data service drops everything in one place after the save succeeds.

## Server CPU with N players

Several simultaneous simulations share one server frame.

- Use **one shared frame budget** (e.g. 8 ms) across all players' simulations. The first sim in rotation always steps; later ones bank their time once the budget is used, unless they have not stepped for 0.25 s. Under load the sims run slightly slower than real time instead of dropping the server frame.
- Measure the worst case early: one battle of 110+ units ran at about 29 server fps in Studio. Six at once needs the budget.
- Rotate who goes first each frame, or the same player always gets the smooth sim.

## Checklist

- World geometry built on the owner's client only.
- Server-simulated arenas: lifted per slot, PersistentPerPlayer + AddPersistentPlayer(owner), OwnerId, lowered on the client, not under PlayerGui.
- Zero `FireAllClients` for per-player events.
- Other avatars invisible, silent, non-colliding, non-queryable.
- Every per-player table cleared on leave and on prestige; no re-creation for leaving players.
- Leave order: mark, finish, save, drop.
- Shared frame budget for simultaneous sims.
- Max Players set by hand in Game Settings.
- A 2-client playtest that counts what client A received of client B's game (should be zero parts, zero snapshots, zero sounds).

Previous: [[Data and saves]] · Next: [[Performance]]
