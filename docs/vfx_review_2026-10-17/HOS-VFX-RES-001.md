# HOS-VFX-RES-001: resource place review and textured egg trails (17 Oct)

Source: `C:\Users\hunte\Downloads\UNSORTED OS RESOURCES.rbxl`, a community "open source" VFX dump. Only read; nothing saved there.

## Changed in the game place
`ServerScriptService.EOS.Services.EconomyService` `trailOn`: Sparkle, Ember and Rainbow egg trails are now textured trail layers instead of flat colour strips. Same lifetime range, colours, hitboxes and timing. Backup: `docs/backups/HOS-VFX-RES-001_2026-10-17/EconomyService.lua`.

## Textures in use that are not ours
If one is deleted, that trail layer draws blank (no error). Replace them with our own uploads when we draw them.

| Use | Asset id | Uploader |
|---|---|---|
| Sparkle trail, main | 18568183566 | realkilometers |
| Sparkle + Rainbow glitter layer | 18568048335 | realkilometers |
| Ember trail | 70464235210468 | BloxenRBLX |
| Rainbow trail, main | 99421661918040 | Arisu Club (group) |

## Shortlist for later (see the screenshots and sheets in this folder)
1. Rift skins: the PortalFx set recolours from one `Colouring` Color3Value.
2. More permanent egg trails: Stardust, wisp, water, prismatic pink, lightning arc.
3. Guardian dome / egg case skins: Forcefield Texture Pack (ForceField material + texture).
4. Hatching and lobby bursts: confetti, magic burst, heart dissolve, butterfly, magic circle, runes flipbooks.
5. Decoy poof variants: smoke ring, hearts, butterflies, glitch (poof only; the copy keeps its look).

Avoid: Rho Aias (Fate), JJK, Bleach, One Piece, Dragon Ball effects, Yinlin/Changli (Wuthering Waves), and `RANDOM AHH ASSETS` (game rips).
Already deleted at review time: bubble pop 9295449811, water bubble 14850580310, wind trail 17899313357.

| Confetti Burst | 11137599166 | IxJoke |

## Rift skins (installed 17 Oct, Hunter OK'd)
Shop items `fx_rift_void` / `fx_rift_inferno` / `fx_rift_frost` (Effects tab, 200 Gems each, Gems only, `kind = "abilitySkin"`, `slot = "riftSkin"`). Buying wears it; Wear / Take off like egg cases (`ProfileLogic.setCosmetic` slot `riftSkin`). `AbilityService` loadout reads `cosmetics.riftSkin` at match start and passes `ctx.skin = "skin:<id>"`; `Abilities.Rift` draws the skin's portal unless the pet has its own (Imp, Hare, Djinn, Seraph keep theirs). `Shared.AbilityCosmetics.SKINS` maps it to `ReplicatedStorage.VFX.Abilities.SkinVoidRiftPortal / SkinInfernoRiftPortal / SkinFrostRiftPortal` (the resource PortalFx swirl layers scaled to our 6.4-stud portal, 0.5 s emit, brightness capped at 3). Only the Hop portals change; arrive, reticle and fizzle stay default.
Checked: all 7 touched scripts compile; in a live server the skin resolves to its template, Ring Imp keeps ImpRiftPortal, plain Rift keeps RiftPortal, no errors. Not yet seen on screen (Studio screenshots of the game window fail while it isn't in front). Owed: a look in Play, Robux prices if wanted.
Edit list: `rift_skin_edits.json`. Backups: `docs/backups/HOS-VFX-RES-001_2026-10-17/`.
