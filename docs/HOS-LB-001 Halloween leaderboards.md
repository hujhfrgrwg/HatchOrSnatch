---
tags: [delivery]
ticket: HOS-LB-001
date: 2026-10-17
---
# HOS-LB-001: Halloween leaderboards

The four Halloween boards in `Workspace.Leaderboards` (`Leaderboard_01` to `Leaderboard_04`) now do what the old lobby boards did: live this-server rankings, and each board turns to face the player looking at it. The old boards are deleted from the lobby (backup below).

## What each board shows

| Model | Title | `Stat` | Ranks by |
|---|---|---|---|
| `Leaderboard_01` | HIGHEST LEVEL | `level` | account level (`EOS_Level`, the nameplate level) |
| `Leaderboard_02` | MOST WINS | `wins` | `EOS_Wins` |
| `Leaderboard_03` | TOP PLAYERS | `top` | wins + catches + pets hatched + level, added together |
| `Leaderboard_04` | MOST STEALS | `captures` | `EOS_Captures` (catches) |

Top 10 players in the server, numbers with commas (3,492). Empty places stay blank. The placeholder names in the models are only for Studio; the server overwrites them before anyone joins and then every 3 seconds.

## How it's wired

- **Data:** each board's `A01_DisplayPanel` has tag `EOS_Board` and attribute `Stat`. `LobbyService.updateLeaderboards` fills `Rows.Row01..Row10` (`Name`, `Score`; `Rank` is left as designed). It still fills the old `Row1..Row8` layout too.
- **Turning:** each `Leaderboard_0N` model has tag `EOS_FacePlayer` and `ModelStreamingMode = Atomic`. The client `FacePlayer` controller turns it on the vertical axis only, so the board stays upright and never leans toward the player. It turns around the model's pivot (the bottom centre) and the front is the pivot's LookVector, which is the side the SurfaceGui is on. Atomic streaming makes the whole board arrive at once, so turning it never leaves parts behind.
- Only boards inside `Workspace.LobbyProto` follow the stadium's lobby lift; the Halloween boards stay where they are.

To change the TOP PLAYERS formula, edit `TOP_PARTS` in `LobbyService`. To add a board, tag the panel `EOS_Board` with a `Stat` from `BOARD_STATS`, and tag the model `EOS_FacePlayer` with Atomic streaming.

## Checked in a playtest

- All four boards filled with the test player's stats (level 27, 3,492 wins, 980 steals, TOP PLAYERS 4,540 = 3492 + 980 + 41 + 27).
- From in front, 25 studs to the left and 25 to the right, every board turned to within 0.5° of the player with zero tilt, and the panel moved with the frame.
- Standing 3, 5 and 8 studs in front at five spots along the row: neighbouring boards never overlapped.
- No errors in the output.

## Backups and notes

- Pre-edit scripts and restore steps: `docs/backups/HOS-LB-001_2026-10-17/`. The old boards' model is in `ServerStorage._Backup_OldLeaderboards_20261017`.
- `ServerStorage.EOSBuild.LobbyProps` (the lobby builder) still makes the old swivel boards. Rerunning it would bring them back.
- Script snapshot: `ScriptHistory/` (first snapshot of the place).
