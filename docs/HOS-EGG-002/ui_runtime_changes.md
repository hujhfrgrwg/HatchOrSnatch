# HOS-EGG-002 UI: runtime edits and runtime elements (append only)

Source: `StarterPlayer.StarterPlayerScripts.EOS.Controllers.EggUIController` (disk: `docs/HOS-EGG-002/src/EggUIController.lua`),
started by one line at the end of `UIController`'s `UIC.init`. Gui: `StarterGui.EggUI` (Builder from `roblox/ui_egg`, export
config `ui_egg/rbx.json`, pages `ui/egg_x_*.html` written by `docs/HOS-EGG-002/tools/build_egg_export.py`).
EggUI's DisplayOrder is set to EOSUI's + 2 at runtime.

## Edits to other screens (while EggConfig.ENABLED)
- **EOSUI `UI.open`** is wrapped: `open("Incubator")` opens EggUI's `EggIncubator` (or `EggFirstPet` while the free first
  pet is claimable) instead of EOSUI's Incubator. Every path (rail button `Opens`, `toggle`, UIController calls) goes
  through `UI.open`.
- **EOSUI `Root.MatchHUD.Egg`** is kept `Visible = false` (checked each Heartbeat) while EggUI's `EggCard` shows; UIController
  still refreshes it underneath.
- **EOSUI `Root.Overlay` SAFE! banner**: on an upgrade roll, the SAFE! card UIController queues is set `Visible = false`
  (its queue keeps running) and EggUI shows the `EggBanner_<rarity>` template instead. One banner per safety.
- **EOSUI `IncubatorButton`** gets a cloned `ReadyBadge` named `EggReadyBadge` (anchored to its top-right), visible only while
  the incubator egg is full and the player is in the lobby.
- **PointsUI results card** (Match Points `You` well): 0.3 / 1.0 / 2.0 s after `Results`, `EggText` / `EggSlot.Icon` show
  the shard's rarity, `PieceText` reads `+1 <RARITY> SHARD` with the shard icon, or `NO EGG THIS MATCH` + "Snatch an egg as
  a Catcher to keep one" with the piece row cleared. A cloned `ShardRow` (its shard icon/text removed) named `EggMini`
  sits at the well's right edge, level with the shard line: the small incubator egg + ring + "x / 30 FILL", refilled
  when the settlement's ProfileState lands.

## Runtime elements (EggUI)
| Element | Source | Purpose / contents | States | Position |
|---|---|---|---|---|
| EggCard | screen EggHUD | rarity word, 4-segment charge meter (`Seg1..4.Fill` widths), `ChargeGlow` | `Runner_<rarity>`, `Catcher` (stash, `CapText`), `CatcherEmpty`; `BonusTag` | bottom-left, where EOSUI's egg card was |
| Tip | screen EggHUD `EggTip.Tip` | "Brave plays charge your egg." once per session, 4 s | hidden / shown | top centre |
| ChargePop | template | sparkle + "+CHARGE" in the egg colour, 1.1 s | | design (1346, 430), beside the +PTS pop |
| EggBanner_rare/epic/legendary | templates | upgrade at safety, after the ~1 s flicker | | centre, y 300 |
| Roll flicker | EggCard | cycles Rare / Epic / Legendary looks every 0.12 s for ROLL_SECONDS (x rolls for bonus rolls); off with Reduce effects | | |
| EggIncubator | screen | fill ring (`FillRing.Cooldown` halves), `BigEgg`, `FillText` / `FillSub`, `Shard_<r>.On/Off`, `OddsBar_<r>` / `OddsText_<r>`, `OddsSoon`, `Focus_<fam>.Sel/Open/Locked` + `FocusSel`, `BtnHatch` / `BtnHatchOff` | filling / ready / hatching | centre panel |
| EggFirstPet | screen | `Pick_<family>` tiles + `PickSel`, `BtnClaim` | | centre card |

## Added after the in-Studio QA (17 Oct, ~10:40Z)
- **Fill rings** (`FillRing`, results `MiniRing`): Builder's square `Cooldown` wedge is moved into a `CooldownClip` CanvasGroup
  with a round UICorner at init (only a CanvasGroup clips to a corner); `Hole` stays above it.
- **EggCard position** follows EOSUI's hidden `MatchHUD.Egg` each Heartbeat (glass plate to glass plate), so phones get the
  same raised spot EOSUI gives its own card. That spot overlaps the thumbstick's top edge on an iPhone 14, exactly as the
  live card did before this ticket.
- **EggCard visibility** goes through EggUI's `UI.setGroupHidden("EggCard", ...)` (its `refreshHud` re-showed the card when
  a panel closed).
- **EOSUI `Root.HUD.Goal`** (the lobby goal pill, "NEXT HATCH 0 / 2 COMMON PIECES") is kept hidden while EggConfig.ENABLED:
  it counts recipe pieces, which no longer exist. Follow-up: a goal pill that shows the egg's fill (needs a mockup).
