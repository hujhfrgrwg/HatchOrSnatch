# HOS-MAPVOTE-001 Map vote before every match (mockup stage)

Hunter, 17 Oct: a NEXT MAP vote before the start of every round, with the Lead Catcher button under it like his reference
(`docs/references/03_map_vote_next_map.png`, `02_map_vote_buy_lead_catcher.png`).

## How maps work today (read 17 Oct, live place 128015050187408)
- 4 playable maps. `MapService.lua` ORDER is `Farm, SunnyCove, FrostyPass, Stadium` (titles: Hatchery Farm, Sunny Cove,
  Frosty Pass, Egg Bowl Stadium). In the place: live `workspace.EOS_World.Arena` = SunnyCove; stored in
  `ServerStorage.EOS_Maps`: Arena_Farm, Arena_FrostyPass, Arena_Stadium. `EOS_FixedMap` is not set.
- The map is chosen by rotation, not by players. `MatchService.lobbyLoop` (ScriptHistory l.1148-1154): after a played match,
  `MapService.rotate()` (MapService l.161) swaps in the next map in ORDER, and every client gets a "Next map: <title>" toast.
  `MapService.set(name)` (l.139) swaps any stored map in by moving models. It only runs between matches.
- Timings (`GameConfig.Timing`): RESULTS 11 s, then INTERMISSION 15 s (the lobby countdown), then ROLE_REVEAL 5 s.
  The rotation happens just before INTERMISSION.

## Proposal (mockup)
- The vote runs during INTERMISSION (15 s). Two choices from the 3 maps not just played, picked at random.
  This matches the reference and keeps the panel small. Click a tile or press 1 / 2. You can switch your vote until the end.
- At 0 s the winner is shown for about 1 s. A tie is broken at random. The server then calls `MapService.set(winner)` before
  ROLE_REVEAL, in place of `rotate()`.
- The approved Lead Catcher card (HOS-LEAD-001) docks centred 16 px under the vote panel while the vote is up.
  It goes back to the bottom right if there is no vote (e.g. waiting for players).
- Panel 920 x 372 + card 580 x 176 = 920 x 564, centred under the round header. The SPECTATE pill is hidden while
  the vote is up (it only shows during a match anyway).
- Map photos don't exist yet. The tiles use themed placeholders. After the look is approved, capture each map in Studio
  (one upload per map).

## Mockups (UI/build.py `vote_panel` / `map_tile` / `mv_scene`, pages `mapvote*.html`)
`mockups/mapvote_lobby.png`, `mapvote_states.png` (open, voted + paying, taken, result), `mapvote_phone_844x390.png`,
`mapvote_size_check.png`.
Nothing goes into Studio until Hunter approves the look.
