---
tags: [handoff, showcase, cosmetics, lobby]
ticket: HOS-TRAIL-003
date: 2026-10-18
requested_by: Matthew
status: not started in Studio (research done, nothing edited yet)
---
# HOS-TRAIL-003 handoff: trail showcase on Podium_Crown

## The request (Matthew, verbatim)
"Ok Now on the Podium_Crown, display their character running and the trail behind them. Have the rig be sideways instead of facing the front so the trail can show. show the dash animation beams too. keep the rig in the middle during the dash but have the beams be sideways. for the dash one we can have the player face the front"

**Nothing has been changed in Studio or the repo for this ticket yet.** Everything below is research and a plan.

## Where things stand (all done, committed and pushed to `matthew`)
- HOS-PREV-001: trail shop preview fixed.
- HOS-TRAIL-001:
  - Matthew (user 2403942283, "ssported") gets every trail on load (`EconomyService.TESTERS`).
  - The equipped trail shows on your back in the lobby.
  - No egg in the preview.
- HOS-TRAIL-002:
  - The dash streaks (`SlideFX`) wear the trail: Player attribute `EOS_Trail`, Brightness 1 when dressed.
  - Every trail look lives in the new `ReplicatedStorage.EOS.Shared.TrailLook` (`LAYERS`, `RAINBOW`, `color(item)`).
- Still waiting on Matthew: the HOS-SHOW-002 overhead mockup (docs/HOS-SHOW-002/).

## Facts gathered
- **Podium_Crown:** `Workspace._PodiumPreview.Podium_Crown`, pivot (-25.65, 9.6, 1452.15), about 8.6 studs across. It has no tag yet.
  - `StandGlow.RigStand` world position: (-25.65, 11.47, 1452.15).
  - It has a `Dummy` whose look is (0.53, 0, 0.85), toward the lobby.
  - Master copy: `ServerStorage.HOS_RigPodiums.Podium_Crown`.
  - Build script: `tools/build/HOS-POD-001_rig_podiums.lua`, `buildCrown`, about line 115. Add the tag there like `buildObelisk` does at line 155.
- **Avatar copy:** avatars are R6 (`Torso`). Copy the pattern from `Controllers.WeaponShowcase` (in ScriptHistory, it matches Studio):
  - `WeaponPedestals.makeAvatarTemplate(char)` makes the copy, re-taken on `CharacterAdded`.
  - Root anchored at `stand + (0, leg.Y + torso.Y/2, 0)`.
  - The Dummy is removed on the client only.
  - A `refresh` handles streaming.
  - Everything rests while `LobbyGate.active()` is false (the API also has `near(pos, ANIM_RANGE=60)` and `centre()`).
  - Copies go in a client-only workspace folder.
- **Animations** (`AnimConfig.ids`):
  - `Run` = rbxassetid://87156589310850 (Runners use it at 14+ studs/s).
  - `DashLeft` = 124658835855251, `DashRight` = 107227095081492, `DashBack` = 115077148052587.
  - `builtin.Idle` = 180435571.
- **Dash timings** (`GameConfig.Dash`): SPEED 58, BURST_TIME 0.16, RECOVER_TIME 0.24, ANIM_SPEED 1.15.
- **Trails** (`EconomyConfig.SHOP`): `trail_spark`, `trail_ember` (kind `trail`, one-match), `trailp_rainbow` (kind `trailPerm`).
  - Looks come from `TrailLook.LAYERS[id]` (tex, width, life) and `TrailLook.color(item)`.
  - The real trail (`EconomyService.trailOn`):
    - per layer, attachments at the base's +0.1 and +0.1+0.8×width;
    - Stretch texture, LightEmission 0.6, FaceCamera;
    - Transparency from 0.1 (layer 1) or 0.35 (others) up to 1;
    - Sparkle and Ember add a sparkles ParticleEmitter (`rbxasset://textures/particles/sparkles_main.dds`, Rate 18, Life 0.4–0.7, ember accel +4 Y, spark −2 Y).
  - Lobby/preview anchor spot: `torso.CFrame * CFrame.new(0, -0.55, torso.Size.Z/2 + 0.1)`.
- **SlideFX** (`Controllers.SlideFX`, 11,577 bytes):
  - `SlideFX.play(char, side)` builds trails on any model that has `HumanoidRootPart` and `Torso`: scuff, core, edges, two air lines and dust.
  - The trails stay on for `BURST_TIME + RECOVER_TIME - 0.04` seconds.
  - Floor spans lie front-to-back for "Left"/"Right" slides. They follow `AssemblyLinearVelocity` only when it's over 6, so an anchored part keeps the first lay.
  - `dress(rig, char)` reads the owner's `EOS_Trail` through `Players:GetPlayerFromCharacter`.
  - It's triggered automatically only for player characters and NPCs, so a showcase copy needs no guard against double triggers.
- **Walk-up prompt:** `UIC.openShopTab(tab)` accepts `gold, getgems, gems, passes, featured, cosmetics, emotes, weapons`.
  - `Controllers.ShowcasePrompts` maps tag to tab in `SHOWCASES`.
  - Add `{ tag = "HOS_TrailShowcase", tab = "cosmetics", action = "View in Shop", object = "Egg Trails" }` so this podium matches the other three. Matthew asked for walk-up GUIs on all showcases earlier.

