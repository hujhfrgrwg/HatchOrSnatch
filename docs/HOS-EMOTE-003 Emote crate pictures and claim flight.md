---
tags: [delivery]
ticket: HOS-EMOTE-003
updated: 2026-10-18
---
# HOS-EMOTE-003 Emote crate: emote pictures, hide the screen behind, Claim flies to Backpack

Matthew (18 Oct): "Need to fix the roll animation to have the 2d images of the emotes here. When the emote crate shows you which one you got, it needs to disappear the shop UI behind it. when they hit claim, the 2d emote icon should go tween to the player's hud backpack".

## What changed
- **Emote pictures on the reel and the reveal card.**
  - The game has no 2D emote icons; the tiles showed the template's dashed placeholder.
  - Each tile now shows your avatar frozen in that emote's most expressive keyframe (the one that moves furthest from the rest pose, in the middle 70% of the clip).
  - The poses come from the clips in `ReplicatedStorage.EOS_Emotes`. All 51 emotes work, nothing to upload, and new emotes get a picture automatically.
  - Each pose is built once per emote and reused. The cache clears when your avatar reloads.
- **The screen behind goes away.** When a crate opening starts, whatever EOSUI screen was open closes, the Shop included (before, only the Emotes screen did).
  - This covers a Robux crate bought from the Shop, whose result arrives while the Shop is open.
  - If you opened it from the Emotes screen, Emotes comes back afterwards, as before (after the flight has landed).
  - The Shop doesn't come back, so the flight to Backpack is the last thing you see.
- **Claim flies the emote into Backpack.** On Claim, the reveal card's picture:
  - pops up a little, then curves down into the HUD's BACKPACK button (`HUD.Rail.PetsButton`), shrinking as it goes;
  - lands with the "reward" sound, a sparkle and a bump of the button.
  - Duplicates don't fly; they refund Gems.

## Scripts
- `StarterPlayerScripts.EOS.Controllers.EmoteController`:
  - a new block before the crate-opening section (`keyPose`, `poseRig`, `emoteStill`, `stillView`, `decorateTile`, `flyToBackpack`; source in `tools/build/HOS-EMOTE-003/emote_stills_block.lua`);
  - `onOpened` closes any open screen;
  - `onClosed` waits for the flight before reopening Emotes;
  - `Spin.init` gets `decorateTile` and `onClaim`.
- `StarterGui.EmoteCrateUI.EmoteCrateSpin`, and its builder copy `ServerStorage.EmoteCrateUIBuild.Client.EmoteCrateSpin`: two new optional hooks.
  - `decorateTile(tile, emote)`, called for every reel tile and the reveal's big tile.
  - `onClaim(result, revealTile)`, called when Claim (or Escape / B) is pressed, before the screen closes.
- Pre-edit copies: `docs/backups/HOS-EMOTE-003_2026-10-18/`. ScriptHistory is updated.

## Checked in a playtest
- **From the Emotes crate page:** the Emotes screen closed, the reel showed 48 posed tiles, and the reveal showed the prize's pose. Claim flew it to Backpack, and Emotes came back afterwards.
- **With the Shop open:** the Shop was hidden for the whole opening. The flight was logged ending at the Backpack button's centre (47, 281).
- No script errors.
- Screenshots: `docs/HOS-EMOTE-003/reel_emote_stills.jpg`, `reveal_shop_hidden.jpg`, `claim_flight.jpg`.

## Not changed (seen while testing)
- **"Opening..." stage:** it shows no crate picture, because `crateImage` isn't passed to the spin.
- **"Open again" button:** its Gems icon is a blank placeholder.
