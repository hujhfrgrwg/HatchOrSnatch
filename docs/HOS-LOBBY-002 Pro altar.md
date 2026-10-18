---
tags: [delivery]
ticket: HOS-LOBBY-002
date: 2026-10-17
---
# HOS-LOBBY-002: Pro altar

An altar in the middle of the Halloween lobby plaza, based on Matthew's concept (`HOS-LOBBY-002 altar reference.webp`), built in the lobby's own style. The centre is a **summoning circle**: players stand in it to enter.

Revision (18 Oct 2026, Matthew):

- **Wider:** the dais is 17 instead of 14, and the walkway between the corner blocks 7 instead of 6.
- **Shorter corner blocks:** they now rise 0.6 above the dais floor instead of 1.8.
- **Centre:** the pedestal and trophy were replaced by the summoning circle.

Revision 2 (18 Oct 2026, Matthew: lower, wider, more room in the middle):

- **Lower:** steps are 0.5 instead of 0.8, so the dais is 1.5 tall instead of 2.4. The corner plinths, lamps and obelisks drop with it.
- **Wider:** the dais is 22 instead of 17.
- **More room in the middle:** the open centre and walkways are 11 wide instead of 7. The summoning circle is 1.2× bigger (r ≈ 3.8).

## Where and how big

- **Location:** `Workspace.CentralAltar.ProAltar`, centred on the plaza centre (0, 1500), sitting on `Ground_Plaza` (y 10.05). Its pivot is that centre point.
- **Footprint:** about 31 × 31 studs including the outer jack-o'-lanterns. The stone dais is 22 × 22, or 25.5 across to the bottoms of the stairs. The plaza is 80 × 84, and nothing else in the lobby is within 2 studs of the altar.
- **Height:** the dais is 1.5 tall; 11.7 studs to the lamp-post finials.

## What's in it

| Part | Notes |
|---|---|
| **Dais** | 22 × 22, 1.5 tall (three 0.5 risers). A stair flight on each side; every step nose has a neon orange strip. The cheek walls step down with the stairs. |
| **Corner blocks** (4) | 5.5 × 5.5 low stone plinths rising 0.6 above the dais floor (1.0 with the cap). They have a base course, a capped top and relief cracks like the kit's stone blocks. Between them is an 11 × 11 open centre with 11-wide walkways to the stairs. |
| **Candles** | Kit large/medium/small candles on three corners of each cap. |
| **Lamp posts** (NE and SW corners) | Iron post, crossbar, two kit hanging lanterns and a purple banner with a gold crown on both faces and a split tail. |
| **Obelisks** (NW and SE corners) | Stepped stone spire with purple neon panels, gold gems, a neon tip and a purple PointLight. |
| **Spiked fences** | Low wooden fences hugging each corner block's two outer faces. |
| **Jack-o'-lanterns** (4) | Kit `A04_JackOLantern` at 0.85 scale, one outside each corner, facing out. |
| **Summoning circle** | A round stepped floor disc (r ≈ 3.8, set by `CIRCLE`) at the centre of the dais. It has a purple outer ring and an orange inner ring (24 neon segments each at 15° steps), eight purple runes between the rings and a glowing diamond sigil in the middle. Purple motes rise from it and a purple PointLight lights it. Players stand on it to enter. |
| **SummonZone** | `SummoningCircle.SummonZone`: invisible, no collision, 7.4 × 7 × 7.4 over the circle. It's a ready-made volume for the enter/summon code (e.g. `GetPartsInPart`). Its `Purpose` attribute explains it. **Not wired to any code yet.** |

## Style

- **Lobby rules:** Plastic with Studs surfaces (the lobby uses SurfaceTypes, not MaterialVariants). Neon only for glow strips, panels and the summoning circle's rings, runes and sigil.
- **Colours:** read from the lobby's kit and old central shrine.
  - Stone: 93,83,121 / 84,72,110 / 74,63,99 / 47,41,68.
  - Glow: orange 255,122,26, purple 180,92,255.
  - Gold: 255,194,58.
  - Wood: 62,46,44 / 77,56,51.
- **Kit pieces reused:** candles, hanging lanterns and jack-o'-lanterns come from `ServerStorage.HalloweenLobbyKit`, so they match the rest of the lobby exactly.

## Rebuilding

`tools/build/HOS-LOBBY-002_pro_altar.lua` builds the whole altar. Run it in Studio's command bar (or `execute_luau`). It replaces any existing `CentralAltar.ProAltar` and records an undo step. All sizes come from the variables at the top: `HALF` (dais half-width), `ARM` (half-width of the open centre and walkways), `RISE` (step height), `TREAD`, `CB_TOP` (corner plinth height) and `CIRCLE` (summoning circle scale).

## Checks

- **Nothing in the way:** no other lobby part is inside the altar's bounds. The one exception is the old shrine's `A10_FireLight_OPTIONAL`, an invisible light that was already there; it adds warm light over the circle.
- **Circle fit:** every ring, rune and sigil corner sits on the disc. The SummonZone touches no corner block.
- **Coplanar sweep:** no visible coplanar faces. The only remaining hits are crack plates' back faces buried in the stone. The altar sits at z ≈ 1500, where float precision is about 0.0001 studs, so the anti-flicker offsets are 0.002–0.01 rather than 0.0001.
- **Screenshots:** a diagonal three-quarter view and a straight-on front view of the first version. I couldn't screenshot either revision: Studio's capture kept returning another window on Matthew's PC.
