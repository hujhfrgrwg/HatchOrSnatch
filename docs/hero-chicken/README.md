---
tags: [delivery]
updated: 2026-10-17
ticket: HOS-HOC-001
---
# HOS-HOC-001: Hero or Chicken (the cinematic pick)

At the start of every crossing the lead Catcher picks one Runner, who chooses **HERO** (crosses alone, first; the
group waits on the line, then goes) or **CHICKEN** (crosses with everyone). A Hero who gets across earns double
crossing value (Gold + XP, never Gems) and one bonus egg-piece roll. A caught Hero joins the Catchers like anyone
caught. When only one Runner is left there is no pick (Last Runner Standing plays instead).

**Status:** built in the Hatch or Snatch place (not saved: Hunter saves). Playtested solo with NPC fill
(17 Oct, seven takes). The last take had zero comfort warnings and no errors.

## Final clip and stills (`final/`)
- `hero_or_chicken_final.mp4` (57 s):
  - crossing 1: I'm picked, go HERO, the run, HERO! with +200 PTS, the group goes next;
  - crossing 2: an NPC is picked and goes HERO while I'm held on the line;
  - crossing 3: an NPC goes CHICKEN.
- Stills:
  - `01_lead_catcher_considering`
  - `02_choosing_spotlight`
  - `03_catcher_points_and_pick_cards`
  - `04_picked_hero_or_chicken`
  - `05_hero_reveal`
  - `06_chicken_reveal`
  - `07_hero_attempt_heros_view`
  - `08_hero_attempt_held_runners_view_lined_up`
  - `09_hero_success_200pts`
  - `10_group_goes_next`

## 17 Oct update (after Hunter: "he should point at who he picked")
- **The point works on every server, with no upload needed.** The lead Catcher turns in 0.3 s and their right arm swings up to aim straight at the picked Runner.
  - The server sets the shoulder joint (`CatcherGesture`) and holds it until the choice is made.
  - The shared `Controllers/CharacterAnim` had been resetting the shoulder on every client every frame. It now leaves it alone while the character has `EOS_ArmHeld` (a one-line hook, tagged HOS-HOC-001).
  - Checked on the client: the arm is horizontal during the point. Still `13_catcher_points_at_pick.png`, clip `pick_point.mp4` (8.5 s: considering, turn, point, push to the Runner).
- **Pick shot:** a held 1.2 s view from the Catcher's right side, about 8 studs away. The Catcher is on the left, the arm crosses the frame, and the spotlit Runner is on the right (`Gesture.OTS`). If a wall is in the way, the shot switches sides or moves in closer.
- **Considering pose is published:** Animation 131022066837723 in group 228184582 (`Gesture.CONSIDER_ID`), so live servers play it. `POINT_ID` stays 0, so the point stays in code.
- **Lineup fix:** on Frosty Pass the lead Catcher's spot was inside the ice-fishing cabin. `CrossingLineup` now uses the nearest clear spot: a body fits, nothing is overhead, and the Runner row is in view.
- **Close shots check line of sight** (`clearDir`): they try other angles around the subject, else move in closer.
- **Teal + trophy points pill imported** after Hunter's OK at 07:25. The HERO! chip reads "+200 PTS" (still `09b_hero_success_teal_pill.png`). The old unused "+200 HERO PTS" pop is gone from the place and from `UI/build.py`.

## What happens (one crossing)
| Beat | Server stage | Seconds (config) | What players see |
|---|---|---|---|
| Lineup | (inside runPick) | - | Runners in a 4-stud row on the start line, Catchers across the centre, the lead Catcher one step in front; everyone frozen |
| a1 Lead Catcher | CHOOSING | 3.2 | a slow push toward the lead Catcher, who is doing a "considering" pose; label LEAD CATCHER · 0:09 |
| a2/a3 Choosing | CHOOSING | to 9.2 | dip to the Runner line. Everyone else: a slow chest-height dolly. Lead Catcher: a wide pick view; click/tap/gamepad picks. A spotlight follows their aim on every screen |
| b Picked | PICKED | 5 | the Catcher turns and points (side shot), dip, slow push to the picked Runner; label HERO OR CHICKEN? · 0:05; the picked Runner gets the HERO / CHICKEN cards |
| c Reveal | REVEAL | 2 + 1.3 | HERO!: gold rays, ring and confetti. CHICKEN!: a grey picture, feathers and a slow pull-back. Then a dip back to the game |
| Ready | READY | 1.5 | the round header says "<name> is going HERO" and "get ready · 3" |
| Hero run | HERO_RUN | max 12 | header HERO ATTEMPT. The group stays frozen and the Catchers chase the Hero. HERO line in the Hero's own name tag. Tags past 60 studs fade |
| Success | HERO_SUCCESS | 3.4 | a low push on the Hero in the safe zone, HERO! with "+200", confetti and a cheer |
| Group ready | GROUP_READY | 2.5 | header HERO ATTEMPT COMPLETE / THE HERO WAS CAUGHT, THE GROUP GOES NEXT, get ready · 3; then the group goes and the crossing clock restarts for them |

