---
tags: [delivery, lobby]
date: 2026-10-18
---
# HOS-LOBBY-001: one-piece checkered plaza

Asked by Matthew: make the lobby's `Ground_Plaza` the checkered stud look, and one brick instead of the stack of long strips.

## What changed in Studio (place "Hatch or Snatch", 128015050187408)
- `Workspace.Ground.Ground_Plaza` (Model) had 42 `Part`s, all named `Ground_Plaza`: 2-stud-deep strips of different widths that built a stepped circle (Plastic, Dark grey metallic, Studs top). They're replaced by **one** `Part` named `Ground_Plaza` inside the same model.
- The new part is a **Cylinder**, 82 studs across (the strips spanned 80 x 84), 0.06 thick, centered at (0, 10.02, 1500). Its top sits at the same height as the old strips, the colour is the same and it's still anchored and collidable. The cylinder's round face points up (rolled 90 degrees on Z), so its "top" is the part's **Right** face.
- **Checker:** a `Texture` named `Checker`, `rbxassetid://111949839624798` (the same checker the stadium preview uses), Face = Right, StudsPerTileU/V = 8 (4-stud squares), Transparency 0.9.
- **Studs:** cylinders don't draw `Studs` surfaces, so the part uses the MaterialVariant `HOS_Studs`. That's a copy, placed in `MaterialService`, of the `Studs` variant from Vynx's egg pack (`ColorMap 10509831729`, `NormalMap 10509831753`, StudsPerTile 1). The pack's original copy in Workspace wasn't touched.
- No scripts reference `Ground_Plaza` (searched all 520 scripts), so nothing else needed changing.

## Why a cylinder
The orange `Ground_Ring` under the plaza is a full disc rather than a band, so a square brick would cover the ring's corners and stick out over the dark ground. A cylinder keeps the plaza round with one part. The edge is now a smooth circle where it used to be stepped, so the orange ring shows as a band of slightly varying width with a smooth inside edge and a stepped outside edge.

## Backup and undo
- The old strips are in `docs/backups/HOS-LOBBY-001_2026-10-18/Ground_Plaza.json`: every shared property plus each strip's Z and width, enough to rebuild them exactly.
- The edit was recorded as two Studio undo steps ("HOS-LOBBY-001 one-piece checker plaza", "HOS-LOBBY-001 plaza stud variant").

## Screenshots
- Before: `docs/HOS-LOBBY-001_plaza_before.jpg`
- After: `docs/HOS-LOBBY-001_plaza_after.jpg`

The place still needs to be saved/published from Studio for the change to stick.
