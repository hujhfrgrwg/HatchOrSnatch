# Ability sounds (HOS-SFX-001)

**Source and licence for every sound.**
- All are real recordings from Roblox's licensed **Pro Sound Effects** library on the Creator Store.
- Creator: "ProSoundEffects" (verified, user 7462895450). Free to use in Roblox experiences; credit line "Courtesy of Pro Sound Effects".
- Nothing is synthesised or AI-made, and nothing was uploaded by us.

**Where they're set:**
- Config: `ReplicatedStorage.EOS.Shared.AbilitySounds`.
- Played by `Controllers.AbilityVFX` (and `Controllers.Invisibility` for on/off) through `SoundService.Abilities`, a SoundGroup at volume 0.55.
- Positioned in 3D with inverse-tapered rolloff: full volume within 12 studs, silent past 90.

| Key | When | Asset id | Pro Sound Effects title | Play settings |
|---|---|---|---|---|
| DecoySplit | Decoy copy runs off | 9120711172 | Whoosh Fast Swish By 7 | vol 0.7, speed 1.1 |
| DecoyPoof | Decoy copy leaves | 9117848644 | Pops Mouth Popping Multiple Versions 7 | vol 0.8 |
| Snare | Snare drops (lasting effect appears) | 9113760544 | Chain Movement 8 | vol 0.8 |
| SnareTrigger | A Runner steps in | 9113760085 | Chain Movement 1 | vol 1 |
| ShieldUp | Shield raised | 9114369767 | Fairy Dust 2 (chimes) | vol 0.7, first 1.1 s, speed 1.15 |
| ShieldBreak | Shield blocks a tag | 9114593452 | Glass Breaks 20 | vol 0.9 |
| TetherYank | Tether pulls the Runner | 9114164480 | Dowel Swishes Thin Single And Multiple 21 | vol 1, speed 0.85 |
| PulseCharge | Pulse warning ring | 9116276051 | Lightning Flashes Quick Electrical Bursts 11 | vol 0.6, speed 1.3 |
| PulseBlast | Pulse goes off | 9116277954 | Lightning Flashes Quick Electrical Bursts 32 | vol 0.9 |
| KnockHit | Each Catcher pushed | 9113476527 | Body Fall Master 36 | vol 0.7 |
| StormBall | Ball rolling (loop) | 9114237487 | Electric Arcing 4 | vol 0.45, looped while the ball exists |
| StormBounce | Ball hits a wall | 9116684830 | Metal Impacts 3 | vol 0.9 |
| StormHit | Ball hits a Runner | 9116275998 | Lightning Flashes Quick Electrical Bursts 13 | vol 1 |
| RiftPortal | Portal Hop portals open | 9119467870 | Spirit Pass Bys Fast Overlapping Whooshes 3 | vol 0.6, first 1.2 s, speed 1.2 |
| RiftArrive | Someone lands from a Rift | 9120716870 | Whoosh Fast Swish By 4 | vol 0.7, speed 1.15 |
| RiftReticle | Blink warning reticle | 9113089565 | Alarm Tone 2 Tone Fast High Low Switching 2 | vol 0.45, first 0.6 s |
| RiftFizzle | A Rift fizzles | 9119583983 | Static Many Various Length Bursts 24 | vol 0.7 |
| InvisOn | Default cloak on | 9113069659 | Air Fingers Short Swooshing Bursts Sucking 1 | vol 0.6, first 1.4 s |
| InvisOff | Default cloak off | 9114159111 | Doppler Whooshes Crackly Airy Bursts 1 | vol 0.6, first 1.2 s |

Silent on purpose: Rooted, Slowed, ShieldBubble, TetherBeam (the trigger, hit, up and yank sounds cover them).

## Per-pet sounds
Sounds use the same lookup as the VFX: `AbilityCosmetics.sfx(species, key)`.
- To swap a sound for one species: `SPECIES.Fox = { sfx = { PulseBlast = "SomeOtherKey" } }`, where the key is in `AbilitySounds.SOUNDS`. Use `AbilityCosmetics.NONE` for silence.
- A species whose own effect covers a key (its `vfx` for that key is NONE) gets no default sound there either.
  - Crow and Kitsune play no default split or poof sound; they keep their own summon sounds (the Sound controller's "poof" / "evolve", unchanged).
  - Grim Ghost and Prism Chameleon play no cloak on/off sounds.

## Checked (2-player playtest)
- Mouse Tempest Catcher: roll loop at the throw, bounce sound 0.43 s, hit 0.63 s. All go through the Abilities group, and the loop stops with the ball.
- Mouse Decoy Catcher: snare drop on the snare.
- Crow Decoy Runner: no default sounds.
- Mouse cloak: on and off sounds. Grim Ghost: none.
- No errors. All 19 ids load in Studio.
