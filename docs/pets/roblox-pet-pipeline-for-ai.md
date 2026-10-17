# Procedural Roblox pet pipeline: setup guide for an AI assistant

**For the human:** give this whole file to an AI agent that can **run Python and open PNG images it has rendered**
(Claude Code, or Claude with code execution and file access). Looking at its own renders and fixing what it sees
is the core of the method, so a chat-only AI won't get the same results. Say: *"Read this whole file, set up the
pet kit from the appendices, then we'll make our first pet."* Then fill in the starter prompt in section 12.

**For the AI:** this file describes, in full, the workflow another studio's AI used to make its game's pets. Their
pets are chunky, stylised, low-poly creatures (~1,100–1,500 triangles) with painted textures, glowing accents and
three upgrade levels each, animated from code in Roblox. Everything you need is here:
- the guidance the original AI worked from (section 1);
- the art bar and the lessons from each art review (sections 3 and 6);
- the exact generator spec (section 4);
- the Blender and Roblox steps (sections 7 to 10);
- the source of the shared toolkit (Appendices A to G).

Save each appendix to the file name shown in its heading, all in one folder called `pet-kit/`. Read sections 1 to 6
before writing any pet code.

---

## 1. Where the original AI's guidance came from

The pets didn't come from one magic prompt. They came from layers of context that piled up over many sessions. To
get the same results, set up the same layers:

| Source | What it gave | How to recreate it |
|---|---|---|
| **The generator spec + shared kit** (`SPEC` = section 4, `petkit.py`) | Axes, scale, material slots, triangle budget, the module API, and mesh/texture/pose/render helpers. This is why every pet comes out consistent. | Appendices A to E, unchanged. |
| **A finished reference pet** | The first pet (a crow) was iterated until the developer was happy. Every later pet was told to "match the crow's quality bar" and to study a complete example module before writing anything. | Make your first pet slowly with a lot of feedback. Then point every later pet at it as the worked example. |
| **Art-review feedback, written down** | After each review the AI wrote what changed and why in the pet's `NOTES.md`, and the shared lessons went into a common list (section 6). | Keep a `NOTES.md` per pet and one shared lessons list. Make the AI read them every session. |
| **Reference images from the developer** | E.g. "needs to look like this. No big eyes or facials", with a picture. The AI matched proportions and palette closely. | Give a reference image for each pet whenever you have one. |
| **Project notes** (one living doc per pet, plus the game design doc) | Template structure, asset IDs, timing constants, what's in the game, open items. Read at the start of each session, updated at the end. | Keep a `docs/` folder or AI "project" with one note per pet plus the design doc. |
| **Memory of the developer's standing rules** | Pets *are* abilities; three levels, like weapon skins. Uploads go under the developer's own account. Originality. Don't disrupt a teammate's work in Team Create. | Put your standing rules in your AI's memory/custom instructions, or at the top of your project notes. |
| **Skills** (reusable instruction packs) | A **Roblox VFX skill** for the ability effects: layered ParticleEmitters with custom-drawn numpy textures, an attribute-driven Emit module and a frame-by-frame check loop. It's adapted from the open-source *Roqer* `roblox-animation-vfx` skill (github.com/S4US/Roqer, MIT). Also a **computer-use skill** for driving Studio's 3D Importer and Asset Manager. | Install the Roqer skills, or tell your AI to follow section 9's VFX rules. Computer use is optional: you can click the importer yourself. |
| **Tools** | Python 3 + numpy + Pillow for everything procedural. Blender 5 only to turn the module into FBX + PNGs. A **Roblox Studio MCP server** (the open-source `robloxstudio-mcp`) so the AI can inspect and edit the place, import `.rbxmx`, playtest and screenshot. | Section 2. |
| **The AI's general knowledge** | Maths (skinning, IK, quaternions), Roblox API knowledge, texture-painting tricks. | Nothing to do. |

The two highest-leverage items are **the kit + spec** and **written-down art feedback**. Without the second, every
new pet repeats the same mistakes.

---

## 2. Tools and setup

- Python 3.10+ with `numpy` and `Pillow` (`pip install numpy pillow`).
- **Blender 5.x** (free). It's only used for the build step: you paste one line into its Python console.
- **Roblox Studio.** Optionally, a Studio MCP server so the AI can work in Studio directly. Without one, the AI writes
  Luau files and you paste or import them.
- An AI agent that can run code and view images.

Folder layout:
```
pet-kit/
  petkit.py          (Appendix A) shared numpy kit. Never edit per pet.
  lit_view.py        (Appendix B) lit preview renderer. Use it for all previews.
  kview.py           (Appendix C) the same, plus alpha blending for RGBA decals / translucent parts.
  pet_blender.py     (Appendix D) Blender side: rig, meshes, materials, actions, .blend + .fbx + PNGs.
  make_build.py      (Appendix E) module -> one self-contained Blender script.
  export_pet_anims.py(Appendix F) module ANIMS -> Luau data module for the runtime rig.
  roblox/PetRig.luau (Appendix G) plays the baked keyframes on Bones from code.
  <pet>/             one folder per pet: <pet>.py, make_previews.py, out/, NOTES.md, check scripts
  build/             generated Blender scripts
```

---

## 3. The look: what makes these pets look the way they do

- **Chunky stylised low-poly**, appealing to kids and teens. The silhouette is solid and readable, never scrawny.
  Shapes are big and simple; colour comes in clear blocks; eyes are big and clean.
- **Readable at small size.** The follower is under 20% of the avatar's height on screen. Check every design as a
  thumbnail.
- **1,050–1,500 triangles in total**, including every level's extras. For reference, the finished pets were:

  | Pet | Tris | Bones |
  |---|---|---|
  | Crow | 1,080 | 22 |
  | Prism chameleon | 1,470 | 23 |
  | Kitsune | 1,492 | 24 |
  | Translucent sky-manta | 1,400 | 24 |

- **Shading.** Faceted gem-like pets use `SHARP_ANGLE` ≈ 18 (sharp edges). Furry or soft pets use about 55 (smooth
  shading in Blender, crisp only on ears, noses and rims).
  - Anti-prism lofts (alternate rings turned half a step) break flat sides into varied facets instead of long flat
    ribbons. Use them on every body loft.
- **Painted, not photographic, textures.** One 1024² atlas holds each pet's whole body.
  - Detail is subtle: fur clumps, scales or facet edges, plus a light grain.
  - It's painted per UV triangle when the pet is faceted: each facet gets a small tint, an internal gradient and a
    faint light edge, and some facets are "glint" facets.
  - A height map (normal strength ~2.5) adds bevels and grooves. Roughness runs 0.12–0.22 on gems and higher on
    fur.
- **Glow as an accent, not everywhere.**
  - Emissive masks go only on eyes, wing or tail tips, gems, flames and markings.
  - Roblox bloom makes them pop when (texture colour × tint × strength) goes past the bloom threshold (the original
    game uses bloom threshold 1.4, emissive strength 3–6).
  - White-hot cores with a coloured falloff read best.
- **Three levels that look like skin upgrades.**
  - L1 is the clean base pet.
  - L2 adds pieces (mat 2) and gets brighter and more saturated.
  - L3 adds more pieces (mat 3) and the richest colour: glow, spectrum or rim accents, particles.
  - Each upgrade must read from a distance and still look clean.
  - Examples from the original pets:
    - *Kitsune*: L2 adds a rope collar, a bell and two tails; L3 adds more tails and paper tags; warm glow on the
      tail tips and markings.
    - *Chameleon*: L2 and L3 add chunky faceted gems; the gems glow.
    - *Crow*: L2 adds drifting black feather particles; L3 adds rising dark wisps.
    - *Manta*: L2 adds jelly ribbons and scalloped frills; L3 adds wingtip streamers, a veil train and a pink-violet
      galaxy of inner stars.
- **Translucency, used sparingly.**
  - The glassy manta's body is about 25% transparent, so neon "galaxy star" octahedra inside it show through.
  - Its outer wing veils use graded alpha in a separate texture (AlphaMode Transparency), while the body region
    stays opaque (Overlay).
  - Heavy transparency everywhere reads as mush and costs performance on mobile, so keep a solid core.

---

## 4. Generator spec (follow exactly)

Each pet is **one pure Python + numpy module**. It builds the mesh, weights, UVs, textures and animations
procedurally. No hand modelling. The module is later embedded into a Blender script and turned into FBX + PNGs.

**Conventions**
- 1 unit = 1 stud. The pet faces **−Y**, up is **+Z**, and its LEFT side is **+X** (`.L` bones on +X, `.R`
  mirrored).
- The lowest resting point is at z = 0. A floating pet's lowest point is about z = 0.15.
- Size is about 1.3–1.7 units tall at rest. The game rescales it.
- Bones: `Root` at the origin first, parents before children, 12–26 bones, ASCII names with no spaces.
- Every vertex is weighted, with at most 4 influences, and blends smoothly at joints. Rigid pieces such as gems use
  the same weights on all their vertices.
- **Materials** (`mb.mat` / `mat=`). Each id becomes one Roblox MeshPart:
  - 0 = body (the atlas: colour + normal + roughness);
  - 1 = eyes/face (a small mesh with its own 512 RGBA texture that the game swaps per level);
  - 2 = level-2 extras (body atlas, shown at L2+);
  - 3 = level-3 extras (body atlas, shown at L3).

  You may add ids beyond 3 for special parts (the manta used 4 = translucent veil and 5–7 = neon star meshes per
  level), but the Blender script and the Roblox template must then handle them.
- **Triangle budget: everything ≤ 1,500.**
- **Closed, connected geometry.** No holes, no open edges on the body, and no floating bits: limbs, tails and extras
  start *inside* the body (buried bases). Single-sided decal shells (eyes, face or mask) are the only allowed open
  edges. They sit 0.005–0.01 off the surface.
- Textures use row 0 = TOP of the image. The body atlas is 1024×1024. Return colour per level, plus one height map and
  one roughness map.

**Module API** (`pet-kit/<pet>/<pet>.py`)
```python
from petkit import *            # keep a small try-block header that walks up the folders to find petkit.py
NAME = 'Otter'                  # one unique ASCII word; every output file is named after it
SHARP_ANGLE = 40                # Blender auto-smooth angle (deg): low = faceted, high = smooth
NORMAL_STRENGTH = 2.5           # optional
ATLAS = Atlas({'body': (x0, y0, w, h), ...})     # regions in image pixels, from the top-left
def bones_def(): ...            # [(name, head V(...), tail V(...), parent or None)], Root first
def build(): ...                # -> MB with mats 0..3
def paint_atlas(level): ...     # -> (col HxWx3 or HxWx4, hgt HxW, rgh HxW), level 1..3
def face_texture(level, size=512): ...           # -> RGBA for mat 1, level 1..3
ANIMS = {'Idle': fn, ...}       # fn() -> {'frames': int, 'loop': bool, 'keys': {frame: pose}}
                                # pose = {bone: P(('x', deg), ..., loc=(x, y, z))}: rotations in WORLD axes about
                                # the bone head, 24 fps. Loops: last key == first key. Unlisted bones = rest.
```
- **Hard rule:** the module may import only `petkit`, `numpy`, `math`, `os` and `sys`. It must not run anything at
  import time except definitions, because it runs inside Blender.

**Module header** (copy to the top of every pet module, so it finds `petkit.py` from any folder depth, and still works
inside Blender, where petkit is already loaded):
```python
import math, os, sys
try:
    _d = os.path.dirname(os.path.abspath(__file__))
    while not os.path.exists(os.path.join(_d, 'petkit.py')) and os.path.dirname(_d) != _d:
        _d = os.path.dirname(_d)
    if os.path.exists(os.path.join(_d, 'petkit.py')):
        sys.path.insert(0, _d)
except NameError:
    pass
from petkit import *   # noqa: F401,F403
```