- **ReadyBadge** sits just under the Incubator button (the top row is on the screen edge, a badge above it was cut off).
- **Phone egg card** (coordinator, 17 Oct ~10:05Z): when EggUI's FitScale is under 0.5 (phones), the card drops its small
  lines (TextSize < 30: title, "pays +1 ... SHARD", the Catcher's cap and hint; `PaysIcon`), keeping the slot, rarity word
  and meter (attribute `Compact` on EggCard; the bonus-rolls tag is kept). With a touch thumbstick, the card is lifted so
  its plate's bottom is 6 px above the thumbstick frame's top (`TouchGui` Thumbstick / DynamicThumbstick frame).
- **Stage 5 (17 Oct ~11:05Z):** `Controllers.EggFX` (started by EggUIController.init) adds the egg effects: `VFX.EggGlow`
  attachment on each charged player's `EOS_Egg` (light + glitter motes, 3 strengths), `VFX.EggPulse` ring on each charge
  rise, a temporary `Highlight` named `EggRollFlicker` on the egg during the ~1 s roll, `VFX.EggBurst` on an upgrade.
  Reduce effects keeps the glow light only. Results: the egg icon shakes and becomes the shard icon (`crack` sound), and a
  clone of the card's `ChargeGlow` image (`EggCore`) flies to the mini ring, once per Results.
- **Image warm-up:** `EggFX`-layer holder `EggImageWarm` draws every EggUITemplates image once (2% visible, 4 px, off
  screen) at init: a first draw took longer than the 1.6 s banner (seen live: EPIC EGG! without its plate the first time).
- **ProfileState race:** the listener connects first thing in init; a profile that lands before the screens are ready is
  applied once they are; with none after 3 s it asks once with `RequestProfile(EOS_Device)` (the player's own device).
- **Results `EggHow`** (17 Oct ~11:15Z): with a shard, EggUIController sets it to "Safe to the end" (still a Runner) or "Your
  best snatch" (Catcher); PointsController's "Common to Rare on crossing N" ran off the card on phones.
- **Not ours, noted for the match-points thread (PointsController / pts leaderboard):** the role tag "ESCAPED" is cut to
  "ESCAP" on phones, and the header says "1 crossings" (no singular).
- **Stage 6 fixes (17 Oct ~11:50Z):** EggUIController's `show()` now also toggles the plate's `DropShadow` (the sibling the
  export puts just before each plate). Without it a chip built in its Open state kept Open's opaque shadow over its `Sel`
  plate, so a selected family chip drew black (seen live with Decoy focused). The focus ring (`FocusSel` plus its exported
  outline twins `ShadowRing`) now moves to the selected chip: the chips are re-anchored at their centre by the juicy-button
  setup, so the left edge comes from the chip's AnchorPoint. `EggImageWarm` sits at (0, 0) on screen: an off-screen image
  is never decoded (in-playtest test: 0/9 loaded off screen, 9/9 on screen).
- **Guaranteed upgrade (17 Oct ~17:40Z, Hunter "do it" 17:19):** the card's meter shows the fill toward
  `CHARGE.FULL` (2.0) and lasts the match. When full, the card's `BonusTag` (kept on phones) reads
  "FULL: GUARANTEED UPGRADE" until the next safety; the early-end "BONUS ROLLS xN" text takes the tag while it shows.
  After the match's guarantee is spent (`EOS_EggMeterSpent`), the meter is hidden for the rest of the match. The
  one-time tip reads "Brave plays fill your meter." / "A full meter guarantees an upgrade at safety." The upgrade
  banner's `Sub` reads "GUARANTEED UPGRADE" on a guaranteed step, and so does the results card's `EggHow`
  (a Runner whose egg got its step this match). The incubator's `WeightLine2` is set from `EggConfig.SHARD_WEIGHT`
  (now "Rare 1 · Epic 2 · Legendary 8"). Text only: no new images, no uploads.

## Fixes + full import (17 Oct ~18:30-19:30Z, Hunter "make the fixes and then implement fully")
- **EggIncubator rebuilt** from `egg_incubator_over` (overfill, Lucky Egg pass, hatch boost ladder; export page
  `egg_x_incubator` with every state). `Builder.build()` was run for the templates; the old `EggHUD` and `EggFirstPet`
  screens were put back as they were (their data was unchanged). Fit x2, then `roblox/ui_egg/PostFit.luau` (EggUI copy of
  ui_hc's PostFit: design TextSize inside Big frames, labels widened where Roblox glyphs spill).
- New runtime module `Controllers.EggIncubatorView` (one-line hooks in EggUIController: `init` in init, `refresh` at the end
  of refreshIncubator). It writes:
  - `FillRing` 0 -> cap (36), green to FILL, gold past it; `FillText` "x / 36 FILL"; `FillSub`. The ring marks HATCH / MAX
    are static in the export.
  - `OddsNote` "Odds at N fill" (after the focus cost) and `OddsNote2`.
  - `LuckyTag` + `LuckyOn` when `EOS_LuckyEgg`; `BtnLucky` when not owned and `LUCKY_PASS.gamePassId` ~= 0
    (PromptGamePassPurchase).
  - `BoostTag` "xN BOOST" when a tier is bought. `BtnBoost` ("x2 ODDS" / "UPGRADE TO x3" / "UPGRADE TO x4", `BoostPrice` from
    GetProductInfo, PromptProductPurchase of the next tier). `BtnBoostMax` "x4 MAXED" (no action). All hidden while any
    `HATCH_BOOST.products` id is 0.
  - `BtnHatch` label: HATCH NOW / HATCH (BIGGER ODDS).
- New runtime module `Controllers.EggResultsRow` (one-line hook in applyResults; the two mini-egg refills call
  `EggResultsRow.mini`). In Results v2's `EggBlock` it hides `PieceIcon` / `PieceText` (+ Shadow twins) and parents a clone
  of template `FillLine_<rarity>` named `EggFillLine` at their spot: "+N FILL" pill (N from `SHARD_WEIGHT`) and the
  rarity word. The mini egg reads "x / 18 FILL" (green, 22.5 with a focus) until it can hatch, then "x / 36 FILL" (gold,
  golden egg icon).
- New templates: `FillLine_common/rare/epic/legendary`. New art (6, group 228184582): gold Lucky strip, purple boost plate,
  grey maxed plate, 3 odds-bar fills. Reused: `icon:robux`, `icon:star` (already uploaded for ui_hwn / ui_points).
