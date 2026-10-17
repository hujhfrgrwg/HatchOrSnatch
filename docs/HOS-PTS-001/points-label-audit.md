---
tags: [ticket, ui, audit]
updated: 2026-10-17
---
# HOS-PTS-001 points label audit

Hunter, 17 Oct: "the +200 is very vague and misleading. players might assume that it means gold, xp, etc. we need to be specific if a player is being awarded points." This lists every place a points number shows, in the live place and in `UI/build.py`, plus the Gold and XP numbers shown near them.

## The rule (coordinator default; Hunter can still change it)
- A points amount is never a bare number. It is always a pill reading **"+200 PTS"**: trophy icon + the number + the word PTS, white outlined text on the **points teal** plate (the kit's `k-teal`: #4affd8 → #16c8aa, lip #0a807a). Teal carries no other value in the game: it only appears elsewhere as a Servers-panel button colour and the Shield ability colour, never on a number.
- **Gold** is always yellow with the coin icon and the word GOLD ("+25 GOLD 🪙"). **XP** is always sky blue with the word XP ("+544 XP").
- In-match popups keep their reason line: the pill on top, "Reached Safety!" (with the reason's icon) under it.
- The results card shows POINTS, XP and GOLD on separate labelled rows.
- `UI/build.py` helper: `pts_pill(n, size, sign)` in the HOS-PTS-001 section.

**Icon:** the trophy (coordinator, 17 Oct). The star was the first pick, but it is already the Level/XP icon on the lobby HUD (`hv_level`).

## Where points numbers appear

| # | Where | Owner | Current text (before) | After | Stills |
|---|---|---|---|---|---|
| 1 | HERO! success banner chip (`HeroChickenUI` Success.PointsChip) | Hero or Chicken thread (mockup only here) | Live place: bare **"+200"** (`Controllers.HeroChicken` line 1152: `"+" .. HC.HERO_POINTS`). Their `build.py` mock is now "+200 PTS" in gold | Teal pill "🏆 +200 PTS" | `labels/before_hc_d2_success.png`, `labels/after_points_hero_after.png` |
| 2 | HERO pop template (`HeroChickenTemplates.PointsPop`) | Hero or Chicken thread | Live: **"+200 HERO"** (`Controllers.HeroChicken` line 1241); their mock now "+200 HERO PTS" | Should become the pill "🏆 +200 PTS" + "Hero crossing!" line (same as #3) | (their page) |
| 3 | In-match points pop (`PointsUITemplates.PointsPop`): safe / hero / juke / revive / catch / snatch | HOS-PTS-001 | "+100 Reached Safety!" with the amount coloured per kind (lime / gold / white / sky / red / rarity): lime read like Gems, gold like Gold, sky like XP | "🏆 +100 PTS" teal pill, then the reason line ("Reached Safety!", "Juke!", "Revive!", "Catch!", "Epic egg snatched!") with its icon | `labels/before_points_match.png`, `labels/after_points_match.png`, phone `labels/after_points_labels_phone.png` |
| 4 | JUKE! slam (`JukeWord`) | HOS-PTS-001 | "JUKE!" (no number) | unchanged; the "+10 PTS" is in the pop (#3) | same as #3 |
| 5 | Podium cards over the steps + the push-in card (`PodiumCard`, `PodiumCardBig`) | HOS-PTS-001 | "618 Points" in lime (lime = the Gems colour) | "🏆 618 PTS" teal pill under the name | `labels/before_points_podium.png`, `labels/after_points_podium.png` |
| 6 | Results leaderboard rows (`Points.Leaderboard.Row` / `YouRow`) | HOS-PTS-001 | "618" in **Gold yellow** + a dim "PTS": read as Gold | "🏆 618 PTS" teal pill | `labels/before_points_board.png`, `labels/after_points_board.png` |
| 7 | Results rewards card: your points | HOS-PTS-001 | "YOUR POINTS" + "544" in **Gold yellow** | Row "POINTS" + "🏆 544 PTS" pill | same as #6 |
| 8 | Results rewards card: XP | HOS-PTS-001 | "+544 XP" (sky) | Row "XP" + "+544 XP" (sky): unchanged colour, now its own labelled row | same as #6 |
| 9 | Results rewards card: Gold lines + total | HOS-PTS-001 | "PLAYED +25 🪙", "POINTS SHARE +33 🪙", "GOLD +58 🪙" (the word "POINTS" sat next to a Gold amount) | "PLAYED +25 GOLD 🪙", "POT SHARE +33 GOLD 🪙", row "GOLD" + "+58 GOLD 🪙" | same as #6 |
| 10 | Round header / HUD counter | none | No live points counter in the match HUD. The header shows "CROSSING n / 5" (no points) | none needed. If a live counter is added later it uses the pill | `before_points_match.png` |

Not points, but nearby numbers that already follow the Gold/XP half of the rule (no change): the old Results screen "+86 🪙" Gold total (hidden while Points is on), the post-match toast "+544 XP" (`UIController` line 3147, says XP), the lobby Level plate "124 / 375 XP", field Gems "+1 💎" (the gem icon).

## Runtime changes that go with the look (after approval, HOS-PTS-001 only)
- `PointsController.onPop`: write "+N PTS" into `PtsPill.PointsText`; the reason line keeps WordsText + Icon; stop recolouring the amount per kind (one points colour).
- `fillRow` / podium cards: "%d PTS" (no "+" on totals).
- Rewards card: `LineAmount` "+%d GOLD", `GoldTotal` "+%d GOLD", `PointsTotal` "%d PTS".
- Re-export, gen and bundle PointsUI (the pill is native: no new art to upload).
- The Hero or Chicken thread applies the same pill to #1 and #2 in its own UI.
