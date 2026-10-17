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

## Placement (HOS-LB-002, 17 Oct 2026)

The boards stand in an arc just inside the lobby fence. The fence is a circle of radius ~54.5 around the plaza centre (0, 1500), with its inner face at radius 54.2.

| Model | Angle (atan2 z, x) | Pivot (bottom centre) |
|---|---|---|
| `Leaderboard_01` | 28.8° | 43.29, 10, 1523.80 |
| `Leaderboard_02` | 39.6° | 38.06, 10, 1531.49 |
| `Leaderboard_03` | 50.4° | 31.49, 10, 1538.06 |
| `Leaderboard_04` | 61.2° | 23.80, 10, 1543.29 |

- **Radius 49.4:** a turning board can reach ~4.4 studs from its pivot in any direction, since it's edge-on when a player stands off to the side. At 49.4 the board never touches the fence; the closest it gets is 0.36 studs, fully side-on. Facing straight in, it stands ~3.9 studs off the fence. At radius 51 the boards went through the fence by up to 1.2 studs.
- **Spacing:** boards are 10.8° apart (9.3 studs). That's more than two reaches, so neighbours can't touch at any angle.
- **Ground:** the boards sit on `Ground_Outer` (y 10). The ledge they used to stand on had been removed, which left them floating at y 11.2.
- **Checked in a playtest:** player at radii 30, 35, 40, 45, 47 and 48, angles 15° to 75° (54 spots). There was no overlap between any board part and the fence or a neighbouring board.
- **Previous pivots, for undo:** 37.03, 11.2, 1517.41 / 30.49, 11.2, 1523.95 / 23.95, 11.2, 1530.49 / 17.41, 11.2, 1537.03, all facing yaw 45°.

## Backups and notes

- Pre-edit scripts and restore steps: `docs/backups/HOS-LB-001_2026-10-17/`. The old boards' model is in `ServerStorage._Backup_OldLeaderboards_20261017`.
- `ServerStorage.EOSBuild.LobbyProps` (the lobby builder) still makes the old swivel boards. Rerunning it would bring them back.
- Script snapshot: `ScriptHistory/` (first snapshot of the place).
