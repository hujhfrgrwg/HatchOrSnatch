# Ring Imp (Rift, Common) — build notes

Design (Hunter picked TEAL): teal body, cream face mask + belly, big gold eyes, sly one-fang grin, short swept-back
dark horns with gold tips (no rings), pointed ears, spade tail, dark collar with gold trim, magenta-to-cyan portal
ring floating behind its back like a halo. L2: glowing runes on the ring. L3: second smaller ring + sparkles. Hovers.

Module: `tools/pet-kit/imp/imp.py` (copy here as `imp_module_copy.py`; older drafts imp_v0_violet.py, imp_v1.py).
Build: `docs/pets/ring_imp/build/imp/` (Imp_Pet.blend/.fbx + Color/Emit/Face/Normal/Roughness PNGs). Nothing uploaded.

## Checks and the skill step that produced each

| Check | Result | Skill step |
|---|---|---|
| Triangle count under Hunter's 2,000 cap | L1 1,176 / L2 1,384 / L3 1,544 | roblox-game-pipeline models.md "report tris" (cap from Hunter's rules) |
| Pivot / feet: lowest point z 0.16 (hover gap) | ok | pipeline models.md pivot check |
| Open edges | only the ring seam (intended) | pipeline models.md "check the exported file" |
| Exported FBX has mesh content | ok after use_selection=False fix | pipeline models.md "check the exported file" |
| Rig: 17 bones, joints buried, 5 actions (Idle, Walk, Float, Hop, Ability) | ok | RoClicks Animation guide (rigging) |
| Clip check: ring passes the body in Ability frames 4-14 | intended (it steps through its ring) | pet kit make_previews clip check |
| Colours measured against the card | teal/cream/gold palette from Hunter's pick | pipeline models.md "measure colours from the reference" |
| Smooth Blender renders, L1 five angles + L1-L3 card angle | previews/ | pet kit render_pet_blender.py (HOS) |
| 12 player-height screenshots under game lighting | NOT YET: lineup is staged, but another thread's playtest holds the Studio view | pipeline qa.md |

Studio lineup data (upload-free, vertex-coloured EditableMesh): `ImpPreviewData.rbxmx` from
`tools/pet-kit/export_preview_lua.py`. Goes in a Studio-only preview folder (Archivable false), deleted before any playtest.

## Pass 6 (17 Oct, Crow quality bar)
Crow studied read-only in the place (PetLineup + asset thumbnails): clean faceting, matte, subtle painted grain, small
flush eyes, a normal map doing the softening. Changes:
- cream face mask now sits around the eyes and the muzzle, warm cream (was a lilac-to-grey gradient: the grey muzzle)
- horns bigger, rise up then sweep back, slate base with faint ridges, gold over the top 45% (were small dark kinks)
- eyes smaller (r 0.135, flush), ears chunkier, skin matte (roughness 0.55), periodic fur grain + height map
- tris L1 1,208 / L2 1,416 / L3 1,576 (cap 2,000); checks: no issues, ring seam open edges only, Ability clip intended
Renders: previews_pass6/ (pass 5 kept in previews/ for comparison).
Studio lineup: Workspace._ImpPreview (Archivable false): Imp L1-L3 as EditableMesh + EditableImage (no upload) at
x 1544.6 beside the PetLineup columns, plus a Crow L1 clone to compare. Built by tools/pet-kit/export_preview_lua.py.
Delete the folder before any playtest of mine; it is non-archivable, so others' playtests don't copy it.
Open: gold horn tips look slightly split at the very tip in close-up.

## Hunter feedback log
- 17 Oct 06:33: "the imp needs a rework, so that it doesnt look like a happy little imp. our pets are supposed to look as
  if theyre more anime/edgy. also, the eyes arent attached and feel really large". Standing rule now in
  docs/pets/PET_LESSONS.md.

