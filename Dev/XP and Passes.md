# XP and Passes

Built 16 Oct 2026 (HOS-PASS-001). Hunter asked for an XP system like Huss Valley's, a VIP pass and a 2x XP pass.

## XP and account level
- **Earning:** every saved match pays XP. The amount is `EconomyConfig.xpFor`: 40 for playing (moved, crossed or tagged), 20 per crossing, 25 for the first steal and 10 for each extra one (up to 3), and 40 for a win. A typical match pays about 100–150 XP. Practice matches (fewer than 4 real players) save nothing, XP included.
- **Levels:** `EconomyConfig.levelFor(xp)`. Level L needs `100 + 25 × (L − 1)` XP to reach the next one, so Level 10 takes about 15 matches.
- **Level-up pay:** each level pays 50 Gold, and every 5th level also pays 10 Gems (`LEVEL_REWARD`). The pay is in the match's own exact-once settlement (`ProfileLogic.applySettlement`, `ctx.economy`).
- **Where it shows:**
  - the nameplate "Lv." is now the account level (it used to be the best egg level);
  - a LEVEL plate with an XP bar sits under the goal pill (`HUD.TopLeft.LevelPlate`);
  - after each match, a toast shows the XP earned, naming each pass bonus;
  - a LEVEL UP! reveal (the Reward screen) opens once the results close.
- **Profile:** `xp` holds total XP, and the player attribute `EOS_Level` holds the level.
- A level changes nothing in a match.

## Passes
| Pass | Id | Price | What it gives |
|---|---|---|---|
| VIP | 2038202784 | 499 R$ | +25% match XP; a gold VIP before your name on the nameplate (`CharacterService.refreshTag`) and in chat (`ChatTags`, TextChatService); the legendary Honored One emote, added to your collection and wheel |
| 2x XP | 2040494361 | 199 R$ | +100% match XP |

- **Stacking:** the bonuses add up. VIP alone pays 1.25x, 2x XP alone pays 2x, and both pay 2.25x (`PassService.boostXp`).
- **Ownership:** `PassService` checks ownership on join and when a purchase finishes. It mirrors ownership to `EOS_VIP` / `EOS_XP2x`, which only the server sets.
- **Shop:** the Shop has a **Passes** tab (seventh tab) with OWNED states. A purchase opens the Reward reveal.
- **Icons:** prompts are in `docs/ui/chatgpt_icon_prompt.md` (`pass_vip`, `pass_xp2x`). Until the art arrives, the runtime uses the crown and star icons. The Roblox pass icons are still the default.
- **History:** the 2x pass was first built as 2x Gold, from the GDD's "2x Gold 199" line. Hunter changed it to 2x XP the same day.
