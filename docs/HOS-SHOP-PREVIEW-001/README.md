# Shop pet preview on hover (HOS-SHOP-PREVIEW-001, 17 Oct 2026)

Hunter 16:33: "in our shop, if you hover over the item, such as the bone dragon pet, it should tween in that frame to a
viewport preview of the pet doing animations or something on a backdrop". 16:43: "shouldnt we try to find a way to
showcase the ability vfx and effect". 16:47 "looks phenemenal! implement"; 16:51 "shared-scripts OK", "playtest OK".
Review page: https://claude.ai/artifact/WRXgaEQnSq9ju4GNUnp6Tc (mockups, then the live clip and stills).

## What it does
- Hover a Featured pet card (after 0.08 s), or tap its art on a touch screen: the art box tweens (0.25 s Quad Out) into a
  stage with 10 px padding. It shows a backdrop in the card's colour and the pet's own rig in a ViewportFrame. The pet loops
  Idle, then its move clip, then a cast. Casts alternate Runner and Catcher each lap (Dragon: BREATH / SLAM, Jack-o'-Lantern:
  VANISH / STALK, Mummy: SHIELD / LASH, Cat: CLONE / SNARE).
- The cast plays the pet's real summon effect (`ReplicatedStorage.VFX.<name>_L<level>`, at the behaviour module's FLASH_AT).
  ViewportFrames draw no particles, so every ParticleEmitter in the template is redrawn as ImageLabels from its own texture,
  colour, size, transparency, lifetime, speed, spread, acceleration, drag, rotation, flipbook, EmitDelay and EmitCount /
  EmitDuration. Big sprites go behind the pet, small ones in front. Visible parts of a template play inside the viewport
  through `VFX.Emit`. Knobs: `FX_SCALE` 0.5 and `FX_ALPHA` 0.9, so the pet stays readable at the close card camera.
- Invisibility casts fade the pet after the flash and bring it back.
- Title, ability and buy button never move. The tagline swaps for IDLE / move / cast chips, which are clones of the card's
  RarityTag. Resting cards get a PREVIEW chip (TAP TO PREVIEW on touch).
- Touch: a tap on a card opens it; tapping it again or another card flips back. Buy buttons are left alone, so buying is one tap.
- Reduce effects: the pet holds a still idle pose, with no chips and no effect layer.
- The card closes and everything is destroyed (viewport, rig, labels, connections) when the mouse leaves, the shop
  closes, or the card hides. The card always returns to its captured at-rest values, so a fast in/out can't leave it faded.

## Changes in the place
- New `StarterPlayer.StarterPlayerScripts.EOS.Controllers.ShopPetPreview` (source `roblox/game/shop_preview/ShopPetPreview.luau`).
- `Controllers.HalloweenShopUI.slots`: one line after `map[tpl] = id`:
  `require(script.Parent.ShopPetPreview).attach(card, id)`. Backup and undo steps: `docs/backups/HOS-SHOP-PREVIEW-001_20261017/`.
- `ReplicatedStorage.EOS.Assets.Pets` Bone Dragon, Pumpkin Wraith, Mummy, Witch's Cat: added the `ColorMap` attribute on
  their 48 SurfaceAppearances, copied from each one's own ColorMap. ViewportFrames don't draw SurfaceAppearance, so this is
  the attribute PetPreview (Pets > VIEW 3D) already reads. Those pets also show textured in VIEW 3D now. Nothing else changed.
- UIController untouched (200-local limit).
- Backdrops uploaded (group 228184582), listed in `docs/VFX-LEDGER.md`: violet / orange / sky / lime images
  126543247334245 / 119860466123113 / 98575396374871 / 129629158117711 (source PNGs `Assets/Images/ShopPreview/`).

## Checked in solo playtests (17 Oct)
- Bone Dragon and Jack-o'-Lantern previews live, with their own effects (`live/still_dragon_breath.png`,
  `live/still_jack_vanish.png`) and a slow-motion clip of one hover cycle (`live/shop_preview_live.mp4` / `.gif`, played at
  0.3x so the beats read).
- Hover in, cycle, hover out, and rapid in/out: the card comes back exactly at rest, with no errors in the client log.
- How the test was set up: the playtest dropped into a sandbox match, so I set `workspace.HWN_TestTime` to Oct 24 01:00 (the
  Dragon rotation), showed the Shop panel directly, and freed the locked mouse. These were all inside the playtest only.
- Not checked: a real phone tap (Studio sends mouse clicks; the touch path is code-read only), the Mummy and Cat casts,
  gamepad, a session where the first hover lands before the backdrop finishes loading (it preloads on attach), and Reduce
  effects in play.
