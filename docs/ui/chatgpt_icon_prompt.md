# ChatGPT icon prompt (round 3: sporty / competitive)

This is for the round-3 look, a blend of the purple "Summon / BattlePass / Leveling" sheet and the magenta "Inventory" panel (`docs/ui/refs_round3/`): dark panels, hot gradient buttons, bold clean type. The icons have to feel **sporty and competitive, not cute**. The round-2 candy set was "too childish".

**How to use it**
1. Paste the **style block** once.
2. Ask for icons **one per message**: `Icon: <slug>: <description>`.
3. Save each one as `<slug>.png` in `ui/icons_ai/`.
4. Claude trims each icon, fits it to the UI and swaps it in by slug.

If an icon comes out cute (big eyes, faces, chubby shapes, pastel colours), reply: *"Less cute: sharper, more like a competitive shooter / Fortnite item icon."*

Pets and eggs are **not** here. They're photographed from the game's own models (`Workspace.FWP_PetShowroom`).

---

## Style block (paste first)

```
You are making UI icons for a competitive Roblox game called "Evolve or Steal": players sprint across an arena carrying eggs while "Catchers" with knives try to tag them and steal the eggs. The UI is dark charcoal/purple panels with hot magenta, lime, cyan and orange gradient buttons. Icons must look SPORTY and COMPETITIVE, like premium Fortnite / Rivals / Blade Ball item icons. NOT cute, NOT kawaii, NOT a kids' sim.

Rules for every icon, so they match as a set:
- Bold, slightly angular shapes with crisp edges. Strong readable silhouette at 48 px.
- Clean outer outline in near-black (#0c0a12), about 4% of the icon width, same on every icon.
- Glossy semi-3D shading: one strong light from the top-left, a hard specular highlight, a darker rim at the bottom-right. Saturated colours, high contrast, no pastels, no muddy gradients.
- Slight 3/4 dynamic angle where it suits the object (tilted, energetic), centred, filling about 85% of the canvas, nothing cut off.
- No faces, no eyes, no smiles, no cartoon cheeks on objects.
- TRANSPARENT background (PNG with alpha). No background shape, no circle badge behind it, no ground shadow, no glow halo.
- NO text, letters or numbers anywhere. No watermark.
- 1024 x 1024 square.
Reply with ONE image per message, then wait for my next icon.
```

## Icons to request

**Currencies**
- `gold`: a thick gold coin seen at an angle, with an engraved star and a bevelled rim
- `gem`: a sharp emerald-green faceted gem, tilted, with hard facet highlights
- `robux`: a green hexagon token with a square hole (generic Robux style)

**Egg pieces (crafting materials: a jagged cracked eggshell shard, angular, not round-cute)**
- `piece_common`: white shell shard with green square speckles
- `piece_rare`: icy sky-blue shell shard with white square speckles
- `piece_epic`: deep violet shell shard with cyan square speckles, faint inner glow
- `piece_crowned`: polished gold shell shard with white speckles

**Menu buttons**
- `quests`: a clipboard or bounty board with a bold checkmark
- `incubator`: a sci-fi incubator capsule holding an egg, with metal ring and glowing glass
- `pets`: a bold paw print, angular, with a slight metallic sheen
- `shop`: a shopping bag with a lightning bolt emblem
- `stats`: a podium or bar chart with a trophy star
- `settings`: a chunky steel cog
- `afk`: a pause symbol over a small moon
- `hunt`: a red targeting reticle with a crosshair

**Roles and match**
- `runner`: a speed sneaker with motion streaks
- `catcher`: a sleek combat knife (cartoon-game style, clean, no blood)
- `safe`: a checkpoint flag with a checkmark, waving
- `steal`: a gloved hand snatching an egg
- `trophy`: a gold trophy cup with angular handles
- `crown`: a sharp gold crown with a red gem
- `star`: a bevelled gold star
- `lock`: a steel padlock
- `check`: a bold green checkmark (no circle)
- `clock`: a stopwatch
- `gift`: a reward crate with glowing seams
- `dice`: a tilted die (random choice)
- `target`: a bullseye with an arrow in the centre (focused choice)
- `sound`: a speaker with sound waves
- `controls`: a game controller
- `refresh`: a circular arrow
- `info`: an exclamation shield (do not use a letter)

**Pet abilities (the nine ability families, HOS-ABIL-001)**
- `ab_dash`: double forward chevrons with speed trails (Double Dash)
- `ab_invis`: a fading silhouette of a runner made of particles (Invisibility)
- `ab_decoy`: a runner silhouette and a hologram copy offset behind it (Decoy)
- `ab_shield`: a hexagon energy shield bubble (Shield)
- `ab_wall`: a slab of stone bricks rising from the ground (Wall)
- `ab_tackle`: a charging impact burst with a fist (Pet Tackle)
- `ab_scout`: a green radar screen with a sweep beam and three red blips (Scout: see the 3 nearest rivals)
- `ab_brake`: a sneaker skidding to a stop with sparks and skid marks, or a bold arrow cutting a hard 90-degree turn (Brake)
- `ab_spring`: a chunky coil spring launching upward with a lime up-arrow (Spring)

**Shop cosmetics**
- `trail`: a comet streak
- `burst`: an exploding firework
- `case`: a crystal armour shell around an egg (an egg inside clear faceted crystal, NOT a chest)
- `entrance`: a lightning bolt striking the ground with a shockwave ring (NOT a portal)
- `abilityfx`: a spray can with coloured paint splash
- `hatchfx`: an egg cracking open with light beams
- `emote`: a hand making a victory sign (simple glove)

## Still needed (16 Oct)
- `ab_scout`, `ab_brake`, `ab_spring`: new families; drawn stand-ins are in use until these arrive.
- `case` and `entrance`: regenerate; the first batch came back as a loot chest and a portal.

`safe`, `catcher`, `runner`, `hunt` and `afk` arrived in Hunter's zip on 16 Oct. They're in `ui/icons_ai/` and `Assets/UI/icons/`, queued for upload.
