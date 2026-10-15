# ChatGPT icon prompt (Evolve or Steal UI)

Paste the **style block** once at the start of the chat, then ask for icons **one per image** (quality drops when several share an image). Save each as `<slug>.png` and drop them in `ui/icons_ai/`. Claude then runs them through `ui/tools/outline.py`, so they get the same ink edge and drop shadow as the pet photos, and swaps them in by slug.

Pets and eggs are **not** on this list. They're photographed from the game's own models (`Workspace.FWP_PetShowroom`).

Note: the `roblox-ui-maker` skill has a "no AI-generated icons" rule by default. Using these means Hunter overrides that rule for this game.

---

## Style block (paste first)

```
You are making game UI icons for a bright, cute Roblox game called "Evolve or Steal" (kids chase each other carrying eggs; eggs hatch into pets). Every icon must follow this exact style so they match as a set:

- Glossy cartoon "candy" style, like premium Roblox simulator UI icons: chunky rounded shapes, bold readable silhouette at small size (must read at 48 px).
- Thick, even outer outline in very dark purple (#1b0a2b), about 6% of the icon width, same thickness on every icon.
- Soft 3-tone shading: light top-left, saturated middle, deeper bottom-right. One or two crisp white glint highlights on the top-left. No gradients that go muddy.
- Saturated, cheerful colours (candy pink, lime, sky blue, sunny gold, violet). No dull greys unless the object is metal.
- Front or slight 3/4 view, centred, filling about 85% of the canvas, nothing cut off.
- TRANSPARENT background (PNG with alpha). No background shape, no shadow on the ground, no glow halo, no frame.
- NO text, letters or numbers anywhere in the image. No watermark, no signature.
- 1024 x 1024 square.
Reply with one image per message. Wait for my next icon request.
```

## Icons to request (one per message: "Icon: <slug> — <description>")

**Currencies**
- `gold`: a thick gold coin with a raised star in the middle
- `gem`: a faceted emerald-green gem, classic diamond cut
- `robux`: a green hexagon token with a square cut-out (Robux-style, generic)

**Egg pieces (crafting materials: cracked eggshell halves, top and bottom slightly apart)**
- `piece_common`: white eggshell with small green square spots (Basic egg)
- `piece_rare`: pale sky-blue eggshell with white square spots (Shiny egg)
- `piece_epic`: deep violet eggshell with cyan square spots (Cosmic egg)
- `piece_crowned`: shiny gold eggshell with white square spots (Golden egg)

**Menu buttons**
- `quests`: a rolled parchment scroll with a green checkmark badge in the corner
- `incubator`: an egg under a glass dome on a gold base
- `pets`: an orange paw print
- `shop`: a pink shopping bag with a gold star on it
- `stats`: three bars (blue, gold, green) on a white rounded card
- `settings`: a silver cog wheel
- `afk`: a yellow crescent moon with small "z" shapes, drawn as shapes, not letters
- `hunt`: a red crosshair or target reticle

**Roles and match**
- `runner`: a blue sneaker with speed lines
- `catcher`: a cartoon toy knife or dagger with a gold guard (friendly, not gory)
- `safe`: a green flag with a white checkmark
- `steal`: a hand grabbing a white spotted egg
- `trophy`: a gold trophy cup
- `crown`: a gold crown with three coloured jewels
- `star`: a gold five-point star
- `lock`: a gold padlock
- `check`: a green circle with a white checkmark
- `clock`: a blue alarm clock or stopwatch face
- `gift`: a pink gift box with a gold ribbon
- `dice`: a white die with pink dots (random choice)
- `target`: a red and white bullseye (focused choice)
- `sound`: a speaker with sound waves
- `controls`: a dark game controller with coloured buttons
- `refresh`: a purple circular arrow
- `info`: a blue circle with a white "i" shape (draw it as a dot and bar, not a letter)
- `plus`: a green plus sign

**Pet abilities (one per ability pool)**
- `ab_dash`: double orange chevrons pointing right (Double Dash)
- `ab_invis`: a cute pale-blue ghost, semi-transparent (Invisibility)
- `ab_decoy`: two figures, one solid gold and one faded copy behind it (Decoy)
- `ab_shield`: a teal bubble with a shield emblem inside (Shield)
- `ab_wall`: a short wall of lavender bricks (Wall)
- `ab_tackle`: a red boxing glove with impact lines (Pet Tackle)

**Shop cosmetics**
- `trail`: a comet star with a sparkly gold trail
- `burst`: a party popper with confetti
- `case`: a clear crystal shield around a white egg
- `entrance`: a blue lightning bolt
- `abilityfx`: a painter's palette with coloured paint dots
- `hatchfx`: a cracked-open egg with gold sparkles
- `emote`: a happy yellow smiley face