**Rotation signs** (world axes, right-hand rule):
- about 'x', positive pitches the nose DOWN for a bone pointing −Y;
- about 'z', positive turns the nose toward +X (its left);
- about 'y' rolls it.

Verify every pose in the rendered sheet rather than trusting the signs.

**Animations to provide**
- `Idle`: a loop. Frame 0 is also the display pose.
- `Walk`: a loop.
- A fast move to keep up: `Run`, `Fly`, `Glide` or `Float` (a loop).
- Optionally, a one-shot for the ability moment.

Author movement **in place**: the game moves the pet with code. Use rotation + location keys only, with no scale and
no constraints. If you need IK, solve it in Python into plain rotations (two-bone IK to world targets keeps feet
planted). Keep each bone's change between neighbouring keys well under 90°: the runtime blends with Catmull-Rom, which
can overshoot slightly.

**`make_previews.py`** (one per pet) writes into `<pet>/out/`:
- `turn_L1/L2/L3.png`: 6-view turnaround of Idle frame 0, with the materials for that level;
- `anims.png`: each animation at 4–6 frames, side and 3/4 views;
- `atlas_L1..3.png`, `face_L1..3.png`;
- close-ups of the head and any extras;
- `report.json`: tris per material, total, bone count, open edges, bounding box.

---

## 5. The iteration loop

1. Agree the pet in one line with the human:
   - animal or theme;
   - palette;
   - what L2 and L3 add;
   - the follower animations;
   - what the ability moment looks like;
   - a reference image, if there is one.
2. Write the module. Render. **Open every PNG and actually look.** Fix. Repeat:
   - at least **4 render-and-fix passes on the model** and **2 on the animations**;
   - check the top and back views, not just the front.
3. Show the human the turnaround and anim sheet after each major pass. Their eye is the real quality gate.
4. Write **check scripts** and run them every pass. Eyeballing misses clipping. At minimum:
   - **clipping:** no limb, tail or extra vertex inside the body in any frame (test every frame or every second
     frame of every animation), and no tail-into-tail;
   - **connectivity:** every shell is embedded in its parent, with no floating pieces;
   - **weights:** normalised, ≤ 4 influences, every vertex weighted;
   - lowest point at rest is z = 0, the height is in range, and tris are ≤ 1,500;
   - **pet-specific checks**, for example:
     - gem bases buried and gem tips outside the skin;
     - eye discs inside their sockets in every frame;
     - minimum clearance between coil turns.
5. Before any big revision, copy the module to `<pet>_v1.py`. Record what changed and why in `NOTES.md`.
6. Finish with `NOTES.md`: what was built, tris per material, the bone list, the animation list, the checks and
   known issues.

---

## 6. Lessons from the art reviews (these are what made the pets good)

**Geometry**
- **Chunky, not thorny.** Thin 8-triangle crystal shards read as thorns. Use fewer, bigger faceted gems:
  - a buried flat-bottom ring;
  - a short 5- or 6-sided prism;
  - a faceted cap with its tip slightly off-centre;
  - height ≈ 1.5 × width, with rigid weights.

  A tall thin crest made the main gem read as a pole. Lowering and broadening the crest into a helmet fixed it.
- **Not boxy.** Use 14-sided body lofts with alternate rings turned half a step. Give the body a deeper chest, a
  tucked waist and round haunches.
- **Smooth transitions** from head to neck to back, with shoulders and hips blending into the body. Nothing sharp
  should poke out by accident; a cowlick read as a horn in 3/4 view and was removed.
- **No clipping in any frame.**
  - Example: in a fox's Run the low tails swung together until they touched; they now dip instead.
  - Lifted front legs splay out slightly so the elbows don't fold into a deep chest.
- Keep some budget headroom. One late addition usually means trimming somewhere else.

**Face**
- **Eyes flush, never bulging.** Use a thin mat-1 disc 6–8 mm off the surface, or a disc inside a socket lip. Give it
  a big iris and highlights.
- **Painted face markings:** use a mat-1 decal shell. That's a copy of the head's front facets, lifted ~0.008 along
  smoothed normals, with an RGBA texture. Transparent texels carry the head's base colour, so there's no fringe.
  Preview it with `kview`.
- **Match the reference, especially the muzzle.**
  - The fox first read as a cat. Fixing it took:
    - a muzzle about 1.6× longer beyond the eyes;
    - a brow stop;
    - a wedge-shaped muzzle;
    - taller, broad-based ears set wider apart and tilted out.
  - Put the reference beside your render and compare.
- **When the human says "no big eyes or facials", take the face off entirely.** For the manta, the eyes ended up as
  two small glowing dots painted into the texture and the emissive mask, with no eye mesh.

**Colour and texture**
- **Use the lit renderer** (`lit_view`). The kit's default light comes from below, and white fur reads grey under it.
- **White must read white:** a near-white base (`#fbf8f2`) with a light cool shade only in recesses.
- Use cool hues on gems, so shaded facets go blue or violet, never olive.
- **Seams:** tube UVs wrap at u = 0/1, so make any noise periodic across the seam.
- **Levels escalate.** Extras share the atlas, so L1 parts also get richer at L2 and L3. That's intended.
- **Glow:** paint the glow into the texture, then build the emissive mask from the same painted regions. Fade every
  glowing tip to white. Make light sources (PointLights) dimmer than you think; the manta's tail light was halved
  after review.

**Process**
- Build → render → look → fix. Trust `anims.png` over sign conventions.
- When the human changes direction mid-way (a new reference image), restart the look and keep the rig and the
  pipeline.

---

## 7. Blender build

1. `python3 make_build.py <pet>/<pet>.py --save-root "C:\path\to\models"` writes `build/<pet>_build.py`. That's one
   self-contained script with petkit and the module embedded as base64.
2. In Blender 5, go to the Scripting tab and type into the Python console:
   `exec(open(r'C:\full\path\to\pet-kit\build\<pet>_build.py').read())`
3. It builds a fresh scene, rig, meshes (Body / Face / L2 / L3), materials and baked actions, then writes into
   `<save-root>/<name>/`:
   - `<Name>_Pet.blend`;
   - `<Name>_Pet.fbx`: bind pose, no animation, exported with axis_forward Z, axis_up Y;
   - `<Name>_Color.png`, `_Color_L2.png`, `_Color_L3.png`, `_Normal.png`, `_Roughness.png`;
   - `_Face.png`, `_Face_L2.png`, `_Face_L3.png`.

   It prints the tri counts. Fix things in the module, never in Blender, then rebuild.
4. For extra material ids (veils, neon parts), extend `pet_blender.py`'s mesh loop and add a material per id. Save
   any extra textures, such as emissive masks or per-level RGBA atlases, the same way.

---

## 8. Into Roblox Studio

**Import**
- Use the 3D Importer on the FBX, with rig/skinning kept.
- **Set Creator to your own account (or your group) on every row before importing.** The importer silently uploads
  textures under whatever creator is selected.
- Uploads are permanent and moderated. Settle the textures first, then upload them in one batch.
- **Images:**
  - Upload through Asset Manager → Import, then right-click → Copy AssetId.
  - Expect "Asset has not been reviewed" for a short while after uploading.

**Template** (e.g. `ReplicatedStorage.Assets.Pets.<Species>`, a Model)
- An invisible anchored `RootPart` is the PrimaryPart. Every MeshPart is welded to it with a WeldConstraint;
  skinning needs that joint.
- Attributes:
  - `Species`;
  - `Prefix` (the mesh name prefix);
  - `RigScale` (the model scale at which keyframe translations are in studs; 0.01 if the FBX came in at
    centimetres);
  - `BaseScale` (default display scale).
- A `Looks` folder of SurfaceAppearances, one per level. The code clones the right one onto each MeshPart:
  - `Body1..3`: colour + shared normal + roughness. Use AlphaMode Overlay for opaque parts.
  - `Face1..3` (the mat-1 decal): AlphaMode Transparency.
  - `Extra1..3`: for translucent or veil parts with graded alpha, AlphaMode Transparency.
  - Glow:
    - set `EmissiveMaskContent` to a mask texture (white = glows);
    - set `EmissiveTint` and `EmissiveStrength` (about 3 → 6 rising with level);
    - with Lighting bloom on, a threshold around 1.4 makes it bloom.
- L2/L3 MeshParts are destroyed below their level. Any descendant with a `MinLevel` attribute (particles, lights,
  neon parts) is destroyed if `MinLevel` > the pet's level. That makes level effects data-driven: add an emitter, tag
  it `MinLevel = 2`, done.
- **ViewportFrames don't draw SurfaceAppearance.** For a menu preview, copy each look's colour map onto
  `MeshPart.TextureID`. Store it in a `ColorMap` attribute on each SurfaceAppearance, because scripts can't read
  ColorMap.

**Icons**
- Render the pet with glow on a black background.
- Convert to RGBA with a matte step: alpha from the luminance and edge distance, then un-premultiply.
- Make one icon per level.

---

## 9. Runtime: animation, follower, ability, VFX

**Animation from code, not Animation assets.** This avoids every ownership problem between accounts and groups.
1. `python3 export_pet_anims.py <pet> <out.luau> <Species>Anims` bakes the module's ANIMS into a Luau data module.
   It converts axes with `M = [[-1,0,0],[0,0,1],[0,1,0]]`: one quaternion + translation per bone per key.
2. Put it as a child ModuleScript of `PetRig` (Appendix G) and register it in `PetRig.MODULES`.
3. Use `PetRig.new(model, species)`, then `rig:play("Walk", fade, speed)` and `rig:step(dt)` every RenderStepped. Call
   `PetRig.prime(template)` once on the untouched template.

**Pet model builder** (write a small `PetModel` module) that:
- clones the template;
- scales it;
- applies the level look (parts below the level destroyed, `Looks.Body<lv>` / `Face<lv>` / `Extra<lv>` cloned onto
  the parts);
- strips `MinLevel` descendants above the level;
- makes everything non-colliding, massless and CanQuery false.

**Client follower** (one behaviour module per species, all with the same API):
- `INTRO` (seconds);
- `newFollower(player, level)`, `updateFollower(f, dt)`, `respawnFollower(f)`;
- `summon(character, level)`: the ability moment;
- `poof(...)`.

What each follower does:
- **Walkers:** walk to a spot behind the player's right side; walk/run clips scale with speed (with hysteresis so
  the clip never flickers); they pop back if they're lost.
- **Flyers:** hover behind the shoulder, bank into turns, and glide when the player moves fast.
- Everything is client-side and never physical.

**The ability moment ("summon")**
- The server decides the effect and delays it by `INTRO` seconds: the decoy copy appears, or the player vanishes.
  The client plays the pet's summon over the same `INTRO`, so the flash hides the swap. **Keep the server and client
  INTRO values identical.**
- Examples:
  - crow: swoops in from behind and above to the chest;
  - fox: runs in, hops left-right, leaps into the player's back;
  - chameleon: hops to the shoulder and melts in, with prism shards sweeping head to feet;
  - manta: flies in high behind, loops round the right side, rolls 90° with its belly to the player, and sweeps
    across their front, scaled up to cover them head to feet, while the player fades out behind it. It flies on
    past and fades.

**VFX** (follow these strictly)
- **Effects are layered ParticleEmitters, Beams and Trails with custom textures. Never clusters of balls or 3D parts.**
  Mesh shapes (a ring, a crescent) are one layer, not the effect.