## Pass 7 (17 Oct, anime / edgy rework, still teal)
- Mood: no smile; thin one-sided smirk + one small fang, angry slanted mask line; glares out from under it.
- Eyes: narrow almonds slanting down to the nose, glowing gold iris + slit pupil (magenta at L3), about half the old
  size, PAINTED on a face decal shell (mat 1, a copy of the head's front facets lifted 0.009 with the same weights).
  check_eyes_flush.py: 37 shell verts, 135 frames, max gap 0.009 studs -> OK.
- Palette: deeper teal, near-black horns / mask / claws / hands / feet / wing membranes; cream mask + belly dropped;
  dark V on the chest; glowing cyan cheek + forehead runes (emissive, FaceEmit masks).
- Silhouette: lean torso + angular head, long swept-back horns with sharp gold tips (split fixed: tube side_hint -x),
  long pointed ears, tattered bat wings (3 blades per side, Wing bones, flap in every anim), 3 claws per hand,
  sharp arrow spade.
- Levels: L2 brighter runes, glowing magenta claws, ring runes, bracelets. L3 second ring, sparks, darker richer teal,
  magenta eyes and runes.
- Tris L1 1,262 / L2 1,470 / L3 1,630 (cap 2,000); 19 bones; checks: no issues, ring-seam open edges only, Ability
  ring-through-body clip intended.
- Renders: previews_pass7/ (imp_sheet_pass7.png). Pass 6 in previews_pass6/, pass 5 in previews/.
- Studio: Workspace._ImpPreview restaged with pass 7 (no glow in that preview: EditableImage colour only).

## Pass 8 (17 Oct)
Hunter 06:48: "this is a bit better, but the texture needs work, the claws are not attached properly. etc. also note
that we need 3 different levels to it like we did for the crow and kitsune".
- Texture (Kitsune atlas as the bar: fur strokes, jagged colour edges): fur-stroke streaks on skin and limbs, darker
  back with a jagged flame-tooth edge, paler jagged front, near-black tiger slashes on the back and crown, banded
  arms / legs with jagged black gloves and boots, ridged horns with a jagged gold tip, veined wings with a jagged
  glowing edge, jagged black ear tips.
- Claws: roots buried inside the hand, bigger, exiting the bottom-front (were hanging under the hand).
- Three distinct levels (like the Kitsune: each level adds pieces):
  - L1 base imp.
  - L2 "Rift Adept": second pair of horns with glowing cyan tips, shoulder spikes, tattered cape strips with a glowing
    hem, gold bracers, halo runes, glowing claws, a chest rune, brighter teal, an extra cheek rune.
  - L3 "Rift Lord": a crown of five magenta crystals on the halo, a second inner ring, two extra long wing blades a
    side, three tail spikes, darker violet-cast teal, magenta eyes / runes / tips, brow rune marks, longer forehead mark.
- Tris L1 1,198 / L2 1,534 / L3 1,758 (cap 2,000). Checks: no issues; eyes-flush OK (135 frames, max 0.009).
- Renders: previews_pass8/. Studio _ImpPreview restaged with pass 8.

## Animation pass 1 (17 Oct)
Hunter 06:51: "it obviously needs it own unique animations for idle, ability casts and whatnot. and for the vfx for the
actual abilities themselves".
- Idle (3 s): hangs in the air head-low, arms half-folded with claws curled, a sly look aside, one tail whip, wings
  breathe then a quick double flap, ears twitch, halo turns once.
- Walk / Run: glides (no steps), leaning in, legs and tail trailing, arms swept back, wings beating twice a cycle.
- Hop: coils, flings arms and wings open at the top.
- Ability (Portal Relocation, 1 s): lifts the halo flat overhead, hurls it upright in front, spins it, dives through.
- Blink (0.65 s): coils with claws crossed, then a sharp snap flings arms, wings, legs and tail wide (the flash).
- Checks: anims.png (signs verified), eyes-flush 176 frames OK. Blender GIFs in anims_pass1/ (render_pet_anims.py).
- Tooling: pet_blender_hos now writes the actions into the .blend (they were dropped on save).

## Effects pass 1 (17 Oct, roblox-vfx loop)
- ReplicatedStorage.VFX.Abilities.ImpRiftPortal (Runner, both ends; same size / 0.62 s timing as RiftPortal):
  void-swirl flipbook core (dark), rune-text ring magenta + dark twin, gold rim + dark twin, cyan-to-magenta inner
  vortex, magenta glow, jagged gold / pink shard sparks, magenta light.
- ImpRiftArrive (Blink departure + arrival, portal landing; same 0.4 s ring burst size): violet ring burst + dark twin,
  spinning rune ring on the ground + dark twin, violet flash + white core flash, magenta-violet shard burst + dark twin.
- Textures from AllVFX in vfx/imp/tex/ (imp_runering, imp_voidswirl_4x4, imp_shard, imp_shard_jag), shown through
  vfxtex preview addresses (rbxasset://textures/vfxpreview/025930/...). NOT uploaded: waiting for Hunter's yes.
- Capture.hold check: one moment taken (portal at 0.15 s) before another thread's playtest took the view; the rest of
  the 4-6 moments per effect are still owed.
- Still to do: ImpSummon_L1-L3, ImpPet controller (summon plays Ability / Blink by role), AbilityCosmetics entry
  (shared: needs the coordinator's OK), licensed sounds from the Roblox library.

## Reference study + summon / controller (17 Oct)
Hunter 06:55: "This looks good as long as you can animate it well and produce quality ability vfx and whatnot".
Hunter 06:58: "reference the other pets ... so we can train this thread for future pet generations". The reference
study is in docs/pets/PET_LESSONS.md ("Reference pets").
- ImpSummon_L1-L3 (VFX): Crow-decoy pacing (Gather 0.12 s -> dark Backing + violet Flash + white core + spinning rune
  ring + dark twin + stars + shard streaks + dark twin + violet light). L2 adds a counter-spinning cyan rune ring and
  rising cyan glints; L3 a void-swirl flipbook, magenta crystal gems and a pillar (the Toad / Beetle L3 pattern).
  Counts 16/22/28 stars, 9/12/15 shards.
- ImpPet.luau (docs/pets/ring_imp/, not in the place yet): Manta-style hover follower (Idle / Walk / Run by speed,
  banks into turns); summon drops out of a rift at your front-right, plays Ability (Runner) or Blink (Catcher),
  ImpSummon flash at 0.42 s, blinks into you.
- ImpAnims.luau exported (export_pet_anims.py): Idle 72 f, Walk 24, Run 16, Hop 16, Ability 24, Blink 16.
- Needs before it can run: the model uploaded (Hunter's yes), and shared one-line registrations (coordinator's OK):
  PetRig.MODULES, PetBehaviors.MODULES, AbilityCosmetics.SPECIES["Ring Imp"] = { vfx = { RiftPortal =
  "ImpRiftPortal", RiftArrive = "ImpRiftArrive" } }, and the summon INTRO in AbilityService if it is per species.

## Animation pass 2 (17 Oct)
Hunter 07:06: "the run and walk look odd. it should be a flying floating pet".
- Walk / Run are now flight (Crow Fly as the reference: one wing beat per cycle): body pitched forward into a
  superman line (38 deg walk / 62 deg run), head countered to look ahead, legs and tail streaming behind, arms tucked
  back, big wing beats (38 / 48 deg) with the body lifting on the downstroke, ears swept back. The halo no longer spins
  in flight (spinning about world Y under a pitched body made it tumble). GIFs: anims_pass2/.
- Lesson (PET_LESSONS): a ring / prop spun about a world axis tumbles once its parent is pitched; keep it steady.

## Upload + install (17 Oct)
Hunter 07:10: "yes" (upload the Imp: model, its textures, the four effect textures).
- 19 assets uploaded to group 228184582, logged in docs/VFX-LEDGER.md (FBX 111944236975096; colour / normal /
  roughness / emissive per level; face colour + face emissive per level; 4 AllVFX textures).
- Template: ReplicatedStorage.EOS.Assets.Pets["Ring Imp"] (HOS_InstallPet: Prefix Imp_, BaseScale 0.75, RigScale
  0.01, Tris 1758, 19 bones), RenderFidelity Precise, CollisionFidelity Box, Looks folder Body1-3 / Face1-3
  (AlphaMode Transparency, glowing eyes + runes) / Extra2-3, emissive 1.6 / 2.2 / 2.8 (face 2.4 / 3.0 / 3.6).
- ImpAnims under Shared.PetRig; Controllers.ImpPet. VFX templates switched from preview addresses to the uploaded
  textures (previewLeftovers = 0; two Capture leftovers removed from Workspace).
- Edit-mode check: PetModel.build("Ring Imp", 1, L) gives Body+Face / +L2 / +L3 (with an in-memory registration
  only; the shared registrations wait for the coordinator's OK).

## Hooks + playtest (17 Oct)
Hunter 07:26: "go ahead with the pet script hooks and a playtest".
- Hooks (one line / one entry each, originals in docs/backups/IMP_HOOKS_20261017/ORIGINAL_LINES.md): PetModel.RIGGED,
  PetRig.MODULES, PetBehaviors.MODULES, AbilityCosmetics.SPECIES["Ring Imp"] (RiftPortal / RiftArrive overrides),
  EconomyConfig.EXTRA_SPECIES["Ring Imp"] = "Rift". Re-read with grep after editing.
- Solo playtest (memory-only data, nothing saved), workspace EOS_TestPet set to "Ring Imp" for the test and put
  back to "Mirage Manta" after; stopped right after:
  - follower: the textured Imp hovers beside the player and follows (screenshot taken in the match).
  - ability: RIFT BLINK fired (server ok, family Rift); the Imp summon dropped out beside the player with
    ImpSummon_L1 and the default warning reticle. Level 3 summon checked: Imp dives through its halo with the crystal
    crown, L3 summon flash.
  - fix from it: the summon rune ring / void filled the screen at the player camera, shrunk to ~4 studs.
  - not done: the portal-at-both-ends shot and the 12 player-height screenshots (match cinematics kept taking the
    camera); a calmer test (no cinematic) is the next step.

## Per-level ability effects (17 Oct)
Hunter 07:42: "Make sure they look different at l2 and l3 slightly".
- Plumbing (small edits, originals in docs/backups/IMP_HOOKS_20261017): Abilities.Shared.vfx takes an optional level
  and sends it; Rift passes ctx.level on its RiftPortal / RiftArrive calls; Controllers.Pets passes t.level on;
  AbilityVFX.template tries <override>_L2 / _L3 first (only for a species override, so defaults never change).
- Templates (same size / timing as L1): ImpRiftPortal_L2 = + counter-spinning cyan rune ring, brighter gold rim,
  more sparks; _L3 = that + magenta-violet rune rim, deeper void, magenta crystal burst, brighter light.
  ImpRiftArrive_L2 = + cyan counter-spinning ground runes, rising cyan glints; _L3 = that + magenta crystal burst,
  magenta pillar, dark void floor, magenta-violet ring.
- Visual check of L1 / L2 / L3 side by side owed: another thread's playtest held Studio right after.

Effects (after look approval): Portal Relocation + Blink via the roblox-vfx loop (Capture.hold checks), AllVFX
textures, licensed recorded sounds, as Imp overrides in AbilityCosmetics (ask coordinator first).
