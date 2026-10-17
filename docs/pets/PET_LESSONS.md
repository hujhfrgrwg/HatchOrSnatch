# Pet lessons (shared, every pet)

The friend's guide section 6 lessons apply too (`Pet Pipeline Guide.md`). This file holds Hunter's own feedback for
Hatch or Snatch pets. Read it before every pet pass and add to it after every review.

## Look
- **Anime / edgy, never cute or cheerful** (Hunter, 17 Oct, on the Ring Imp: "doesnt look like a happy little imp. our
  pets are supposed to look as if theyre more anime/edgy"). References in our place: Shadow Crow (sharp red eyes, dark
  palette) and Spirit Kitsune (markings, mask feel).
  - Mood is sly or menacing: no smiles; a flat mouth or a thin one-sided smirk with one small fang.
  - Deep, darker body colours with near-black accents (horn bases, a mask around the eyes, claw tips, wing membranes).
  - Glow comes from small sharp markings (runes, eyes, claw tips), emissive, not from big bright areas.
  - Silhouettes are sharp and angular: pointed ears, swept-back horns, claws, pointed wings and tails. Avoid round,
    chubby, chibi shapes, but keep the forms chunky enough to read at follower size, like the Crow.
- **Eyes** (Hunter, 17 Oct: "the eyes arent attached and feel really large").
  - Narrow, angled anime eyes that slant down toward the nose, small for the head, with a glowing iris and a slit pupil.
  - They must be attached: painted on the face decal shell (a lifted copy of the head's front facets with the same
    skin weights) or set in a carved socket. Never a floating disc.
  - Check with `check_eyes_flush.py` (every frame) and in the head close-up from front, side and 3/4.
- Earlier on the Toad and Imp: "goofy / sleepy eyes" were rejected; a wide eye with a lid wedge reads sleepy.

- **Texture detail** (Hunter, 17 Oct: "the texture needs work"): flat gradients are not enough. Match the Kitsune
  atlas: fur strokes, jagged flame-tooth edges between colour blocks, markings and stripes, veins on membranes.
- **Attachments must be rooted**: claws, spikes and horns start inside the part they grow from (Imp claws hung under
  the hands in pass 7).
- **Three distinct levels** like the Crow and Kitsune: each level adds visible pieces that read from the front at
  follower size (L2 accessories, L3 a crown / extra wings / crystals), plus a palette step.