- Draw the textures procedurally with numpy (soft blobs, stars, strokes, flipbooks). Preview them in Studio before
  uploading anything.
- Store each effect as a template (e.g. `ReplicatedStorage.VFX.<Name>_L1/L2/L3`). Put timing in attributes
  (`EmitCount`, `EmitDelay`) and play it with a small Emit module.
- Build effects in layers on an intensity curve: anticipation (gather) → flash → body → secondaries → a soft tail
  (dust, smoke).
  - Example: the manta's effect is a soft flash and ripple, with stars drifting outward in all directions and
    decelerating ("not like a blast"), plus star dust.
- **Each level gets more layers:** L2 adds a second ripple and droplets; L3 adds a rim, a galaxy swirl and a light.
- The server fires names + CFrames over an UnreliableRemoteEvent; each client plays the effect. Gameplay never waits
  on an effect.

**A test lab** (it made iteration fast)
- Make a Studio-only baseplate, deleted on live servers by a guard script.
- Line up every pet at L1/L2/L3 with labels, playing Idle.
- In front of each pet species, put one dummy rig that loops that pet's real summon on itself, cycling L1 → L2 → L3,
  with a billboard showing the current level.
- Add Studio-only workspace attributes so you can force a test pet, its level and a short cooldown on yourself.
- Filter those attributes by user ID so teammates' playtests aren't affected.

---

## 10. Rules for an AI working in Studio (via an MCP server)

- **Don't push Luau with a "set whole script source" call.** It can mangle escape sequences. Write the `.luau`
  locally, wrap it in a small `.rbxmx`, and import it, or edit specific lines.
- **`require` caches modules in edit mode** for the whole Studio session. To test new code in edit mode, clone the
  module beside itself, require the clone, then destroy it. Re-imports may be served from a cache, so use a new file
  name per version (`MantaPet_v3.rbxmx`, `_v4` ...).
- Tool calls sent in the same turn can race. Set up a camera or pose in one turn and screenshot in the next.
- **Uploads are irreversible.** Say how many files will be uploaded before doing it, and upload only the settled
  set.
- **Team Create:** make small, targeted edits to shared scripts, never reformat someone else's file, and keep test
  hooks filtered to your own user ID.
- Studio screenshots from the capture API may not show BillboardGuis. Check those on the real screen.

---

## 11. Originality

- Every design is original. Never base a pet on a franchise character (Pokémon, Digimon, any game, cartoon or anime
  mascot), not even "inspired by". "We have the licence" isn't something the AI can verify, so it should still say no
  and offer an original design.
- Common animals and folklore creatures (fox, owl, manta, kitsune) are fine. The design and the details must be your
  own. If something starts to look like a known character, change the silhouette, colours or face.
- A reference image the human provides of their own direction is fine to follow closely.
- No logos, brand names or trademarks on pets.

---

## 12. Starter prompt (fill in and give to the AI)

```
Read this whole guide. Set up pet-kit/ from Appendices A-G (exact file names). Then make our first pet:

- NAME (one ASCII word): ________
- Ability it represents in our game: ________
- Animal / theme / one-line look: ________
- Palette (L1), and how L2 and L3 get richer: ________
- L2 extras (mat 2) and L3 extras (mat 3): ________
- Follower animations (Idle, Walk, and Run/Fly/Glide/Float): ________
- Ability moment (what the pet does when the ability fires): ________
- Reference image (path), if any: ________

Follow section 4 exactly (axes, scale, materials, <=1,500 tris, one-file module). Preview with lit_view (kview if
there are RGBA decals or translucent parts). Iterate: render, open every PNG, fix; at least 4 model passes and 2
animation passes, top and back views and head close-ups included. Write check scripts (clipping every frame,
connectivity, weights, lowest point, tris). Apply section 6's lessons. Show me the turnaround and anim sheet after
each major pass. Keep NOTES.md up to date. When I approve: run make_build.py and give me the exact line for
Blender's Python console. Never upload anything to Roblox without telling me the count first.
```

---

# Appendices: the shared kit (save each to `pet-kit/<file>`)

## Appendix A: `petkit.py`

