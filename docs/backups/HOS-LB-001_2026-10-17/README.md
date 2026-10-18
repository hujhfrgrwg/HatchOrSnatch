# HOS-LB-001 backups (17 Oct 2026)

Taken before the lobby leaderboards moved to the Halloween boards.

| File / place | What |
|---|---|
| `LobbyService.lua` | `ServerScriptService.EOS.Services.LobbyService` before the edit |
| `FacePlayer.lua` | `StarterPlayer.StarterPlayerScripts.EOS.Controllers.FacePlayer` before the edit |
| Studio: `ServerStorage._Backup_OldLeaderboards_20261017` | The old boards (`Workspace.LobbyProto.Stations.Leaderboards`). Their CollectionService tags were taken off so the live game ignores them; each tagged instance keeps its tags in the `_BackupTags` attribute. |

To restore the old boards: move the model back to `Workspace.LobbyProto.Stations`, re-add each `_BackupTags` tag and paste the two scripts back.