## Plan
1. **New client module, `StarterPlayer.StarterPlayerScripts.EOS.Controllers.TrailShowcase`.**
   - Start it from `EOS.WeaponFXBoot`. That file is CRLF: normalise to LF, edit, convert back. Add a start line next to the other showcase start lines at the end of the file.
   - Tag: `HOS_TrailShowcase`.
   - It cycles every shop trail (Sparkle → Ember → Rainbow). Per trail:
     - **RUN (about 4.5 s).**
       - Avatar copy faces sideways (`stand.RightVector`), so the profile shows to the lobby; Run clip looped.
       - The trail behind it uses **Beams**, not Trails, because a Trail needs the body to move. Per layer, one Beam:
         - A0: an attachment on the copy's Torso at the anchor spot, raised to the layer's middle (0.1 + 0.4×width).
         - A1: an attachment on an anchored invisible part, about 7 studs × (layer.life / longest life) behind (−runDir).
         - Width0 = Width1 = 0.8×width; FaceCamera; LightEmission 0.6.
         - TextureMode Stretch, TextureSpeed about 1.5 (check it flows away from the body).
         - Color = `TrailLook.color(item)`; Transparency 0.1 (or 0.35) up to 1; Segments about 12.
       - Sparkle/Ember: the sparkles emitter on A0, with Acceleration toward −runDir (about −18) plus the item's up/down drift, so the sparks stream back.
     - **DASH (about 3 s).**
       - Copy turns to face the front (`stand.LookVector`) and idles.
       - Plays `DashLeft` at speed `ANIM_SPEED`, then about 1 s later `DashRight`. The copy stays in the middle.
       - Streaks: an invisible anchored "ghost" model (`HumanoidRootPart` + `Torso`, transparent, CanCollide/CanQuery off) at the copy's root height.
         - Call `SlideFX.play(ghost, side, trailId)`.
         - Tween the ghost from the side to the middle over BURST_TIME + RECOVER_TIME (ease out).
         - Distance: min(58 × 0.16, 7).
         - DashLeft comes in from the copy's right side (`+stand.RightVector`); DashRight from its left.
         - Ghost root must match the copy's root height: R6 root is 3 studs above the floor, which is what SlideFX's `FLOOR_Y = -2.92` assumes.
     - Clean up beams and emitters between trails.
2. **SlideFX change.**
   - Change `SlideFX.play(char, side, trailId: string?)` to pass `trailId` into `dress`.
   - When it's given, use it instead of the owner's `EOS_Trail`. Everything else in SlideFX stays as is.
3. **Tags.**
   - Add `HOS_TrailShowcase` to Workspace `_PodiumPreview.Podium_Crown` and to `ServerStorage.HOS_RigPodiums.Podium_Crown`.
   - Add it in `buildCrown` in `tools/build/HOS-POD-001_rig_podiums.lua`.
4. **ShowcasePrompts:** add the `SHOWCASES` entry above.
5. **Record.**
   - Backups to `docs/backups/HOS-TRAIL-003_<date>/`: SlideFX, ShowcasePrompts, WeaponFXBoot.
   - ScriptHistory copies, LF, including the new `TrailShowcase.lua`.
   - Report `docs/HOS-TRAIL-003 Crown trail showcase.md` with screenshots.
   - A Home note line under the HOS-TRAIL-002 entry.
   - Commit and push to `matthew` only (pull --rebase first: other sessions push often).

## How this session worked (and the gotchas)
- **Studio MCP:** call `get_connected_instances` first and use the "Hatch or Snatch" instance (`instance:mkr-uhr`, place 128015050187408). Never touch the "VFX" place.
- **Editing scripts:** run exact-replacement patches inside `execute_luau`:
  ```lua
  local function rep(a, b)
  	local i, j = s:find(a, 1, true)
  	assert(i, 'missing')
  	assert(not s:find(a, j + 1, true), 'twice')
  	s = s:sub(1, i - 1) .. b .. s:sub(j + 1)
  end
  ```
  - Strings go in `[===[ ... ]===]`. A newline right after the opening bracket is dropped.
  - `loadstring(s)` must succeed before setting `.Source`.
  - Wrap the change in a ChangeHistoryService recording.
  - Mirror the same replacements on the local copies with Python, then compare length and checksum against Studio: `h = (h*31 + byte) % 1000000007`.
- **Playtests:** `solo_playtest start` sometimes returns "Unknown error", and evals then fail. Stop and start again; that fixes it. Code changes need a fresh playtest.
- **Lobby movement:** the character's WalkSpeed reads 0 in a solo playtest, so drive motion by anchoring the root and setting its CFrame.
- **Screenshots:** they lag about 1–2 s. For short-lived streaks, raise the Trail Lifetimes ×6 on the client (test only) and keep sliding in a background loop.
- **Testing the copy:** `eval_client_runtime` can `require` the controller and read `workspace` (the client-only folder).
- **Don't** read `.Source` on the client.