```python
# ===================== PETKIT: shared, pure python + numpy (also runs inside Blender) =====================
# Procedural low-poly Roblox pets. Conventions:
#   1 unit = 1 stud. The pet faces -Y, up is +Z, its LEFT side is +X (".L" bones), feet/ground at z = 0.
#   Materials (MB.MAT ids): 0 = body (atlas + SurfaceAppearance), 1 = eyes/face (own swappable texture),
#   2 = level-2 extras (body atlas), 3 = level-3 extras (body atlas). Each id becomes one MeshPart.
#   Poses: {bone: (R 3x3 in rest-relative WORLD axes about the bone head, t world translation)}.
import math
import numpy as np


# ---------------------------------------------------------------- math
def V(*a):
    return np.array(a, dtype=float)


def nrm(v):
    n = np.linalg.norm(v)
    return v / n if n > 1e-12 else v


def rot(axis, deg):
    """3x3 rotation about a WORLD axis ('x','y','z' or vector) by degrees."""
    if isinstance(axis, str):
        axis = {'x': V(1, 0, 0), 'y': V(0, 1, 0), 'z': V(0, 0, 1)}[axis]
    a = nrm(np.asarray(axis, float))
    t = math.radians(deg)
    c, s = math.cos(t), math.sin(t)
    x, y, z = a
    C = 1 - c
    return np.array([[c + x * x * C, x * y * C - z * s, x * z * C + y * s],
                     [y * x * C + z * s, c + y * y * C, y * z * C - x * s],
                     [z * x * C - y * s, z * y * C + x * s, c + z * z * C]])


def chain(*mats):
    """chain(A, B, C) = apply A first, then B, then C."""
    M = np.eye(3)
    for m in mats:
        M = m @ M
    return M


def lerp(a, b, t):
    return a + (b - a) * t


def smooth(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------- atlas UVs
class Atlas:
    """regions in IMAGE pixels (x0, y0 from the TOP-left, w, h). uv(name, a, b): a across, b DOWN."""

    def __init__(self, regions, size=1024, pad=4):
        self.R, self.N, self.pad = regions, size, pad

    def uv(self, name, a, b):
        x0, y0, w, h = self.R[name]
        p = self.pad
        x = x0 + p + min(max(a, 0.0), 1.0) * (w - 2 * p)
        y = y0 + p + min(max(b, 0.0), 1.0) * (h - 2 * p)
        return (x / self.N, 1.0 - y / self.N)

    def px(self, name):
        """(y0, y1, x0, x1) slice bounds in the image (row 0 = top)."""
        x0, y0, w, h = self.R[name]
        return y0, y0 + h, x0, x0 + w


# ---------------------------------------------------------------- mesh builder
class MB:
    def __init__(self):
        self.V, self.W, self.F, self.UV, self.MAT, self.PART = [], [], [], [], [], []
        self.mat = 0                      # default material for new faces

    def vert(self, p, w):
        self.V.append(np.asarray(p, float))
        if isinstance(w, str):
            w = {w: 1.0}
        s = sum(w.values())
        w = {k: v / s for k, v in w.items() if v / s > 1e-4}
        if len(w) > 4:                    # Roblox skinning: at most 4 influences
            top = sorted(w.items(), key=lambda kv: -kv[1])[:4]
            s = sum(v for _, v in top)
            w = {k: v / s for k, v in top}
        self.W.append(w)
        return len(self.V) - 1

    def face(self, idx, uvs, inside=None, mat=None, part=''):
        idx = list(idx)
        uvs = list(uvs)
        if inside is not None:
            P = [self.V[i] for i in idx]
            n = np.zeros(3)
            for i in range(len(P)):
                a, b = P[i], P[(i + 1) % len(P)]
                n += np.cross(a, b)
            c = sum(P) / len(P)
            if np.dot(n, c - np.asarray(inside, float)) < 0:
                idx.reverse()
                uvs.reverse()
        self.F.append(idx)
        self.UV.append(uvs)
        self.MAT.append(self.mat if mat is None else mat)
        self.PART.append(part)

    def tri_count(self, mat=None):
        return sum(len(f) - 2 for f, m in zip(self.F, self.MAT) if mat is None or m == mat)

    def report(self):
        from collections import Counter
        c = Counter()
        for f, p in zip(self.F, self.PART):
            c[p] += len(f) - 2
        mats = {m: self.tri_count(m) for m in sorted(set(self.MAT))}
        return {'total': self.tri_count(), 'by_mat': mats, 'by_part': dict(c)}

    def open_edges(self, mat=None):
        """edges used by only one face (holes / unclosed shells), per part."""
        from collections import Counter, defaultdict
        cnt = Counter()
        owner = {}
        for f, m, p in zip(self.F, self.MAT, self.PART):
            if mat is not None and m != mat:
                continue
            for i in range(len(f)):
                e = tuple(sorted((f[i], f[(i + 1) % len(f)])))
                cnt[e] += 1
                owner[e] = p
        out = defaultdict(int)
        for e, n in cnt.items():
            if n == 1:
                out[owner[e]] += 1
        return dict(out)


def blendw(stations_w, t):
    """stations_w: list of (t, {bone:w}); piecewise-linear blend at t."""
    if t <= stations_w[0][0]:
        return dict(stations_w[0][1])
    for (t0, w0), (t1, w1) in zip(stations_w, stations_w[1:]):
        if t <= t1:
            f = (t - t0) / max(t1 - t0, 1e-9)
            out = {}
            for k in set(w0) | set(w1):
                out[k] = w0.get(k, 0) * (1 - f) + w1.get(k, 0) * f
            return out
    return dict(stations_w[-1][1])


def loft(mb, centers, radii, n, weights, uvf, part, start='point', end='open',
         profile=None, up_hint=V(0, 0, 1), start_pt=None, end_pt=None, side_hint=None):
    """Tube through `centers`. radii: list of (a, b) half-widths (a along the ring's x, b along its up).
    weights: dict per station. profile(k, n, a, b, i) -> (x, z) ring offsets.
    uvf(i, k, seg, fk) -> (u, v)  (i station, k ring index possibly fractional, seg segment, fk face ring index).
    start/end: 'open' | 'point' (cone cap to start_pt/end_pt or the station centre) | 'flat' (fan cap)."""
    m = len(centers)
    C = [np.asarray(c, float) for c in centers]
    T = []
    for i in range(m):
        if i == 0:
            t = C[1] - C[0]
        elif i == m - 1:
            t = C[-1] - C[-2]
        else:
            t = C[i + 1] - C[i - 1]
        T.append(nrm(t))
    rings = []
    for i in range(m):
        ex = V(1, 0, 0) if side_hint is None else nrm(np.asarray(side_hint[i] if isinstance(side_hint, list) else side_hint, float))
        ex = nrm(ex - np.dot(ex, T[i]) * T[i])
        if np.linalg.norm(ex) < 1e-6:
            ex = nrm(np.cross(T[i], V(0, 0, 1)))
        ez = nrm(np.cross(T[i], ex))
        if np.dot(ez, up_hint) < 0 and abs(np.dot(T[i], up_hint)) < 0.7:
            ez = -ez
            ex = -ex
        a, b = radii[i]
        ring = []
        for k in range(n):
            if profile is not None:
                x, z = profile(k, n, a, b, i)
            else:
                th = math.pi / 2 + 2 * math.pi * k / n
                x, z = a * math.cos(th), b * math.sin(th)
            ring.append(mb.vert(C[i] + ex * x + ez * z, weights[i]))
        rings.append(ring)
    for i in range(m - 1):
        inside = (C[i] + C[i + 1]) / 2
        for k in range(n):
            k2 = (k + 1) % n
            q = [rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]]
            uv = [uvf(i, k, i, k), uvf(i, k + 1, i, k), uvf(i + 1, k + 1, i, k), uvf(i + 1, k, i, k)]
            mb.face(q[:3], uv[:3], inside, part=part)
            mb.face([q[0], q[2], q[3]], [uv[0], uv[2], uv[3]], inside, part=part)
    for which, mode, pt in ((0, start, start_pt), (m - 1, end, end_pt)):
        if mode == 'open':
            continue
        ring = rings[which]
        other = C[1] if which == 0 else C[-2]
        seg = 0 if which == 0 else m - 2
        if mode == 'point':
            p = np.asarray(pt, float) if pt is not None else C[which]
            ci = mb.vert(p, weights[which])
            for k in range(n):
                k2 = (k + 1) % n
                mb.face([ring[k], ring[k2], ci], [uvf(which, k, seg, k), uvf(which, k + 1, seg, k), uvf(which, k + 0.5, seg, k)],
                        inside=other, part=part)
        elif mode == 'flat':
            for k in range(1, n - 1):
                mb.face([ring[0], ring[k], ring[k + 1]], [uvf(which, 0, seg, 0), uvf(which, k, seg, k), uvf(which, k + 1, seg, k)],
                        inside=other, part=part)
    return rings


def slab(mb, LE, TE, th, wLE, wTE, uLE, uTE, part, up=V(0, 0, 1), ridge_at=0.30, close_end=True,
         close_start=False, uR=None, wR=None, top_frac=0.62):
    """A thick blade/wing slab: per station a leading-edge point, a trailing-edge point and a thickness."""
    n = len(LE)
    if uR is None:
        uR = uLE
    ups = up if isinstance(up, list) else [up] * n
    iL, iT, iB, iE = [], [], [], []
    for i in range(n):
        r = LE[i] + (TE[i] - LE[i]) * ridge_at
        iL.append(mb.vert(LE[i], wLE[i]))
        wr = wR[i] if wR is not None else wLE[i]
        iT.append(mb.vert(r + ups[i] * th[i] * top_frac, wr))
        iB.append(mb.vert(r - ups[i] * th[i] * (1 - top_frac), wr))
        iE.append(mb.vert(TE[i], wTE[i]))
    for i in range(n - 1):
        mid = (LE[i] + LE[i + 1] + TE[i] + TE[i + 1]) / 4
        upm = nrm(ups[i] + ups[i + 1])
        for R, sgn in ((iT, 1), (iB, -1)):
            inside = mid - upm * 0.5 * sgn
            mb.face([iL[i], iL[i + 1], R[i + 1]], [uLE[i], uLE[i + 1], uR[i + 1]], inside, part=part)
            mb.face([iL[i], R[i + 1], R[i]], [uLE[i], uR[i + 1], uR[i]], inside, part=part)
            mb.face([R[i], R[i + 1], iE[i + 1]], [uR[i], uR[i + 1], uTE[i + 1]], inside, part=part)
            mb.face([R[i], iE[i + 1], iE[i]], [uR[i], uTE[i + 1], uTE[i]], inside, part=part)
    if close_end:
        j = n - 1
        mb.face([iL[j], iT[j], iE[j]], [uLE[j], uR[j], uTE[j]], (LE[j - 1] + TE[j - 1]) / 2, part=part)
        mb.face([iL[j], iE[j], iB[j]], [uLE[j], uTE[j], uR[j]], (LE[j - 1] + TE[j - 1]) / 2, part=part)
    if close_start:
        mb.face([iL[0], iT[0], iE[0]], [uLE[0], uR[0], uTE[0]], (LE[1] + TE[1]) / 2, part=part)
        mb.face([iL[0], iE[0], iB[0]], [uLE[0], uTE[0], uR[0]], (LE[1] + TE[1]) / 2, part=part)
    return iL, iT, iB, iE


def bipyramid(mb, base, tip, side, up, width, height, w, uvb, uvt, part, wide_at=0.5, ridge_at=0.45, curl=0.0):
    """Flattened 6-vertex crystal/spike/feather (8 tris), closed."""
    base, tip = np.asarray(base, float), np.asarray(tip, float)
    d = tip - base
    L = np.linalg.norm(d)
    d = d / L
    s = nrm(side - np.dot(side, d) * d)
    u = nrm(np.cross(s, d))
    if np.dot(u, up) < 0:
        u, s = -u, -s
    tipc = tip + u * curl * L
    pl = base + d * L * wide_at + s * width / 2
    pr = base + d * L * wide_at - s * width / 2
    pu = base + d * L * ridge_at + u * height / 2 + u * curl * L * 0.4
    pd = base + d * L * ridge_at - u * height / 2 + u * curl * L * 0.4
    ws = w if isinstance(w, list) else [w] * 6
    ib = mb.vert(base, ws[0]); it = mb.vert(tipc, ws[1]); il = mb.vert(pl, ws[2])
    ir = mb.vert(pr, ws[3]); iu = mb.vert(pu, ws[4]); idn = mb.vert(pd, ws[5])
    um = (uvb[0] * 0.4 + uvt[0] * 0.6, uvb[1] * 0.4 + uvt[1] * 0.6)
    center = base + d * L * 0.5
    for top in (iu, idn):
        mb.face([ib, il, top], [uvb, um, um], center, part=part)
        mb.face([il, it, top], [um, uvt, um], center, part=part)
        mb.face([it, ir, top], [uvt, um, um], center, part=part)
        mb.face([ir, ib, top], [um, uvb, um], center, part=part)
    return [ib, it, il, ir, iu, idn]


def raycast(origin, direction, tris):
    """tris: (N,3,3). Nearest hit distance along direction (or None)."""
    o = np.asarray(origin, float)
    dvec = nrm(np.asarray(direction, float))
    v0, v1, v2 = tris[:, 0], tris[:, 1], tris[:, 2]
    e1, e2 = v1 - v0, v2 - v0
    p = np.cross(dvec, e2)
    det = np.einsum('ij,ij->i', e1, p)
    ok = np.abs(det) > 1e-12
    inv = np.where(ok, 1.0 / np.where(ok, det, 1), 0)
    tv = o - v0
    uu = np.einsum('ij,ij->i', tv, p) * inv
    q = np.cross(tv, e1)
    vv = np.einsum('j,ij->i', dvec, q) * inv
    t = np.einsum('ij,ij->i', e2, q) * inv
    hit = ok & (uu >= 0) & (vv >= 0) & (uu + vv <= 1) & (t > 0)
    if not hit.any():
        return None
    return float(t[hit].min())


def tris_of(mb, parts=None):
    out = []
    for f, p in zip(mb.F, mb.PART):
        if parts is not None and p not in parts:
            continue
        for t in range(1, len(f) - 1):
            out.append([mb.V[f[0]], mb.V[f[t]], mb.V[f[t + 1]]])
    return np.array(out)


def nearest_weights(mb, p, parts, k=3):
    """inverse-distance blend of the k nearest vertices' weights from the given parts (skin-attached pieces)."""
    idx = sorted({v for f, pp in zip(mb.F, mb.PART) if pp in parts for v in f})
    P = np.array([mb.V[i] for i in idx])
    d = np.linalg.norm(P - np.asarray(p, float), axis=1)
    order = np.argsort(d)[:k]
    acc = {}
    tot = 0
    for o in order:
        wv = 1.0 / max(d[o], 1e-3)
        tot += wv
        for b, w in mb.W[idx[o]].items():
            acc[b] = acc.get(b, 0) + w * wv
    return {b: w / tot for b, w in acc.items()}


# ---------------------------------------------------------------- textures (row 0 = TOP)
def hx(h):
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)], dtype=np.float32)


def grad(t, stops):
    t = np.clip(t, 0, 1)
    out = np.zeros(np.shape(t) + (3,), np.float32)
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        m = (t >= t0) & (t <= t1)
        f = ((t - t0) / max(t1 - t0, 1e-6))[..., None]
        out = np.where(m[..., None], hx(c0) * (1 - f) + hx(c1) * f, out)
    return out


def ss(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def vnoise(h, w, cells, seed):
    """smooth value noise in [0,1]."""
    rng = np.random.default_rng(seed)
    cy, cx = max(1, int(cells * h / max(h, w))), max(1, int(cells * w / max(h, w)))
    g = rng.random((cy + 2, cx + 2)).astype(np.float32)
    y = np.linspace(0, cy, h, endpoint=False, dtype=np.float32)
    x = np.linspace(0, cx, w, endpoint=False, dtype=np.float32)
    y0 = np.floor(y).astype(int); x0 = np.floor(x).astype(int)
    fy = (y - y0)[:, None]; fx = (x - x0)[None, :]
    fy = fy * fy * (3 - 2 * fy); fx = fx * fx * (3 - 2 * fx)
    a = g[y0][:, x0]; b = g[y0][:, x0 + 1]; c = g[y0 + 1][:, x0]; d = g[y0 + 1][:, x0 + 1]
    return a * (1 - fx) * (1 - fy) + b * fx * (1 - fy) + c * (1 - fx) * fy + d * fx * fy


def grit(h, w, seed):
    """multi-octave grain in [-0.5, 0.5]."""
    return (0.45 * vnoise(h, w, 10, seed) + 0.33 * vnoise(h, w, 40, seed + 1) +
            0.22 * vnoise(h, w, 160, seed + 2)) - 0.5


def normal_from_height(hgt, strength=3.0):
    """tangent-space (OpenGL, +Y up) normal map from a height map whose row 0 is the TOP."""
    H = hgt[::-1]
    dy, dx = np.gradient(H)
    n = np.stack([-dx * strength, -dy * strength, np.ones_like(H)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return (n * 0.5 + 0.5)[::-1].astype(np.float32)


def coords(size):
    """x, y in -1..1 (x right, y UP) for a square texture, row 0 = top."""
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float32)
    return (xs + 0.5) / size * 2 - 1, 1 - (ys + 0.5) / size * 2


def save_png(path, arr):
    from PIL import Image
    a = np.clip(arr, 0, 1)
    if a.ndim == 2:
        a = np.repeat(a[..., None], 3, -1)
    mode = 'RGBA' if a.shape[2] == 4 else 'RGB'
    Image.fromarray((a * 255 + 0.5).astype(np.uint8), mode).save(path)


# ---------------------------------------------------------------- poses / FK / skinning
def P(*rots, loc=(0, 0, 0)):
    return (chain(*[rot(a, d) for a, d in rots]) if rots else np.eye(3), V(*loc))


def mirror_pose(p):
    """Mirror a left-side (rotation, loc) to the right side (reflect through X)."""
    R, t = p
    S = np.diag([-1.0, 1.0, 1.0])
    return (S @ R @ S, V(-t[0], t[1], t[2]))


def sym(d):
    """{'X.L': pose} -> also adds the mirrored 'X.R'."""
    out = dict(d)
    for k, v in d.items():
        if k.endswith('.L'):
            out[k[:-2] + '.R'] = mirror_pose(v)
    return out


def merge(*ds):
    out = {}
    for d in ds:
        out.update(d)
    return out


def pose_mats(bones, pose):
    """bones: [(name, head, tail, parent)], pose: {bone: (R, t)} -> {bone: 4x4 deform}."""
    G = {}
    for name, head, tail, parent in bones:
        R, t = pose.get(name, (np.eye(3), V(0, 0, 0)))
        A = np.eye(4); A[:3, 3] = np.asarray(head, float) + t
        Rm = np.eye(4); Rm[:3, :3] = R
        Bm = np.eye(4); Bm[:3, 3] = -np.asarray(head, float)
        L = A @ Rm @ Bm
        G[name] = (G[parent] @ L) if parent else L
    return G


def skin(mb, bones, pose):
    G = pose_mats(bones, pose)
    out = np.zeros((len(mb.V), 3))
    for i, (p, w) in enumerate(zip(mb.V, mb.W)):
        ph = np.append(p, 1)
        acc = np.zeros(3)
        for b, wt in w.items():
            acc += wt * (G[b] @ ph)[:3]
        out[i] = acc
    return out


def interp_pose(anim, f):
    keys = anim['keys']
    ks = sorted(keys)
    if anim.get('loop'):
        f = f % anim['frames']
    if f <= ks[0]:
        return keys[ks[0]]
    for a, b in zip(ks, ks[1:]):
        if f <= b:
            t = (f - a) / (b - a)
            t = t * t * (3 - 2 * t)
            out = {}
            for bone in set(keys[a]) | set(keys[b]):
                Ra, ta = keys[a].get(bone, (np.eye(3), V(0, 0, 0)))
                Rb, tb = keys[b].get(bone, (np.eye(3), V(0, 0, 0)))
                M = Ra * (1 - t) + Rb * t
                U, _, Vt = np.linalg.svd(M)
                out[bone] = (U @ Vt, ta * (1 - t) + tb * t)
            return out
    return keys[ks[-1]]


# ---------------------------------------------------------------- preview (textured software rasterizer)
def _sample(img, uv):
    H, W = img.shape[:2]
    x = np.clip((uv[..., 0] % 1.0) * W, 0, W - 1).astype(int)
    y = np.clip((1 - (uv[..., 1] % 1.0)) * H, 0, H - 1).astype(int)
    return img[y, x, :3]


def render(mb, verts, textures, yaw, pitch, size=520, scale=None, center=None, bg=(200, 214, 230),
           mats=None, light=(-0.4, -0.7, 0.8), outline=True):
    """textures: {mat_id: (H,W,3|4) float image, row 0 = top}. mats: set of mat ids to draw (None = all)."""
    from PIL import Image
    Vv = np.asarray(verts)
    cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    cp, sp = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
    Rz = np.array([[cy, -sy, 0], [sy, cy, 0], [0, 0, 1]])
    Rx = np.array([[1, 0, 0], [0, cp, -sp], [0, sp, cp]])
    R = Rx @ Rz
    if center is None:
        center = (Vv.min(0) + Vv.max(0)) / 2
    Pp = (Vv - center) @ R.T
    if scale is None:
        ext = max(np.ptp(Pp[:, 0]), np.ptp(Pp[:, 2]))
        scale = size * 0.85 / ext
    sx = size / 2 + Pp[:, 0] * scale
    syy = size / 2 - Pp[:, 2] * scale
    depth = Pp[:, 1]
    img = np.zeros((size, size, 3)); img[:] = np.array(bg) / 255
    zb = np.full((size, size), np.inf)
    lv = nrm(np.array(light)) @ R.T
    for f, uvs, m in zip(mb.F, mb.UV, mb.MAT):
        if mats is not None and m not in mats:
            continue
        tex = textures.get(m)
        for t in range(1, len(f) - 1):
            ids = [f[0], f[t], f[t + 1]]
            uv3 = np.array([uvs[0], uvs[t], uvs[t + 1]], float)
            p3 = Pp[ids]
            n = np.cross(p3[1] - p3[0], p3[2] - p3[0])
            nn = np.linalg.norm(n)
            if nn < 1e-12:
                continue
            n /= nn
            if n[1] > 0:
                continue
            lam = max(0.0, np.dot(n, -lv))
            rim = max(0.0, 1 - abs(n[1])) ** 3 * 0.18
            xs, ys, zs = sx[ids], syy[ids], depth[ids]
            x0, x1 = int(max(0, math.floor(xs.min()))), int(min(size - 1, math.ceil(xs.max())))
            y0, y1 = int(max(0, math.floor(ys.min()))), int(min(size - 1, math.ceil(ys.max())))
            if x1 < x0 or y1 < y0:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            d = (ys[1] - ys[2]) * (xs[0] - xs[2]) + (xs[2] - xs[1]) * (ys[0] - ys[2])
            if abs(d) < 1e-9:
                continue
            w0 = ((ys[1] - ys[2]) * (gx - xs[2]) + (xs[2] - xs[1]) * (gy - ys[2])) / d
            w1 = ((ys[2] - ys[0]) * (gx - xs[2]) + (xs[0] - xs[2]) * (gy - ys[2])) / d
            w2 = 1 - w0 - w1
            inside = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)
            z = w0 * zs[0] + w1 * zs[1] + w2 * zs[2]
            sub = zb[y0:y1 + 1, x0:x1 + 1]
            upd = inside & (z < sub)
            if not upd.any():
                continue
            sub[upd] = z[upd]
            if tex is not None:
                uvp = (w0[..., None] * uv3[0] + w1[..., None] * uv3[1] + w2[..., None] * uv3[2])[upd]
                col = _sample(tex, uvp)
            else:
                col = np.full((upd.sum(), 3), 0.7)
            shade = col * (0.42 + 0.78 * lam) + rim
            img[y0:y1 + 1, x0:x1 + 1][upd] = np.clip(shade, 0, 1)
    if outline:
        zf = np.where(np.isinf(zb), 1e3, zb)
        edge = np.zeros_like(zf, bool)
        edge[1:, :] |= np.abs(zf[1:, :] - zf[:-1, :]) > 0.12
        edge[:, 1:] |= np.abs(zf[:, 1:] - zf[:, :-1]) > 0.12
        img[edge] = img[edge] * 0.35
    return Image.fromarray((img * 255).astype(np.uint8))


def sheet(images, cols, labels=None):
    from PIL import Image, ImageDraw
    w, h = images[0].size
    rows = (len(images) + cols - 1) // cols
    out = Image.new('RGB', (w * cols, h * rows), (255, 255, 255))
    d = ImageDraw.Draw(out)
    for i, im in enumerate(images):
        out.paste(im, ((i % cols) * w, (i // cols) * h))
        if labels:
            d.text(((i % cols) * w + 8, (i // cols) * h + 6), labels[i], fill=(0, 0, 0))
    return out


VIEWS = [(-35, 12, '3/4 front'), (-90, 5, 'side (left)'), (0, 5, 'front'), (35, 15, '3/4 front R'),
         (-150, 15, '3/4 back'), (-90, 80, 'top')]


def turnaround(mb, verts, textures, path, mats=None, size=420, views=VIEWS):
    Vv = np.asarray(verts)
    ctr = (Vv.min(0) + Vv.max(0)) / 2
    ext = np.ptp(Vv, axis=0).max()
    imgs = [render(mb, Vv, textures, y, p, size=size, scale=size * 0.8 / ext, center=ctr, mats=mats) for y, p, _ in views]
    sheet(imgs, 3, [v[2] for v in views]).save(path)
    return path
```

