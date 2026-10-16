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
- `servers`: a chunky teal-green globe with bold meridian lines and a small white signal arc over the top
- `spectate`: a sporty eye or binoculars with a glowing blue lens
- `quests`: a clipboard or bounty board with a bold checkmark
- `incubator`: a sci-fi incubator capsule holding an egg, with metal ring and glowing glass
- `pets`: a bold paw print, angular, with a slight metallic sheen
- `shop`: a shopping bag with a lightning bolt emblem
- `stats`: a podium or bar chart with a trophy star
- `settings`: a chunky steel cog
- `afk`: a pause symbol over a small moon (the AFK button when off: "go AFK"; the game greys it)
- `afk_on`: the same moon with a play triangle instead of the pause bars (the AFK button when on: "come back")
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
- `servers`: a chunky teal-green globe with bold meridian lines and a small white signal arc over the top (the Servers button). A drawn stand-in is in use.
- `spectate`: a sporty eye or a pair of binoculars with a glowing blue lens (the SPECTATE pill). A drawn stand-in is in use.

`afk_on` (the play moon) arrived on 16 Oct; it's uploaded but unused (Hunter kept one drawing per toggle).

Hunter's second zip (16 Oct) brought `case`, `entrance`, `ab_scout`, `ab_brake` and `ab_spring`. `case_frost` and `case_sunset` are recoloured from the new `case` by `ui/tools/icon_variants.py`. The first zip brought `safe`, `catcher`, `runner`, `hunt` and `afk`.

## Gem pack art (Shop > Gems, 16 Oct)
Six pack images for the six Robux Gem packs, small to big. Same style block as above, one per message. They must read as a set that clearly grows, so the 5,000 pack looks worth it. Save as `gempack1.png` … `gempack6.png`.

- `gempack1` (100 Gems): a small handful of three sharp emerald-green faceted gems, slightly tilted, lying together.
- `gempack2` (225 Gems): a small pile of about eight emerald-green faceted gems with a couple of sparkles.
- `gempack3` (500 Gems): a sturdy dark-leather pouch with a gold drawstring, bursting open with emerald gems spilling out the top.
- `gempack4` (1,100 Gems): a dark wooden bucket with metal bands, overflowing with emerald gems.
- `gempack5` (2,400 Gems): an open steel-and-gold treasure chest packed with emerald gems, a few gems tumbling over the edge, a soft green glow from inside.
- `gempack6` (5,000 Gems): a huge heaped mountain of emerald gems with a large chest behind it, gold trim, strong green glow and sparkles, the most impressive of the set.

## Game pass art (VIP and 2x Gold, 16 Oct)
Two pass icons, used on the Roblox store page and in the Shop. Paste the style block first, then the prompt. These two are the only icons allowed text (the pass name is part of the art, like the Huss Valley references). Roblox crops pass icons to a circle, so keep everything inside the middle 80%. Save as `pass_vip.png` and `pass_gold2x.png`.

- `pass_vip`: "Make the VIP game pass icon. Exception to the no-text rule: the bold letters VIP are part of the art. A heavy gold crest/shield with the word VIP in thick bevelled gold capitals across it, a sharp gold crown on top with one cyan diamond in its centre band, small gold laurel wings at the sides. Polished metallic gold with hard specular highlights, near-black outline, a few crisp white sparkles. Premium, competitive, not cute. Keep the whole crest inside the middle 80% of the canvas (Roblox shows it in a circle). Transparent background."
- `pass_gold2x`: "Make the 2x Gold game pass icon. Exception to the no-text rule: big bold 2X is part of the art. A large stack of thick shiny gold coins (our Gold coin: a round gold coin with a raised star in the middle) tilted at an energetic 3/4 angle, with a huge chunky '2X' in front in orange-to-yellow gradient capitals with a near-black outline and a hard white highlight, and two bold upward cyan chevron arrows behind it. Crisp sparkles. Premium, competitive, not cute. Keep everything inside the middle 80% of the canvas (Roblox shows it in a circle). Transparent background."