- **Fliers fly** (Hunter, 17 Oct, Imp: "the run and walk look odd. it should be a flying floating pet"): a floating
  pet never walks. Walk / Run are flight cycles (body pitched into the flight line, head countered, limbs and tail
  streaming, one wing beat per cycle like the Crow's Fly), Idle is a hover.

## Process
- Previews Hunter judges are Blender smooth renders (`render_pet_blender.py`), not the software previews.
- Muzzle / mask colours: check the gradient ends; a lilac gradient end made a cream muzzle read grey (Imp pass 6).
- Tube frames flip when a tube turns from vertical to horizontal (petkit loft's up-flip rule): swept-back horns twisted
  and split at the tip. Pass `side_hint=V(-1, 0, 0)` for tubes that sweep backward (Imp pass 7).
- A prop bone spun about a world axis tumbles once its parent is pitched (the Imp halo in flight): keep it steady or
  spin it about its own axis.

## Reference pets: study these before animating or building effects (Hunter, 17 Oct: "reference the other pets")
Read in the place, read-only. Every new pet is checked against them.

**Controllers** (StarterPlayerScripts.EOS.Controllers, registered in PetBehaviors.MODULES). Every module has INTRO,
newFollower / respawnFollower / updateFollower, summon(who, level) and poof(pos, level).
- Followers:
  - Ground walkers use GroundPet (Kitsune, Chameleon, Toad, Beetle): behind your right side, walk / run.
  - Fliers and floaters have their own follower: the Crow takes off when you run; the Manta (MantaPet) floats at
    right 2.3 / up 1.9 / back 2.0 with a bob, a critically damped follow, banking into turns and Idle / Glide gaits.
  - Hovering pets (Imp) copy the Manta follower.
- Summons are choreographed entrances, not a pop:
  - Kitsune runs in from behind, hops left, hops right, leaps into your back.
  - Crow swoops from behind / above and flares at your chest.
  - Manta loops round to the front and becomes a curtain.
  - Toad and Beetle pop up at your front-right, play the Ability clip (scaled to INTRO x 0.8), flash at the peak
    (FLASH_AT), then shrink into you.
  - The flash fires at the moment the server acts. Abilities fire on the press; the summon is visual only.
- Rigs: PetRig plays per-species <Name>Anims data (Kitsune Idle 48 f / Walk 24 / Run 14 / Jump 12; Toad and Beetle
  Idle / Walk / Run / Hop / Ability; Manta Idle / Glide / Wrap; Crow Idle / Walk / Fly / Swoop).

**Effects** (ReplicatedStorage.VFX, played by attributes EmitCount / EmitDelay / EmitDuration).
- Summon per level, <Pet>Summon_L1-L3 (Toad, Beetle): L1 Flash 0.16 s + Stars 16 + an element streak layer 9
  (VelocityParallel); L3 raises the counts (28 / 15) and adds Gems 10 and a Pillar 2 (VelocityPerpendicular). One
  colour family per pet.
- Crow decoy timing (the best-paced one): Gather (shrinking flash, 0.12 s) -> at +0.12 a dark Backing, Flash, Star,
  Ring (+0.13) and a PointLight -> Glints + Feathers drifting 1-1.5 s. Anticipation, then a peak, then a tail.
- Kitsune hop: L1 ring + glints; L3 adds a swirl flipbook, foxfire and paper ofuda. Levels add THEMED elements
  (torii gate at L3), not just more particles.
- Ability overrides go in AbilityCosmetics.SPECIES[species].vfx { DefaultKey = "PetTemplate" }; effects opponents
  must read (warning rings, reticles) keep the archetype's size, colour and timing.

## Install gotchas (Grin Ghost, 17 Oct)
- Particle textures need the IMAGE id, not the Decal id the uploader returns: resolve with
  `InsertService:LoadAsset(decalId):FindFirstChildWhichIsA("Decal", true).Texture` before setting ParticleEmitter.Texture.
- `EOS_Role` is "CATCHER" / "RUNNER" (upper case): compare with string.upper, or the Catcher clip never plays.
- Script edits made while a playtest is stopping can be lost: re-check templates and hooks after stopping.
- New modules go in with `import_rbxm` from a local .rbxmx (ModuleScript + Source CDATA), no pasting.

## Effect size (Hunter, 17 Oct)
- "shield abilities and whatnot should not be HUGE vfx because it will distract gameplay" then, after I shrank
  everything: "I didnt want you to nuke all of the effects. Just make sure its roughly the size of YOUR OWN humanoid
  for stuff like the shield."
- Rule: effects that sit on the caster (shield, its floor ring, flashes, break bursts) are capped at about the
  player's height (~5.5 studs across). Keep everything else at its built size and count; don't shrink across the board.
- Done on 17 Oct: the Ghost / Warden shrink was undone; only Warden ShieldUp / ShieldBubble / ShieldBreak emitters
  bigger than 5.5 studs were capped to 5.5.

## Legendaries (Eclipse Tengu, 17 Oct)
- Camera-facing flashes cloned from another pet keep that pet's size: the Crow's eye / dark flash at summon scale
  covered the player and pet. Check the in-game still at follower distance; the Tengu's eye flashes run at 55 %.
- A new layer that reuses a ground-ring texture as a FacingCamera particle reads as a solid disc: keep such flashes
  under ~2 studs Size and partly transparent.
- `SPECIES_RARITY` is not read by any script yet, so "legendary" is safe there.
- **Every pet gets its OWN ability effects** (Hunter, 17 Oct, on the Eclipse Tengu reusing the Crow's decoy burst
  recoloured): never clone and recolour a family member's effect. Draw the pet's own textures (vfx/<pet>/textures.py,
  roblox-vfx process) around a motif from its card (Tengu: black-sun eclipse, fan gust, crow feathers), with AllVFX
  picks for smoke / wisps, then build the layers from scratch. Same size and timing as the archetype; per-level steps.
- Building a pet's own effects on an archetype: clone the archetype template only for its STRUCTURE (Root,
  attachments, the Storm Ball orb / beams / trail, the Guardian dome, the Rift spark ring), strip every emitter and
  add the pet's own layers. Keep what opponents read (charge / warning rings, the shield dome) at the archetype's
  size, rate and timing; restyle everything else.
- Studio's playtest is shared with other threads: re-check `edit-claims.md` for a PLAYTEST line before Capture holds
  in edit mode too (a running playtest takes the viewport), and wait for it to clear.

## Halloween pets (HOS-HWN-001, 17 Oct)
- **Hoods must cover the top of the head** (Hunter on the Pumpkin Wraith: "The cloak sits on its head weird. It should
  cover the top of the head like a wraith"). A cowl closes over the crown with its front edge overhanging the brow and
  the face set back inside it, shadowed; never a shell perched behind the head with the face sticking out in front.
  Check the side view: the face must sit inside the hood line.
- Open shells (a hood made of a C-shaped ring) need their winding set from the ring order, not loft's "inside" point:
  the segment centre lies in the cavity, so inner faces flip and the hood looks see-through. Same for flat ribbons
  (bandage strips): orient each face away from the nearest centreline point or they render black in Blender / Roblox.
- Effects cloned from another pet carry that pet's theme layers: the Moth's crescent-moon afterimage, the Tengu's crow
  feathers and sun disc, the Ghost's chains, the Tanuki's leaves. List every emitter by name and texture after cloning
  and retexture or remove the ones that belong to the source pet before playtesting.
- A pet sold in the shop needs a shop portrait: `tools/pet-kit/render_pet_portrait.py` (transparent 3/4, Blender) ->
  crop to 320 px -> `ui/set/icons/pet_<slug>_t1.png`.
- `make_float_controller.py` writes a hover / flying controller from the Tengu's (role-based fx names); `make_controller.py`
  stays for ground walkers.
- Bash `"C:\path\$var\..."` keeps the backslash before `$` (the build went to `docs\pets$slug`): pass save roots with
  forward slashes.
- **Every pet gets its own ability effects** (standing rule, relayed 17 Oct; Hunter on the Eclipse Tengu): clone the
  family's template only for size and timing, then redraw its signature layers per pet (`vfx/<pet>/textures.py`) and
  remove the source pet's theme layers. A recolour alone is not accepted.
- Edit-viewport captures share one camera with every other session: claim `STAGE CAMERA` in edit-claims.md, build in
  your own Archivable=false folder (not `HOS_Stage`, which other sessions clear), and check no playtest is running
  (`RunService:IsRunning()`) before each capture. Freeze with `Handle:setTimeScale(0)` and step a fixed dt per frame.
- Give every pet its own BODY PLAN, not just its own paint: eight pets built on the Hound's lofted quadruped all read
  as one animal (Hunter, 17 Oct, "a lot of these pets look the same"). Check the L1 lineup as black silhouettes before
  building. A whole-pose change can be done after the build with a per-vertex transform weighted by skin weight
  (`_tilt` / `_settle` in hare.py, `_slink` in neko_src.py), applied to the bones too so names and anims still fit;
  run face_shell before the transform. `tools/pet-kit/reshape_build.sh` does the build, renders, sheets and upload list.
- Keep separate parts apart: a ring or plate that touches another surface z-fights in game (the Djinn's collar and
  jaw). Leave a clear gap or bury one part fully inside the other.

## Legendary redo (HOS-PET-REDO, 17 Oct)
- Legendaries must read as the biggest, richest pets: a big head and chest, a large signature feature (mane, wings),
  a palette no other pet uses. A reshape that keeps the right silhouette can still read "small and thin" (Raiju) or
  "a pale cat with wings" (Seraph): check the L1 render against the bar (Eclipse Tengu, Shrine Lion) before uploading.
- Palette clashes are judged across the whole roster: blue / gold Raiju vs the Riot Hound; a black cat vs the Witch Cat.
  Look at `docs/pets/reshape_lineup.jpg` (every pet at L1) before picking colours.
- Feathered wings: build them from pointed feather blades (bipyramids) fanned from a wing arm, primaries from the wrist,
  secondaries along the arm and a row of shorter coverts in front (`fwing` in seraph.py). Blades about 0.25 wide so
  they overlap into one wing; narrower blades read as a fan of knives.
- Moth wings: a pointed, hooked forewing over a separate hindwing; tail streamers must sweep out and back, or straight
  down they read as legs.
- Ghost-fire tails: thin tubes (radius 0.045 -> 0.012) with a plume of long, thin, curled bipyramid wisps (wid ~0.06,
  curl +-0.3, alternating) pointing mostly up; fat bipyramids read as "chunky blocks".
- A body-wide "belly" mask in the paint also catches the arms and the whole front of a round pet: limit it to the torso
  region and a narrow band, or the pet washes out (Djinn pass 1). `ss(e0, e1, x)` with e0 > e1 is a falling edge:
  check the sign before using it for thin bands (Djinn arms went solid gold).
- Pale patches above a dark eye mask read as a second pair of eyes (Tanuki brows).
- `reshape_build.sh` moves old previews to its backup folder only once; for a later pass use `redo_build.sh` (own
  backup folder and superseded tag) so the "before" renders survive.
- Studio edit-viewport captures right after cloning a template show grey meshes until the maps stream in: wait a few
  seconds (`ContentProvider:GetAssetFetchStatus`) and capture again.
- Sandbox playtest of any pet: set the player's `EOS_TestPet` / `EOS_TestPetLevel` on the server, add the user id to
  `workspace.EOS_TestRunnerIds` for the Runner side, and fire `Net.event("RequestAbility")` from the client; the
  loadout is taken on the first request. Restore the workspace test attributes afterwards.