The camera follows Hunter's comfort rules (17 Oct): FOV 70 → 62 at most, eased dollies under 5 studs/s and
25°/s, 0.2 s black dips between shots, no flashes and no shake. With Reduce effects on, the camera doesn't move.

## Files in the place
- **Server**
  - `ServerScriptService.EOS.Services.HeroChickenService`: the pick, choice and reveal, the Hero run, the reward and analytics.
  - `CrossingLineup`: forced lineup and freeze.
  - `CatcherGesture`: the lead Catcher's considering and point clips.
- **Config:** `ReplicatedStorage.EOS.Shared.HeroChickenConfig` (every number; `Enabled` is the switch).
- **Client**
  - `StarterPlayerScripts.EOS.Controllers.HeroChicken`, booted by `EOS.HeroChickenBoot` (a LocalScript, so ClientMain is untouched).
  - The camera goes through the shared `Controllers.Cinematic`.
- **UI:** `StarterGui.HeroChickenUI` and `ReplicatedStorage.HeroChickenTemplates`.
  - Built with roblox-ui-maker from the EOSUI project: `UI/build.py` section "Hero or Chicken (HOS-HOC-001)", pages `UI/hc_*.html`.
  - Export config `ui_hc/rbx.json`, Luau `roblox/ui_hc/`.
  - Approved renders are in `ui_match/`.
- **VFX:** `ReplicatedStorage.VFX.HeroChicken` (`HC_HeroBurst`, `HC_SuccessBurst`, `HC_ChickenFeathers`, `HC_Spotlight`), played with `VFX.Emit` (roblox-vfx).
- **Hooks in shared scripts** (all tagged HOS-HOC-001):
  - `MatchService`: require, lineUpCatchers, runPick, crossingStarted, step, crossingEnded, matchEnded, settle bonus, init/bind.
  - `MatchLogic`: the HERO Gold line and the heroBonus field.
  - `ProfileLogic`: bonusMaterials.
  - `AbilityService`: no abilities while frozen on the line.
- **For other systems:** `EOS_State.HeroRunActive` is true only while a Hero runs alone. Field Gems pause on it.
- **Studio only:** workspace `HC_ForcePick` (a user id or "LOCAL") and `HC_ForceChoice` (HERO / CHICKEN) force a pick for recordings. Live servers ignore them.

## Sounds (real recordings, Roblox licensed library)
| Sound | Asset | Recording |
|---|---|---|
| drumroll | 1842251033 | Snare Drum Roll (KPM via APM) |
| heartbeat | 1842342421 | Heartbeat (a) (KPM via APM) |
| whoosh | 9120711172 | Whoosh Fast Swish By 7 (Pro Sound Effects) |
| lock thump | 9119882039 | Synth Whomps 38 (PSE) |
| HERO sting | 9047100306 | Hustler Sting 2 (Score Production Music) |
| CHICKEN | 9113444703 | Bird Wing Flaps Pigeon Two Squeaks 1 (PSE): no licensed chicken cluck exists in the library |
| cheer | 9112766176 | Crowd Cheer And Applause 1 (PSE) |

They play through the game's `EOS_SFX` group, so the Settings sound toggle applies and the music ducks under the pick.

## Uploads
One new image: `vfx/hero-chicken/tex/hc_confetti.png` (AllVFX Specs or Wisps/59.png) → decal 114250128044960, image 136039681178523. It's logged in `docs/VFX-LEDGER.md`.

## Open items for Hunter
- **Tags in the break:** in the WAVE_END break, before a pick starts, the lined-up Runners' overhead tags can still run together for a moment. The tags are hidden once the cut-scene starts and while people are frozen. A follow-up could hide them from the lineup on.
- **Save the place** (I never save or publish).
- **Points:** "+200" is a placeholder (`HERO_POINTS`). It currently pays one extra crossing of Gold and XP (`HERO_CROSSING_MULT = 2`). The points thread reads `HERO_POINTS` when its points system goes in.
- **Bonus egg piece odds:** 70 / 25 / 5 common / rare / epic (`BONUS_ROLL`).
- **Length:** a full pick (NPC timings) runs about 12-14 s. The worst case is about 19 s if the Catcher and the Runner both use their whole windows.
