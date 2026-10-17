---
tags: [delivery]
ticket: HOS-LOBBY-002
date: 2026-10-17
---
# HOS-LOBBY-002: Pro altar

A small trophy altar in the middle of the Halloween lobby plaza, based on Matthew's concept (`HOS-LOBBY-002 altar reference.webp`), built in the lobby's own style.

## Where and how big

- **Location:** `Workspace.CentralAltar.ProAltar`, centred on the plaza centre (0, 1500), sitting on `Ground_Plaza` (y 10.05). Its pivot is that centre point.
- **Footprint:** about 23 × 23 studs including the outer jack-o'-lanterns. The stone dais is 14 × 14, or 17.5 across to the bottoms of the stairs. The plaza is 80 × 84.
- **Height:** 13.8 studs to the lamp-post finials.

## What's in it

| Part | Notes |
|---|---|
| **Dais** | 14 × 14, 2.4 tall (three 0.8 risers). A stair flight on each side; every step nose has a neon orange strip. The cheek walls step down with the stairs. |
| **Corner blocks** (4) | 4 × 4 stone blocks rising 1.8 above the dais. They have a base course, a band at the floor line, a capped top and relief cracks like the kit's stone blocks. The cross between them is a 6-wide walkway with room to walk round the pedestal. |
| **Candles** | Kit large/medium/small candles on three corners of each cap. |
| **Lamp posts** (NE and SW corners) | Iron post, crossbar, two kit hanging lanterns and a purple banner with a gold crown on both faces and a split tail. |
| **Obelisks** (NW and SE corners) | Stepped stone spire with purple neon panels, gold gems, a neon tip and a purple PointLight. |
| **Spiked fences** | Low wooden fences hugging each corner block's two outer faces. |
| **Jack-o'-lanterns** (4) | Kit `A04_JackOLantern` at 0.85 scale, one outside each corner, facing out. |
| **Pedestal** | Dark body with gold corner strips and lip. A glowing gold crown (band, stepped points, jewel dots) on all four faces. Purple neon gems at the corners of the floor medallion. |
| **Trophy** | Stepped gold cup with handles and dark inner rim, on a neon gold pad with a gold PointLight and soft gold sparkles. |

## Style

- **Lobby rules:** Plastic with Studs surfaces (the lobby uses SurfaceTypes, not MaterialVariants). Neon only for glow strips, panels and the crown/pad.
- **Colours:** read from the lobby's kit and old central shrine.
  - Stone: 93,83,121 / 84,72,110 / 74,63,99 / 47,41,68.
  - Glow: orange 255,122,26, purple 180,92,255.
  - Gold: 255,194,58.
  - Wood: 62,46,44 / 77,56,51.
- **Kit pieces reused:** candles, hanging lanterns and jack-o'-lanterns come from `ServerStorage.HalloweenLobbyKit`, so they match the rest of the lobby exactly.

## Rebuilding

`tools/build/HOS-LOBBY-002_pro_altar.lua` builds the whole altar. Run it in Studio's command bar (or `execute_luau`). It replaces any existing `CentralAltar.ProAltar` and records an undo step. All sizes come from the variables at the top: `HALF`, `ARM`, `RISE`, `TREAD`.

## Checks

- **Nothing in the way:** no other lobby part is inside the altar's bounds. The one exception is the old shrine's `A10_FireLight_OPTIONAL`, an invisible light that was already there; it now adds warm light to the top of the altar.
- **Coplanar sweep:** no visible coplanar faces. The only remaining hits are crack plates' back faces buried in the stone. The altar sits at z ≈ 1500, where float precision is about 0.0001 studs, so the anti-flicker offsets are 0.002–0.01 rather than 0.0001.
- **Screenshots:** a diagonal three-quarter view and a straight-on front view.
