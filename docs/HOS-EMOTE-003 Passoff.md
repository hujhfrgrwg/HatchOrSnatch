---
tags: [passoff]
ticket: HOS-EMOTE-003
updated: 2026-10-18
---
# HOS-EMOTE-003 passoff: Emote Crate reveal in the reward-popup look

**Matthew's ask** (18 Oct, with a screenshot of the spin wheel's "YOU WON!" prize popup): "The reward UI needs to look like this for the emote thing."

**Already done and pushed:** the reel shows each emote's pose, the Shop hides during an opening, and Claim flies the emote to Backpack. See [[HOS-EMOTE-003 Emote crate pictures and claim flight]].

## State right now
**In Studio, not saved (Matthew: press Ctrl+S), not committed as a snapshot:**
1. **`StarterGui.EmoteCrateUI.Root.EmoteCrate.Reveal` was rebuilt** by `tools/build/HOS-EMOTE-003/build_reveal.lua`. It's a copy of `EOSUI.Root.Reward.Reveal` over a black `Shade`, with:
   - `Card` (UIScale `CardScale` 0.8, `Base` 0.8);
   - YOU WON!, `Icon`, `ItemName`, `KindText`, `SubText`;
   - `BtnClaim` (COLLECT!, green art) and `BtnAgain` (AGAIN + gem + `Price`, purple NICE! art);
   - `ShortRow`.
   - The reveal has a `Span` attribute of 883 and `HOS_PrizeLook` = true.
   - The old card reveal is in `ServerStorage._Backups.HOS-EMOTE-003_2026-10-18.Reveal_before`.
2. **`reveal()` in `EmoteCrateUI.EmoteCrateSpin`** (and the builder copy `ServerStorage.EmoteCrateUIBuild.Client.EmoteCrateSpin`) was replaced with `tools/build/HOS-EMOTE-003/reveal_fn.lua`. That is the **first** version, without the three fixes below.
   - `init` also reads the `Span` attribute into `design.cardSpan`.
   - Both copies have checksum `29778:780477121`.
3. **Tested in a playtest:** the reveal shows YOU WON!, rays, the emote's pose, the name, "COMMON EMOTE", "New emote!", COLLECT! and AGAIN 250. The Shop was hidden. Screenshot: `docs/HOS-EMOTE-003/reveal_reward_look_wip.png`.
   - **My playtest may still be running. Stop it before editing.**

## Left to do
1. **Apply the three fixes in Studio.** They're already in `tools/build/HOS-EMOTE-003/reveal_fn.lua` on disk; the edit was interrupted, so Studio doesn't have them.
   - **The rarity line came out green.** The label's UIGradient has the exported colour baked in. Set `KindText`'s and `SubText`'s UIGradient `Color` to white.
   - **The reel shows through the shade.** Add `show(find(screen, "Reel"), false)` after the line that hides `CrateTitle`.
   - **How to apply:** a plain-find replace with `execute_luau` on both EmoteCrateSpin copies. The three find/replace pairs are the differences between the first version of `reveal_fn.lua` (git history of this commit) and the current file.
   - **Check:** the expected checksum after the fixes is `30174:772107514`, for the whole module, using the `ck()` hash in the ScriptHistory README style (CRLF→LF, trailing newlines stripped, h=(h*31+byte)%2147483647).
2. **Playtest it all:**
   - **Gems:** give some with `DataService.update(p, "test_gems", function(d) d.gems += 5000 end)` on the server.
   - **Open a crate:** `UI.open("Shop")`, then on the client `Net.event("RequestOpenCrate"):FireServer()`.
   - **Check the reveal:** rarity colour (common = light grey, rare = blue, epic = purple, legendary = gold), and no reel behind it.
   - **Check COLLECT!:** it flies the picture to BACKPACK (`flyToBackpack` looks for `RevealTile` > `EmoteStill`, which the new `reveal()` still makes).
   - **Check AGAIN:** it opens another crate. With too few Gems it greys, shows "Need N more" and toasts.
   - **Duplicates:** the line is gold, with the refund text.
   - **Phone fit:** check it with `set_device_simulator`.
3. **Then:**
   - copy the final `EmoteCrateSpin` into `ScriptHistory/StarterGui/EmoteCrateUI/` and `ScriptHistory/ServerStorage/EmoteCrateUIBuild/Client/`;
   - add a "Reward look" section to `docs/HOS-EMOTE-003 Emote crate pictures and claim flight.md`;
   - commit and push to `matthew` (never `main`);
   - remind Matthew to press Ctrl+S.

## Notes
- **Juiced buttons are centre-anchored at runtime.** `reveal()` positions COLLECT! with `left + width * AnchorPoint.X` and updates `JuiceRest`. COLLECT! sits alone in the middle when AGAIN is hidden.
- **Rebuilding EmoteCrateUI from `ServerStorage.EmoteCrateUIBuild`** would bring back the old card reveal. Run `build_reveal.lua` again after a rebuild.
- **Small problems I saw but didn't fix:** the "Opening..." step shows no crate picture (`crateImage` isn't passed), and the old card's "Open again" had a blank gem icon. The new AGAIN has a real gem.
