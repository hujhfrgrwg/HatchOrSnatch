---
tags: [pets, art, standard]
updated: 2026-10-17
---
# HOS-PET-014: Crow / Kitsune / Manta style analysis, and the pet texture standard

This was a read-only analysis in the Hatch or Snatch place (templates in `ReplicatedStorage.EOS.Assets.Pets`), done for Hunter's question "would a SurfaceAppearance texture on the beetle look better? … more similar to how the crow is and the kitsune", plus his Manta reference (`docs/pets/concepts/surfaceappearance_reference_manta.png`).

**Stills** (`docs/pets/style_analysis/`, same daylight on the sand map):
- `lineup_crow_kitsune_manta_beetle.jpg`: Shadow Crow, Spirit Kitsune, Mirage Manta and Bastion Beetle, front-on.
- `kitsune_closeup.jpg`: the Kitsune's face decal and body shading.
- `beetle_before_paint_pbr_only.jpg`: the Beetle with PBR maps but flat colour fills.
- `beetle_painted_closeup.jpg`: the Beetle with painted detail, after this pass.

## What each one is

| | Shadow Crow | Spirit Kitsune | Mirage Manta | Bastion Beetle (before) |
|---|---|---|---|---|
| **Meshes** | `Crow_Body` + `Crow_Eyes` (1,080 tris) | `Kitsune_Body`, `_Face`, `_L2`, `_L3` (1,493 tris) | `Manta_Body`, `_Veil`, `_L2`, `_L3`, plus `Manta_Stars1-3` (1,400 tris) | `Beetle_Body`, `_Face`, `_L2`, `_L3` (1,905 tris) |
| **SurfaceAppearance maps** | Color, Normal, Roughness | Color, Normal, Roughness; L2/L3 looks add an **Emissive** mask | Color, Normal, Roughness, **Emissive** (2.2 / 2.8 / 3.4 by level) | Color, Normal, Roughness, Metalness, Emissive |
| **Metalness** | none | none | none | yes |
| **AlphaMode** | Overlay | Body Overlay; **Face = Transparency** | Body Overlay; wings/veil = **Transparency**, DoubleSided | Overlay |
| **Part material** | Plastic, no Reflectance | Plastic | Plastic, Body Transparency 0.25; star parts **Neon** | Plastic |
| **Eyes** | separate `Crow_Eyes` mesh with a classic TextureID (EyeBase/EyeL3 swap red at L3) | separate **DoubleSided face mesh with a painted alpha decal** (markings + eyes painted crisp) | eye spots in the emissive mask (glow white) | geometry eyes + emissive mask |
| **Per-level looks** | eye texture swap, particle feathers/wisps | `Looks` folder: Body1-3 / Face1-3 / Extra2-3 SurfaceAppearances | `Looks` folder, emissive rises per level | L2/L3 meshes; aura on L3 |
| **Rig / scale** | CrowRig, model scale 1, BaseScale 0.62, no Prefix | PetRig, RigScale 0.01, BaseScale 0.75 | PetRig, RigScale 0.01, BaseScale 1 | PetRig, RigScale 0.01, BaseScale 0.78 |
| **Sources in repo** | none (only rigs/anims in ScriptHistory) | none | none (`models/pets/src/manta/manta.py` is named in PetRig but not on this machine or branch) | `tools/pets/bastion_beetle.py` |

**Important finding:**
- The Crow's ColorMap and NormalMap fail to load in this place (`ContentProvider` status *Failure*). So do the Manta's ColorMaps.
- In Studio they render untextured grey, as the lineup shows.
- Those textures belong to another creator or experience, so the group place has no permission to them.
- Their pixels can't be read either (`CreateEditableImageAsync`: "no permission").
- So the Manta is analysed from Hunter's screenshot, and the Crow from its maps list plus how it renders here.
- **The Crow and Manta textures need re-uploading to group 228184582** for them to show in this game. I've flagged this for a follow-up and changed nothing.