## Appendix B: `lit_view.py`

```python
# lit_view: lit preview renderer for any pet (camera-relative key light from the upper left, so every view is
# front-lit; petkit's default render light sits below/behind the model and makes white look grey).
# Use lit_render / lit_turnaround in your make_previews.py. Lives next to petkit.py in the pet kit.
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))   # the kit folder (petkit.py sits next to this file)
from petkit import render, sheet, VIEWS  # noqa: E402

CAM_LIGHT = np.array([0.45, 0.62, -0.64])   # camera space travel direction: key light from upper-left, toward the model
BG = (196, 206, 222)


def view_R(yaw, pitch):
    cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    cp, sp = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
    Rz = np.array([[cy, -sy, 0], [sy, cy, 0], [0, 0, 1]])
    Rx = np.array([[1, 0, 0], [0, cp, -sp], [0, sp, cp]])
    return Rx @ Rz


def lit_render(mb, verts, tex, yaw, pitch, size=420, scale=None, center=None, mats=None, ground=None):
    R = view_R(yaw, pitch)
    light = (CAM_LIGHT / np.linalg.norm(CAM_LIGHT)) @ R        # world vector that maps back to CAM_LIGHT
    im = render(mb, verts, tex, yaw, pitch, size=size, scale=scale, center=center, mats=mats, light=tuple(light),
                bg=BG)
    if ground is not None and center is not None and scale is not None:
        from PIL import ImageDraw
        # ground line: project the z=0 plane's centre line
        p = (np.array([0, 0, ground]) - center) @ R.T
        y = size / 2 - p[2] * scale
        d = ImageDraw.Draw(im)
        d.line([(0, y), (size, y)], fill=(150, 160, 178), width=1)
    return im


def lit_turnaround(mb, verts, tex, path, mats=None, size=420, views=VIEWS):
    Vv = np.asarray(verts)
    ctr = (Vv.min(0) + Vv.max(0)) / 2
    ext = np.ptp(Vv, axis=0).max()
    imgs = [lit_render(mb, Vv, tex, y, p, size=size, scale=size * 0.8 / ext, center=ctr, mats=mats)
            for y, p, _ in views]
    sheet(imgs, 3, [v[2] for v in views]).save(path)
    return path
```

## Appendix C: `kview.py`

