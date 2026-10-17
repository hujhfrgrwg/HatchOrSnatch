# HOS-MAPVOTE-001 Map vote: delivery report (17 Oct 2026)

Hunter asked for a NEXT MAP vote before every round, with the Lead Catcher button under it like reference 03 (`docs/references/03_map_vote_next_map.png`). The layout is approved, and so is the look (v3, our UI kit). It is installed and playtested in the Hatch or Snatch place, which Hunter saved on 17 Oct (20:18Z).

## What it does
- The vote runs in the lobby INTERMISSION. It offers 2 maps picked at random from the maps not just played (4 maps: Hatchery Farm, Sunny Cove, Frosty Pass, Egg Bowl Stadium).
- Each real player gets one vote (bots don't vote), switchable by clicking a card or pressing 1 / 2.
- The vote locks 1.5 s before 0:00 and shows the winner (gold card + WINNER tag, the other card dims). A tie, or no votes at all, picks a random map.
- At 0:00 the winner goes live (`MapService.set`) before ROLE_REVEAL, and the panel hides.
- The red X hides the panel for that vote only.
- No vote runs if `EOS_FixedMap` is set or fewer than 2 other maps exist; the old rotation runs instead.
- While the vote shows, the Lead Catcher card (HOS-LEAD-001) becomes a small 210 x 62 button centred under the panel, key R. Its states are: Become Lead Catcher, Buying..., Lead Catcher: <name> (grey), You're Lead Catcher! (gold).

## Changed in the place
| Where | What |
|---|---|
| `ServerScriptService.EOS.Services.MapVoteService` | new: the vote |
| `ServerScriptService.EOS.Services.MatchService` | two one-line hooks in `lobbyLoop`, each ending `-- HOS-MAPVOTE-001`: `open()` before the rotation block, `close()` after `forceStartFlag = false` |
| `StarterPlayerScripts.EOS.Controllers.MapVoteController` | new: the panel (started by LeadCatcherController; no ClientMain edit) |
| `StarterPlayerScripts.EOS.Controllers.LeadCatcherController` | docks the small button under the vote, key R |
| `ReplicatedStorage.MapVoteUITemplates`, `StarterGui.MapVoteUI`, `ServerStorage.MapVoteUIBuild` | roblox-ui-maker build (`ui_mapvote/rbx.json`; UI/build.py `vote_panel`, `map_tile`, `lead_button`, page `mapvote_templates`) |

The backup of MatchService from before the edit is in `docs/backups/HOS-MAPVOTE-001_20261017/`. ScriptHistory has been updated for all 4 scripts above, and each matches the live source by length and checksum. All uploads are logged in `docs/VFX-LEDGER.md` (map photos v2, panel art, button plates, the grey plate re-upload).

## Tested (Studio playtest, PC + iPhone 13 844 x 390)
Everything below passed:
- click vote and switching
- 1-1 tie -> random winner
- gold winner + dim loser
- panel/button hide at the end
- the winner map loads
- all 4 Lead Catcher button states
- fake receipt -> pass -> starting Catcher and Hero or Chicken lead (Catcher count unchanged)
- phone: the panel is 50% of the width, clear of the joystick and buttons

Screenshots are in `docs/HOS-MAPVOTE-001/playtest/`.

**Not testable here:** the 1 / 2 keys. Studio's VirtualInput can't send number keys while Roblox's backpack hotbar is enabled. Real key presses go through UserInputService, and clicking works.

## Notes for later
- Titles are upright. The kit font (Fredoka) has no italic in Roblox, so there is no italic like the reference.
- The map photos are Studio captures (`docs/HOS-MAPVOTE-001/photos/raw_*.png`). Re-capture them if a map changes.

## Follow-up HOS-MAPVOTE-002 (17 Oct, Hunter: no Lead Catcher card bottom right; AFK players don't see the vote)
- Lead Catcher has no lobby card anymore. It only shows as the small button under the open NEXT MAP vote, and that includes the "You're Lead Catcher!" credit state (`LeadCatcherController.refresh`).
- AFK players (`EOS_AFK`) don't see the vote panel or the button, and can't vote:
  - `MapVoteService` ignores their votes and drops a vote when its player goes AFK.
  - `LeadCatcherService` refuses `RequestLeadCatcher` with reason "AFK"; credits are untouched.
  - Turning AFK off shows both again.
- Playtested:
  - no card in the lobby outside the vote
  - the small button shows during the vote
  - AFK on hides both, drops the vote (1-0 -> 0-0) and the Lead request is refused
  - AFK off shows both again
- Screenshots are `docs/HOS-MAPVOTE-001/playtest/afk_*.png`. Backups are in `docs/backups/HOS-MAPVOTE-002_20261017/`, and ScriptHistory is updated (the 4 scripts match live).
- With a single real player, going AFK also stops the countdown (MatchService counts only non-AFK players), so the lobby goes back to WAITING. With other players the countdown keeps running and only the AFK player's view hides.