## What makes them look the way they do
1. **SurfaceAppearance on every mesh**, carrying colour, normal and roughness. The normal map is what softens the low-poly silhouette; the colour map carries the shading and detail. None of them use metalness, and Lighting.EnvironmentSpecularScale is only 0.25 here anyway.
2. **Painted detail, not flat fills** (the Manta reference):
   - micro-pattern: net/scale texture along the wing edges, swirls and dots on the body
   - tonal gradients and light/dark variation inside every colour area
   - small bright speckles
3. **Glow comes from the emissive mask** on the SurfaceAppearance. It covers the eyes, wing tips, speckles and crystals, its strength rises with level, and it reads even in daylight. Neon is used only for tiny star specks (Manta).
4. **Transparency where the art wants it:**
   - alpha (`AlphaMode Transparency` + DoubleSided) for veils, fins and the Kitsune's face decal
   - a lighter, translucent edge on the Manta wings
5. **Crisp faces:** the Kitsune's eyes and markings are a painted alpha decal on a thin face mesh, so they stay sharp at any size.

## How the Beetle differed, and what changed (live in the place now)

| Before | After (HOS-PET-014) |
|---|---|
| Flat colour fills × AO (ivory, bronze and crystal each one tone) | **Painted detail baked into the colour map:** engraved swirl lines and mottling on the ivory, worn-metal variation with bright worn edges and fine scratches on the bronze, faceted cells and white inner sparkle in the crystals, low-contrast noise on the dark body, and a top-lit tonal gradient inside every area |
| Normal map from a smoothed copy only | Same smoothed-copy bake **plus the engraving and crystal facets bumped in** |
| Metalness on the bronze | **Kept** (the bronze reads as metal in daylight). This differs from the Crow/Kitsune/Manta, which skip it; it's harmless with the place's low specular scale. |
| Emissive on crystals and eyes | Kept: crystals, eyes, claw insets, horn and forehead glow cyan (strength 2.2 body / 3.0 eyes / 3.2 L2 / 2.6 L3) |

Rebuilt with `tools/pets/rigkit.py` `paint_material()` styles. The new maps are Decals 110718269307342 (body colour), 133437821793365 (normal), 111425491047639 (roughness) and 139307937290337 (emissive). Every id is listed in [[VFX-LEDGER]].

## The pet texture standard (every pet from the Toad on)
This replaces the PBR-only rule from earlier today.

**Maps**
- Each MeshPart gets a SurfaceAppearance with **Color + Normal + Roughness + Emissive mask**.
- Metalness is optional and only for real metal parts.
- Textures are 1024 px or less.

**Colour map: painted, not flat**
- Use `rigkit.paint_material(mat, style)` before the bake:
  - `skin` for skin, fur and scales
  - `filigree` for armour and stone
  - `metal` for worn metal
  - `crystal` for gems and crystals
  - `dark` for the understructure
- Every area gets a tonal gradient, micro-pattern and highlights.
- Add the species' own markings as geometry or pattern; for example, the Toad's lightning bolts.

**Normal map**
- Bake it from a smoothed subdivided copy plus the painted bumps, so plates and limbs read rounded without extra triangles.

**Glow**
- Use the **emissive mask** on eyes, crystals, markings and runes, tuned to read on the bright sand map in daylight.
- Raise the strength per level.
- No Neon parts for glow, except tiny specks.

**Eyes and faces**
- Keep them crisp: a separate Face mesh. For painted eyes and markings, follow the Kitsune: a thin DoubleSided face mesh with an alpha decal (`AlphaMode Transparency`).

**Translucency**
- Use `AlphaMode Transparency` + DoubleSided only where the design is see-through: veils, fins, wings.

**Process**
- Upload everything to group 228184582 so it loads in this place. This is the problem the Crow and Manta have now.
- Log every upload in [[VFX-LEDGER]].