```python
"""kview: alpha-aware preview renderer: petkit's textured rasterizer + alpha blending for RGBA decal materials (mat 1, the
face decal shell, is shown the way Roblox shows SurfaceAppearance AlphaMode=Transparency: transparent texels let
the fur underneath show through). Camera-relative key light as in lit_view.py.
Use it instead of lit_view when mat 1 is an RGBA face decal shell (painted face markings over the fur)."""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))   # the kit folder (petkit.py sits next to this file)
from petkit import nrm, sheet, VIEWS  # noqa: E402

CAM_LIGHT = np.array([0.45, 0.62, -0.64])
BG = (196, 206, 222)


def view_R(yaw, pitch):
    cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    cp, sp = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
    Rz = np.array([[cy, -sy, 0], [sy, cy, 0], [0, 0, 1]])
    Rx = np.array([[1, 0, 0], [0, cp, -sp], [0, sp, cp]])
    return Rx @ Rz


def _sample4(img, uv):
    H, W = img.shape[:2]
    x = np.clip((uv[..., 0] % 1.0) * W, 0, W - 1).astype(int)
    y = np.clip((1 - (uv[..., 1] % 1.0)) * H, 0, H - 1).astype(int)
    px = img[y, x]
    if px.shape[-1] == 4:
        return px[..., :3], px[..., 3]
    return px[..., :3], np.ones(px.shape[:-1])


def render(mb, verts, textures, yaw, pitch, size=520, scale=None, center=None, bg=BG, mats=None,
           light=(-0.4, -0.7, 0.8), outline=True, alpha_mats=(1,)):
    from PIL import Image
    Vv = np.asarray(verts)
    R = view_R(yaw, pitch)
    if center is None:
        center = (Vv.min(0) + Vv.max(0)) / 2
    Pp = (Vv - center) @ R.T
    if scale is None:
        ext = max(np.ptp(Pp[:, 0]), np.ptp(Pp[:, 2]))
        scale = size * 0.85 / ext
    sx = size / 2 + Pp[:, 0] * scale
    syy = size / 2 - Pp[:, 2] * scale
    depth = Pp[:, 1]
    img = np.zeros((size, size, 3)); img[:] = np.array(bg) / 255
    zb = np.full((size, size), np.inf)
    lv = nrm(np.array(light)) @ R.T
    order = [i for i, m in enumerate(mb.MAT) if m not in alpha_mats] + \
            [i for i, m in enumerate(mb.MAT) if m in alpha_mats]
    for fi in order:
        f, uvs, m = mb.F[fi], mb.UV[fi], mb.MAT[fi]
        if mats is not None and m not in mats:
            continue
        tex = textures.get(m)
        blend = m in alpha_mats and tex is not None and tex.shape[-1] == 4
        for t in range(1, len(f) - 1):
            ids = [f[0], f[t], f[t + 1]]
            uv3 = np.array([uvs[0], uvs[t], uvs[t + 1]], float)
            p3 = Pp[ids]
            n = np.cross(p3[1] - p3[0], p3[2] - p3[0])
            nn = np.linalg.norm(n)
            if nn < 1e-12:
                continue
            n /= nn
            if n[1] > 0:
                continue
            lam = max(0.0, np.dot(n, -lv))
            rim = max(0.0, 1 - abs(n[1])) ** 3 * 0.18
            xs, ys, zs = sx[ids], syy[ids], depth[ids]
            x0, x1 = int(max(0, math.floor(xs.min()))), int(min(size - 1, math.ceil(xs.max())))
            y0, y1 = int(max(0, math.floor(ys.min()))), int(min(size - 1, math.ceil(ys.max())))
            if x1 < x0 or y1 < y0:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            d = (ys[1] - ys[2]) * (xs[0] - xs[2]) + (xs[2] - xs[1]) * (ys[0] - ys[2])
            if abs(d) < 1e-9:
                continue
            w0 = ((ys[1] - ys[2]) * (gx - xs[2]) + (xs[2] - xs[1]) * (gy - ys[2])) / d
            w1 = ((ys[2] - ys[0]) * (gx - xs[2]) + (xs[0] - xs[2]) * (gy - ys[2])) / d
            w2 = 1 - w0 - w1
            inside = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)
            z = w0 * zs[0] + w1 * zs[1] + w2 * zs[2]
            sub = zb[y0:y1 + 1, x0:x1 + 1]
            upd = inside & (z < sub)
            if not upd.any():
                continue
            if tex is not None:
                uvp = (w0[..., None] * uv3[0] + w1[..., None] * uv3[1] + w2[..., None] * uv3[2])[upd]
                col, a = _sample4(tex, uvp)
            else:
                col, a = np.full((upd.sum(), 3), 0.7), np.ones(upd.sum())
            shade = np.clip(col * (0.42 + 0.78 * lam) + rim, 0, 1)
            region = img[y0:y1 + 1, x0:x1 + 1]
            if blend:
                a = a[:, None]
                region[upd] = shade * a + region[upd] * (1 - a)
                zz = z[upd]
                keep = a[:, 0] > 0.5
                tmp = sub[upd]
                tmp[keep] = zz[keep]
                sub[upd] = tmp
            else:
                sub[upd] = z[upd]
                region[upd] = shade
    if outline:
        zf = np.where(np.isinf(zb), 1e3, zb)
        edge = np.zeros_like(zf, bool)
        edge[1:, :] |= np.abs(zf[1:, :] - zf[:-1, :]) > 0.12
        edge[:, 1:] |= np.abs(zf[:, 1:] - zf[:, :-1]) > 0.12
        img[edge] = img[edge] * 0.35
    return Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))


def lit_render(mb, verts, tex, yaw, pitch, size=420, scale=None, center=None, mats=None):
    R = view_R(yaw, pitch)
    light = (CAM_LIGHT / np.linalg.norm(CAM_LIGHT)) @ R
    return render(mb, verts, tex, yaw, pitch, size=size, scale=scale, center=center, mats=mats, light=tuple(light))


def lit_turnaround(mb, verts, tex, path, mats=None, size=420, views=VIEWS):
    Vv = np.asarray(verts)
    ctr = (Vv.min(0) + Vv.max(0)) / 2
    ext = np.ptp(Vv, axis=0).max()
    imgs = [lit_render(mb, Vv, tex, y, p, size=size, scale=size * 0.8 / ext, center=ctr, mats=mats)
            for y, p, _ in views]
    sheet(imgs, 3, [v[2] for v in views]).save(path)
    return path


REF = None   # set to the path of a reference picture (e.g. one the game owner gave you), or pass ref= to with_ref


def with_ref(img, height=None, label='reference', ref=None):
    """img (PIL) next to the reference picture (ref= path, or REF) scaled to the same height."""
    from PIL import Image, ImageDraw
    path = ref or REF
    if not path:
        raise ValueError('with_ref: pass ref=<path to the reference picture> or set kview.REF')
    ref = Image.open(path).convert('RGB')
    h = height or img.size[1]
    ref = ref.resize((int(ref.size[0] * h / ref.size[1]), h))
    out = Image.new('RGB', (img.size[0] + ref.size[0], h), (255, 255, 255))
    out.paste(img, (0, 0))
    out.paste(ref, (img.size[0], 0))
    ImageDraw.Draw(out).text((img.size[0] + 8, 6), label, fill=(255, 255, 255))
    return out
```

## Appendix D: `pet_blender.py`

```python


# ===================================================================== GENERIC PET BLENDER BUILD
# Appended after petkit + one pet module (NAME, SHARP_ANGLE, ATLAS, bones_def, build, paint_atlas,
# face_texture, ANIMS). Builds a fresh scene, the rig, 4 meshes (Body / Face / L2 / L3), bakes the
# actions, writes every texture next to the .blend, saves <NAME>_Pet.blend and exports <NAME>_Pet.fbx.
import os

# ------------------------------------------------------------------ SET THIS (where the outputs go)
# Folder that receives <name>/ with <Name>_Pet.blend, <Name>_Pet.fbx and every texture PNG, for example
#   SAVE_ROOT = r"C:\Users\you\Documents\RobloxPets\models"
# None = a 'models' folder next to the generated build script (make_build.py records that folder in BUILD_DIR).
# You can also leave this file alone and run `python3 make_build.py <pet.py> --save-root "<folder>"`.
SAVE_ROOT = None


def _save_root():
    if SAVE_ROOT:
        return SAVE_ROOT
    bdir = globals().get('BUILD_DIR')
    if bdir and os.path.isdir(bdir):
        return os.path.join(bdir, 'models')
    # the build script was generated on another machine: fall back to the home folder
    fb = os.path.join(os.path.expanduser('~'), 'RobloxPets_pet_models')
    print('SAVE_ROOT not set and BUILD_DIR %r not found on this machine; writing to %s' % (bdir, fb))
    return fb


import bpy
from mathutils import Matrix, Vector

ROOT_DIR = _save_root()
SAVE_DIR = os.path.join(ROOT_DIR, NAME.lower())
print('Pet outputs ->', SAVE_DIR)
FPS = 24


def save_rgba(name, arr, data=False):
    H, W = arr.shape[:2]
    if arr.ndim == 2:
        arr = np.repeat(arr[..., None], 3, -1)
    if arr.shape[2] == 3:
        arr = np.concatenate([arr, np.ones((H, W, 1), np.float32)], -1)
    img = bpy.data.images.get(name)
    if img is None:
        img = bpy.data.images.new(name, W, H, alpha=True)
    if tuple(img.size) != (W, H):
        img.scale(W, H)
    if data:
        try:
            img.colorspace_settings.name = 'Non-Color'
        except Exception:
            pass
    img.pixels.foreach_set(np.ascontiguousarray(np.clip(arr, 0, 1)[::-1], dtype=np.float32).ravel())
    img.update()
    os.makedirs(SAVE_DIR, exist_ok=True)
    img.filepath_raw = os.path.join(SAVE_DIR, name + '.png')
    img.file_format = 'PNG'
    img.save()
    img.pack()
    return img


def _principled(name, diffuse):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial'); out.location = (500, 0)
    bsdf = nt.nodes.new('ShaderNodeBsdfPrincipled'); bsdf.location = (200, 0)
    nt.links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])
    m.diffuse_color = diffuse
    return m, nt, bsdf


def make_body_material(col_img, nrm_img, rgh_img):
    m, nt, bsdf = _principled(NAME + '_Skin', (0.8, 0.8, 0.8, 1))
    tex = nt.nodes.new('ShaderNodeTexImage'); tex.location = (-350, 120); tex.image = col_img
    ntex = nt.nodes.new('ShaderNodeTexImage'); ntex.location = (-350, -200); ntex.image = nrm_img
    nmap = nt.nodes.new('ShaderNodeNormalMap'); nmap.location = (-50, -200)
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    nt.links.new(ntex.outputs['Color'], nmap.inputs['Color'])
    nt.links.new(nmap.outputs['Normal'], bsdf.inputs['Normal'])
    rtex = nt.nodes.new('ShaderNodeTexImage'); rtex.location = (-350, -480); rtex.image = rgh_img
    nt.links.new(rtex.outputs['Color'], bsdf.inputs['Roughness'])
    return m


def make_face_material(img):
    m, nt, bsdf = _principled(NAME + '_FaceMat', (0.9, 0.9, 0.9, 1))
    tex = nt.nodes.new('ShaderNodeTexImage'); tex.location = (-300, 0); tex.image = img
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    nt.links.new(tex.outputs['Alpha'], bsdf.inputs['Alpha'])
    bsdf.inputs['Roughness'].default_value = 0.3
    try:
        m.surface_render_method = 'BLENDED'
    except Exception:
        pass
    return m


def mesh_from(mb, mat_id, name, material, bones):
    faces = [i for i, m in enumerate(mb.MAT) if m == mat_id]
    if not faces:
        return None
    used = sorted({v for i in faces for v in mb.F[i]})
    remap = {v: k for k, v in enumerate(used)}
    verts = [tuple(mb.V[v]) for v in used]
    polys = [[remap[v] for v in mb.F[i]] for i in faces]
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], polys)
    me.update()
    uv = me.uv_layers.new(name='UVMap')
    for p, fi in zip(me.polygons, faces):
        for li, (u, v) in zip(p.loop_indices, mb.UV[fi]):
            uv.data[li].uv = (u, v)
    me.materials.append(material)
    try:
        me.shade_smooth()
        me.set_sharp_from_angle(angle=math.radians(SHARP_ANGLE))
    except Exception as ex:
        print('smooth fallback', ex)
        for p in me.polygons:
            p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    for b in bones:
        ob.vertex_groups.new(name=b[0])
    for v in used:
        for bone, w in mb.W[v].items():
            ob.vertex_groups[bone].add([remap[v]], w, 'REPLACE')
    return ob


def build_rig(name, coll, bones):
    arm = bpy.data.armatures.new(name)
    rig = bpy.data.objects.new(name, arm)
    coll.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    ebs = {}
    for bname, head, tail, parent in bones:
        eb = arm.edit_bones.new(bname)
        eb.head = Vector(tuple(head))
        eb.tail = Vector(tuple(tail))
        d = Vector(tuple(tail)) - Vector(tuple(head))
        if d.length < 1e-4:
            eb.tail = eb.head + Vector((0, 0, 0.1))
            d = Vector((0, 0, 0.1))
        if abs(d.normalized().z) < 0.9:
            eb.align_roll(Vector((0, 0, 1)))
        else:
            eb.align_roll(Vector((0, -1, 0)))
        eb.use_deform = True
        ebs[bname] = eb
    for bname, head, tail, parent in bones:
        if parent:
            ebs[bname].parent = ebs[parent]
            ebs[bname].use_connect = False
    bpy.ops.object.mode_set(mode='OBJECT')
    arm.display_type = 'STICK'
    rig.show_in_front = True
    for pb in rig.pose.bones:
        pb.rotation_mode = 'QUATERNION'
    return rig


def bind(ob, rig):
    ob.parent = rig
    mod = ob.modifiers.new('Armature', 'ARMATURE')
    mod.object = rig


def to_local(rig, bname, R, t):
    Rb = rig.data.bones[bname].matrix_local.to_3x3()
    Rw = Matrix([list(R[0]), list(R[1]), list(R[2])])
    Rl = Rb.transposed() @ Rw @ Rb
    return Rl.to_quaternion(), Rb.transposed() @ Vector(tuple(t))


def bake_action(rig, aname, anim, bones):
    act = bpy.data.actions.get(aname)
    if act:
        bpy.data.actions.remove(act)
    act = bpy.data.actions.new(aname)
    act.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = act
    try:
        if len(act.slots) == 0 and hasattr(act, 'slots'):
            pass
    except Exception:
        pass
    names = [b[0] for b in bones]
    prev = {}
    for f in sorted(anim['keys']):
        pose = anim['keys'][f]
        for bname in names:
            R, t = pose.get(bname, (np.eye(3), V(0, 0, 0)))
            q, loc = to_local(rig, bname, R, t)
            if bname in prev:
                q.make_compatible(prev[bname])
            prev[bname] = q
            pb = rig.pose.bones[bname]
            pb.rotation_quaternion = q
            pb.location = loc
            pb.keyframe_insert('rotation_quaternion', frame=f, group=bname)
            pb.keyframe_insert('location', frame=f, group=bname)
    return act


def run():
    bones = bones_def()
    mb = build()
    sname = NAME + 'Pet'
    old = bpy.data.scenes.get(sname)
    if old:
        old.name = sname + '_old'
    scn = bpy.data.scenes.new(sname)
    bpy.context.window.scene = scn
    if old:
        for ob in list(old.objects):
            bpy.data.objects.remove(ob, do_unlink=True)
        for c in list(old.collection.children_recursive):
            bpy.data.collections.remove(c)
        bpy.data.scenes.remove(old)
    scn.render.fps = FPS
    scn.view_settings.view_transform = 'Standard'
    exp = bpy.data.collections.new(NAME + '_Export')
    scn.collection.children.link(exp)

    col1, hgt, rgh = paint_atlas(1)
    col2 = paint_atlas(2)[0]
    col3 = paint_atlas(3)[0]
    ns = globals().get('NORMAL_STRENGTH', 2.5)
    col_img = save_rgba(NAME + '_Color', col1)
    save_rgba(NAME + '_Color_L2', col2)
    save_rgba(NAME + '_Color_L3', col3)
    nrm_img = save_rgba(NAME + '_Normal', normal_from_height(hgt, ns), data=True)
    rgh_img = save_rgba(NAME + '_Roughness', rgh, data=True)
    face1 = save_rgba(NAME + '_Face', face_texture(1))
    save_rgba(NAME + '_Face_L2', face_texture(2))
    save_rgba(NAME + '_Face_L3', face_texture(3))
    m_body = make_body_material(col_img, nrm_img, rgh_img)
    m_face = make_face_material(face1)

    rig = build_rig(NAME + '_Rig', exp, bones)
    objs = []
    for mat_id, suffix, material in ((0, 'Body', m_body), (1, 'Face', m_face), (2, 'L2', m_body), (3, 'L3', m_body)):
        ob = mesh_from(mb, mat_id, NAME + '_' + suffix, material, bones)
        if ob is not None:
            exp.objects.link(ob)
            bind(ob, rig)
            objs.append(ob)
    acts = {}
    for aname, fn in ANIMS.items():
        acts[aname] = bake_action(rig, NAME + '_' + aname, fn(), bones)
    rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)

    tc = lambda o: sum(len(p.vertices) - 2 for p in o.data.polygons)
    counts = {o.name: tc(o) for o in objs}
    os.makedirs(SAVE_DIR, exist_ok=True)
    bpy.data.libraries.write(os.path.join(SAVE_DIR, NAME + '_Pet.blend'), {scn}, fake_user=True, compress=True)
    # FBX in the bind pose: textures referenced by file name, found next to the .fbx by Studio's importer
    rig.data.pose_position = 'REST'
    for o in bpy.context.view_layer.objects:
        o.select_set(o in objs or o == rig)
    bpy.context.view_layer.objects.active = rig
    fp = os.path.join(SAVE_DIR, NAME + '_Pet.fbx')
    bpy.ops.export_scene.fbx(filepath=fp, use_selection=True, object_types={'ARMATURE', 'MESH'}, add_leaf_bones=False,
                             bake_anim=False, axis_forward='Z', axis_up='Y',
                             path_mode='STRIP', embed_textures=False)
    rig.data.pose_position = 'POSE'
    print('PET BUILT', NAME, counts, 'ALL:', sum(counts.values()), 'bones:', len(rig.data.bones),
          'actions:', list(acts), 'fbx:', os.path.getsize(fp))
    return counts


run()
```

