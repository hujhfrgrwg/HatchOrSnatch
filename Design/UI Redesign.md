---
tags: [design, ui]
updated: 2026-10-15
---
# UI redesign (neon style)

Hunter asked on 15 Oct 2026 for a premium UI that matches two reference images: a green "Season Pass" and a red "Settings" screen, both by a commissioned UI artist. The work follows `roblox-ui-maker`: HTML first, Hunter approves, then export to a real ScreenGui in Studio. **Status: round 1 (neon) rejected on 15 Oct 2026: "great job copying it, but this UI doesn't match our game or its theme at all." The direction is open again; see `docs/ui/direction_board.jpg` (A bright stud recommended, B Huss Valley clean). Nothing has been changed in Studio.** The lesson is saved in the ui-maker LESSONS (check a reference against the game's world before building from it).

## Where things are
| | |
|---|---|
| Source | `ui/build.py` (all pages), `ui/styles/neon.css` (the style), `ui/kit.css` (skill base) |
| Textures | ui-resources.com, fetched with `ui/tools/fetch_textures.py`. Sources and credits are in `ui/tools/textures.json`. The files themselves aren't committed |
| Icons | **Placeholders** I drew in SVG (`ui/tools/icons_svg.py` → `icons/`). Keep the slugs when a licensed pack replaces them |
| References | `ui/ref.png` (Season Pass), `ui/ref2.png` (Settings) |
| Backgrounds | `ui/bg_lobby*.jpg`, cropped from a Studio capture of the Hatch or Snatch lobby |
| Round 1 shots | `docs/ui/round1/` |

To run it: `cd ui && python3 tools/fetch_textures.py && python3 tools/icons_svg.py && node tools/render_icons.mjs && python3 build.py && python3 -m http.server 8870`, then open `/index.html`. `node tools/shoot.mjs` renders `shots/*.png`.

## The style (inspired by, not a copy)
- **Banner titles:** an angled ribbon with a notched tail. The face is a bright gradient with halftone dots and light streaks, and a sparkle sits at the tip. The text is heavy italic Montserrat with a black outline.
- **Panels:** a dark body tinted with the screen's accent. It has a neon accent edge with a black outline, an outer glow, a grid texture, halftone dots in the corners, and an angled dark slab behind it with an accent edge.
- **Buttons:** chamfered corners, a gradient face with a top shine and a scratched sheen, and a darker lip. Green means go, red/pink means close, silver means off or inactive.
- **Tiles:** diagonal stripes and halftone, colour-coded by rarity (Common cream, Rare blue, Epic purple) or by family (Decoy gold, Scout cyan, Brake lime). Selected tiles get a white glow, and locked or empty ones go grey.
- **One accent per screen:** Incubator lime, Settings red, Shop gold, Pets cyan, Quests purple, Stats gold.
- **Close button:** a pink parallelogram with a text "X".

## Round 1 pages
1. `style.html`: both references, then the kit in every accent and state.
2. `hud.html`: the lobby HUD. Quests and Incubator pills, a first-pet goal pill, a compact LOBBY timer, Stats and Settings, a left rail (Shop, Pets, AFK, Hunt with ON/OFF chips), Gems and Gold, and the equipped-ability card.
3. `hud_match.html`: the match HUD. Following GDD 14, the economy and menus hide. It shows the role tag, the crossing chip with the big timer, Runner and Catcher counts, clean-streak pips (the code's current match-end rule), the egg level with 4 pips and the tier it pays, the ability cooldown, a Dash chip and a steal feed.
4. `incubator.html`: piece counts, a first-pet track in the Season Pass style, tier tabs showing counts against the recipe, three family cards (Decoy/Scout/Brake with their Common species and cooldowns), and a hatch box with the free first-pet choice. The random/choose costs come from EconomyConfig.
5. `settings.html`: the real settings only (Reduce Effects, Show Hints, Volunteer To Hunt) with Game/Audio/Controls tabs.

## Open questions for Hunter
- Does round 1 match the look you want? It needs approval before more screens are built.
- **Icon pack:** the placeholders work, but a licensed pack (RoClicks suggests Vector Icon Pack Pro) or an artist would lift the item art.
- **Exporting to Roblox:** the big panel bodies become images, and Roblox caps images at 1024 px. Before import they need splitting into 9-slice pieces (a fixed corner and edge art with a native glow), or the panels stay fixed-size.
- **Fonts:** Montserrat Italic needs a check in Studio (`FontFace` with `Enum.FontStyle.Italic`).

## Next rounds
Shop (Gold and Gem tabs, every item state), Pets (collection and equip), Quests, Stats, Results (podium, thief, your breakdown per GDD 14), toasts and the confirm dialog, the phone HUD, and a states sheet.