## Appendix E: `make_build.py`

```python
"""Writes build/<pet>_build.py: a single self-contained script for Blender's Python console
(petkit + the pet module embedded as base64 modules, then pet_blender.py).

usage (from the pet-kit folder):
    python3 make_build.py mypet/mypet.py [other/other.py ...] [--save-root "C:\\path\\to\\models"]

  <pet>.py       one or more pet modules (SPEC.md module API). The build key is the file name without .py.
                 Relative paths are tried against the current folder first, then against this kit folder.
  --save-root    optional: bake an output folder into the build script (sets SAVE_ROOT in pet_blender.py).
                 Without it the script writes to SAVE_ROOT as set in pet_blender.py, or, if that is None,
                 to build/models/<name>/ next to the build script.

The pet module is embedded on its own: it may import only petkit, numpy and the standard library
(no PIL, no helper files of your own; those are not inside Blender).

Then in Blender 5: Scripting workspace > Python console:
    exec(open(r'<full path>/build/<pet>_build.py').read())
"""
import base64
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.join(HERE, 'build')


def b64(path):
    return base64.b64encode(open(path, 'rb').read()).decode()


def resolve(p):
    for cand in (os.path.abspath(p), os.path.join(HERE, p)):
        if os.path.isfile(cand):
            return cand
    sys.exit('make_build: pet module not found: %s' % p)


def main(argv):
    save_root, pets = None, []
    it = iter(argv)
    for a in it:
        if a == '--save-root':
            save_root = next(it, None)
            if not save_root:
                sys.exit('make_build: --save-root needs a folder')
        elif a.startswith('--save-root='):
            save_root = a.split('=', 1)[1]
        elif a in ('-h', '--help'):
            print(__doc__)
            return
        else:
            pets.append(a)
    if not pets:
        print(__doc__)
        sys.exit('make_build: give at least one pet module, e.g. python3 make_build.py mypet/mypet.py')

    body = open(os.path.join(HERE, 'pet_blender.py')).read()
    if save_root:
        body, n = re.subn(r'(?m)^SAVE_ROOT = .*$', lambda m: 'SAVE_ROOT = %r' % save_root, body, count=1)
        assert n == 1, 'pet_blender.py: SAVE_ROOT line not found'
    os.makedirs(BUILD, exist_ok=True)
    for p in pets:
        path = resolve(p)
        key = os.path.splitext(os.path.basename(path))[0]
        src = ['# Auto-generated: build the %s pet in Blender (exec this file from the Python console).' % key,
               'import sys, types, base64, math',
               'import numpy as np',
               'BUILD_DIR = %r   # folder this script was generated in (default output: BUILD_DIR/models)' % BUILD,
               'def _petmod(name, data):',
               '    m = types.ModuleType(name)',
               "    m.__file__ = name + '.py'",
               '    sys.modules[name] = m',
               "    exec(compile(base64.b64decode(data).decode('utf-8'), name + '.py', 'exec'), m.__dict__)",
               '    return m',
               "_petmod('petkit', '%s')" % b64(os.path.join(HERE, 'petkit.py')),
               "_PET = _petmod('pet_%s', '%s')" % (key, b64(path)),
               "globals().update({k: v for k, v in vars(_PET).items() if not k.startswith('__')})",
               '']
        out = os.path.join(BUILD, '%s_build.py' % key)
        open(out, 'w').write('\n'.join(src) + body)
        print(out, os.path.getsize(out))


if __name__ == '__main__':
    main(sys.argv[1:])
```

## Appendix F: `export_pet_anims.py`

```python
"""Export a pet module's ANIMS as a Luau data module for PetRig (Roblox model axes).
usage: python3 export_pet_anims.py <pet folder> <out.luau> <ModuleName>"""
import sys, os, math, importlib
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
pet = sys.argv[1]
sys.path.insert(0, os.path.join(HERE, pet)); sys.path.insert(0, HERE)
P = importlib.import_module(pet)
M = np.array([[-1, 0, 0], [0, 0, 1], [0, 1, 0]], float)
BONES = [b[0] for b in P.bones_def()]


def quat(R):
    t = np.trace(R)
    if t > 0:
        s = math.sqrt(t + 1.0) * 2
        w = 0.25 * s; x = (R[2, 1] - R[1, 2]) / s; y = (R[0, 2] - R[2, 0]) / s; z = (R[1, 0] - R[0, 1]) / s
    elif R[0, 0] > R[1, 1] and R[0, 0] > R[2, 2]:
        s = math.sqrt(1.0 + R[0, 0] - R[1, 1] - R[2, 2]) * 2
        w = (R[2, 1] - R[1, 2]) / s; x = 0.25 * s; y = (R[0, 1] + R[1, 0]) / s; z = (R[0, 2] + R[2, 0]) / s
    elif R[1, 1] > R[2, 2]:
        s = math.sqrt(1.0 + R[1, 1] - R[0, 0] - R[2, 2]) * 2
        w = (R[0, 2] - R[2, 0]) / s; x = (R[0, 1] + R[1, 0]) / s; y = 0.25 * s; z = (R[1, 2] + R[2, 1]) / s
    else:
        s = math.sqrt(1.0 + R[2, 2] - R[0, 0] - R[1, 1]) * 2
        w = (R[1, 0] - R[0, 1]) / s; x = (R[0, 2] + R[2, 0]) / s; y = (R[1, 2] + R[2, 1]) / s; z = 0.25 * s
    q = np.array([x, y, z, w])
    return q / np.linalg.norm(q)


def fmt(v):
    s = ('%.4f' % v).rstrip('0').rstrip('.')
    return '0' if s in ('-0', '') else s


out = ['-- %s: baked from pets/%s/%s.py. Do not edit by hand.' % (sys.argv[3], pet, pet),
       '-- Per key: for each bone in `bones`: qx, qy, qz, qw, tx, ty, tz (model axes, rest-relative,',
       '-- rotation about the bone head in model space; translation in studs at rig scale 1).',
       'return {']
for name, fn in P.ANIMS.items():
    a = fn()
    keys = a['keys']
    ks = sorted(keys)
    used = [b for b in BONES if any(b in keys[k] for k in ks)]
    out.append('\t%s = {' % name)
    out.append('\t\tframes = %d, loop = %s,' % (a['frames'], 'true' if a['loop'] else 'false'))
    out.append('\t\tbones = { %s },' % ', '.join('"%s"' % b for b in used))
    out.append('\t\tkeys = {')
    prevq = {}
    for k in ks:
        vals = []
        for b in used:
            R, t = keys[k].get(b, (np.eye(3), np.zeros(3)))
            q = quat(M @ R @ M.T)
            tr = M @ np.asarray(t, float)
            if b in prevq and np.dot(prevq[b], q) < 0:
                q = -q
            prevq[b] = q
            vals += [fmt(v) for v in q] + [fmt(v) for v in tr]
        out.append('\t\t\t{ f = %s, v = { %s } },' % (fmt(k), ', '.join(vals)))
    out.append('\t\t},')
    out.append('\t},')
out.append('}')
src = '\n'.join(out) + '\n'
open(sys.argv[2], 'w').write(src)
print(sys.argv[3], 'bytes', len(src), {n: (fn()['frames'], fn()['loop'], len(fn()['keys'])) for n, fn in P.ANIMS.items()})
```

## Appendix G: `roblox/PetRig.luau`

```lua
--!strict
-- PetRig: plays a rigged pet's baked keyframes (<Species>Anims child modules) on its Bones from code.
-- Per species: each species has its own animation set (<Species>Anims child module) and rest cache.
-- Template attribute RigScale = the template's Model scale at which keyframe translations are in studs.
-- No Animation assets: works in any place whoever owns it, in Studio and live, on client-only
-- models. Keys are rotations about each bone's rest head in model axes; they are turned into
-- Bone.Transform with the bone's rest orientation: T = R^-1 * Q * R (translation R^-1 * t).
-- Between keys: Catmull-Rom (smooth through the keys, like Blender's auto curves).

local PetRig = {}
PetRig.MODULES = {
	-- [species] = "<Species>Anims" (a child ModuleScript written by export_pet_anims.py)
	Otter = "OtterAnims",
} :: { [string]: string }

local animCache: { [string]: any } = {}
local function animsFor(species: string): any
	local a = animCache[species]
	if a == nil then
		local name = PetRig.MODULES[species]
		local mod = name and script:FindFirstChild(name)
		a = if mod then require(mod :: ModuleScript) else {}
		animCache[species] = a
	end
	return a
end
PetRig.animsFor = animsFor

PetRig.__index = PetRig
PetRig.FPS = 24

type Anim = { frames: number, loop: boolean, bones: { string }, keys: { { f: number, v: { number } } } }
type Track = { name: string, anim: Anim, frame: number, speed: number }
export type Rig = typeof(setmetatable(
	{} :: {
		model: Model,
		species: string,
		anims: any,
		rest: { [string]: CFrame },
		restInv: { [string]: CFrame },
		rigScale: number,
		bones: { [string]: Bone },
		cur: Track?,
		prev: Track?,
		fade: number,
		fadeTime: number,
		names: { string },
	},
	PetRig
))

-- rest orientation of each bone relative to the model pivot, per species (same for every clone)
local REST: { [string]: { [string]: CFrame } } = {}
local REST_INV: { [string]: { [string]: CFrame } } = {}

local function rotOnly(cf: CFrame): CFrame
	return cf - cf.Position
end

local function learnRest(species: string, model: Model, bones: { [string]: Bone })
	if REST[species] then
		return
	end
	local r, ri = {}, {}
	local pivot = model:GetPivot()
	for name, b in pairs(bones) do
		local o = rotOnly(pivot:ToObjectSpace(b.WorldCFrame))
		r[name] = o
		ri[name] = o:Inverse()
	end
	REST[species] = r
	REST_INV[species] = ri
end

local function bonesOf(model: Model): ({ [string]: Bone }, { string })
	local bones: { [string]: Bone } = {}
	local names = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Bone") then
			bones[d.Name] = d
			table.insert(names, d.Name)
		end
	end
	return bones, names
end

-- Call once with the untouched template so later clones never learn from a posed rig.
function PetRig.prime(template: Model, species: string?)
	local sp = species or template.Name
	local bones = bonesOf(template)
	learnRest(sp, template, bones)
end

function PetRig.new(model: Model, species: string?): Rig
	local sp = species or (model:GetAttribute("Species") :: string?) or model.Name
	local bones, names = bonesOf(model)
	learnRest(sp, model, bones)
	local rs = model:GetAttribute("RigScale")
	local self = setmetatable({
		model = model,
		species = sp,
		anims = animsFor(sp),
		rest = REST[sp],
		restInv = REST_INV[sp],
		rigScale = if type(rs) == "number" and rs > 0 then rs else 1,
		bones = bones,
		cur = nil :: Track?,
		prev = nil :: Track?,
		fade = 1,
		fadeTime = 0.2,
		names = names,
	}, PetRig)
	return self
end

-- does this rig have an animation called name?
function PetRig.has(self: Rig, name: string): boolean
	return self.anims[name] ~= nil
end

function PetRig.length(self: Rig, name: string): number
	local a = self.anims[name]
	return if a then a.frames / PetRig.FPS else 0
end

-- sample one animation at a (fractional) frame: bone name -> { qx, qy, qz, qw, tx, ty, tz }
local function sample(anim: Anim, frame: number): { [string]: { number } }
	local keys = anim.keys
	local n = #keys
	local f = frame
	if anim.loop then
		f = f % anim.frames
	else
		f = math.clamp(f, keys[1].f, keys[n].f)
	end
	-- segment i: keys[i].f <= f <= keys[i+1].f
	local i = 1
	while i < n - 1 and keys[i + 1].f < f do
		i += 1
	end
	local k1, k2 = keys[i], keys[math.min(i + 1, n)]
	local f1, f2 = k1.f, k2.f
	local k0, k3, f0, f3
	if anim.loop then
		-- keys[1] and keys[n] are the same pose (f = 0 and f = frames)
		if i > 1 then
			k0, f0 = keys[i - 1], keys[i - 1].f
		else
			k0, f0 = keys[n - 1], keys[n - 1].f - anim.frames
		end
		if i + 2 <= n then
			k3, f3 = keys[i + 2], keys[i + 2].f
		else
			k3, f3 = keys[2], keys[2].f + anim.frames
		end
	else
		if i > 1 then
			k0, f0 = keys[i - 1], keys[i - 1].f
		else
			k0, f0 = k1, f1 - 1
		end
		if i + 2 <= n then
			k3, f3 = keys[i + 2], keys[i + 2].f
		else
			k3, f3 = k2, f2 + 1
		end
	end
	local span = math.max(f2 - f1, 1e-6)
	local s = math.clamp((f - f1) / span, 0, 1)
	local s2, s3 = s * s, s * s * s
	local h00, h10, h01, h11 = 2 * s3 - 3 * s2 + 1, s3 - 2 * s2 + s, -2 * s3 + 3 * s2, s3 - s2
	local m1s = span / math.max(f2 - f0, 1e-6)
	local m2s = span / math.max(f3 - f1, 1e-6)
	local out = {}
	local v0, v1, v2, v3 = k0.v, k1.v, k2.v, k3.v
	for b, name in ipairs(anim.bones) do
		local o = (b - 1) * 7
		local r = table.create(7, 0)
		-- keep the quaternions on one hemisphere
		local d0 = v0[o + 1] * v1[o + 1] + v0[o + 2] * v1[o + 2] + v0[o + 3] * v1[o + 3] + v0[o + 4] * v1[o + 4]
		local d2 = v2[o + 1] * v1[o + 1] + v2[o + 2] * v1[o + 2] + v2[o + 3] * v1[o + 3] + v2[o + 4] * v1[o + 4]
		local d3 = v3[o + 1] * v1[o + 1] + v3[o + 2] * v1[o + 2] + v3[o + 3] * v1[o + 3] + v3[o + 4] * v1[o + 4]
		local s0 = if d0 < 0 then -1 else 1
		local sg2 = if d2 < 0 then -1 else 1
		local sg3 = if d3 < 0 then -1 else 1
		for c = 1, 7 do
			local a0, a1, a2, a3 = v0[o + c], v1[o + c], v2[o + c], v3[o + c]
			if c <= 4 then
				a0 *= s0
				a2 *= sg2
				a3 *= sg3
			end
			local m1 = (a2 - a0) * m1s
			local m2 = (a3 - a1) * m2s
			r[c] = h00 * a1 + h10 * m1 + h01 * a2 + h11 * m2
		end
		local len = math.sqrt(r[1] * r[1] + r[2] * r[2] + r[3] * r[3] + r[4] * r[4])
		if len > 1e-6 then
			r[1] /= len
			r[2] /= len
			r[3] /= len
			r[4] /= len
		else
			r[4] = 1
		end
		out[name] = r
	end
	return out
end
PetRig.sample = sample

local IDENT = { 0, 0, 0, 1, 0, 0, 0 }

function PetRig.play(self: Rig, name: string, fadeTime: number?, speed: number?, startFrame: number?)
	local anim = self.anims[name] :: Anim?
	if not anim then
		return
	end
	local cur = self.cur
	if cur and cur.name == name then
		cur.speed = speed or cur.speed
		return
	end
	self.prev = cur
	self.cur = { name = name, anim = anim, frame = startFrame or 0, speed = speed or 1 }
	self.fadeTime = fadeTime or 0.2
	self.fade = if self.prev and self.fadeTime > 0 then 0 else 1
end

function PetRig.setSpeed(self: Rig, speed: number)
	if self.cur then
		self.cur.speed = speed
	end
end

-- current animation name and frame
function PetRig.state(self: Rig): (string?, number)
	local cur = self.cur
	if not cur then
		return nil, 0
	end
	return cur.name, cur.frame
end

function PetRig.finished(self: Rig): boolean
	local cur = self.cur
	return cur == nil or (not cur.anim.loop and cur.frame >= cur.anim.frames)
end

local function apply(self: Rig, poseA: { [string]: { number } }?, poseB: { [string]: { number } }, w: number)
	local scale = self.model:GetScale() / self.rigScale
	for name, bone in pairs(self.bones) do
		local b = poseB[name] or IDENT
		local q = b
		if poseA and w < 1 then
			local a = poseA[name] or IDENT
			local dot = a[1] * b[1] + a[2] * b[2] + a[3] * b[3] + a[4] * b[4]
			local sg = if dot < 0 then -1 else 1
			local r = table.create(7, 0)
			for c = 1, 7 do
				local av = a[c]
				if c <= 4 then
					av *= sg
				end
				r[c] = av + (b[c] - av) * w
			end
			local len = math.sqrt(r[1] * r[1] + r[2] * r[2] + r[3] * r[3] + r[4] * r[4])
			r[1] /= len
			r[2] /= len
			r[3] /= len
			r[4] /= len
			q = r
		end
		local R, Ri = self.rest[name], self.restInv[name]
		if R then
			local Q = CFrame.new(0, 0, 0, q[1], q[2], q[3], q[4])
			local t = Vector3.new(q[5], q[6], q[7]) * scale
			bone.Transform = CFrame.new(Ri * t) * (Ri * Q * R)
		end
	end
end

function PetRig.step(self: Rig, dt: number)
	local cur = self.cur
	if not cur then
		return
	end
	local fps = PetRig.FPS
	cur.frame += dt * fps * cur.speed
	if not cur.anim.loop and cur.frame > cur.anim.frames then
		cur.frame = cur.anim.frames
	end
	local prev = self.prev
	local poseA = nil
	if prev and self.fade < 1 then
		prev.frame += dt * fps * prev.speed
		if not prev.anim.loop and prev.frame > prev.anim.frames then
			prev.frame = prev.anim.frames
		end
		self.fade = math.min(1, self.fade + dt / math.max(self.fadeTime, 1e-3))
		poseA = sample(prev.anim, prev.frame)
	else
		self.prev = nil
	end
	local w = self.fade
	w = w * w * (3 - 2 * w)
	apply(self, poseA, sample(cur.anim, cur.frame), w)
end

-- show one frame of one animation right now (viewports, thumbnails)
function PetRig.pose(self: Rig, name: string, frame: number)
	local anim = self.anims[name] :: Anim?
	if anim then
		apply(self, nil, sample(anim, frame), 1)
	end
end

-- back to the bind pose
function PetRig.reset(self: Rig)
	for _, b in pairs(self.bones) do
		b.Transform = CFrame.identity
	end
end

return PetRig
```
