---
tags: [research, roclicks]
source: https://roclicks.gg/resources/video-audio/sound-sourcing-and-upload
retrieved: 2026-10-15
---
# Sound sourcing and upload

Use online SFX libraries with clear licences. Do not pull audio from the Toolbox or Creator Store: audio owned by another creator usually resolves to silence with no error in your place, and you...

## Contents

- [[#Sources and licences]]
- [[#Prepping files]]
- [[#Uploading under the group]]
- [[#Mapping uploads back to names]]
- [[#"Not approved" and fallback ids]]
- [[#Checklist]]

## Sources and licences

Use online SFX libraries with clear licences. Do **not** pull audio from the Toolbox or Creator Store: audio owned by another creator usually resolves to **silence with no error** in your place, and you can't see the licence anyway.

| Source                                 | Licence                  | Notes                                                                               |
|----------------------------------------|--------------------------|-------------------------------------------------------------------------------------|
| Kenney (kenney.nl audio packs)         | CC0                      | Great UI clicks, impacts, jingles, voiceovers. A good v1 for everything.            |
| Mixkit sound effects                   | Mixkit SFX Free License  | Allows video games, no attribution. You can't redistribute the raw files as a pack. |
| Mixkit **music**                       | Stock Music Free License | **Forbids video games.** Don't use it for music.                                    |
| OpenGameArt                            | Mixed                    | Filter to **CC0 only**; good for loops and composed game music.                     |
| Pixabay                                | Pixabay licence          | Plain downloads hit a bot check (HTTP 403). Don't log in or bypass it; skip it.     |
| Sonniss GDC bundles                    | Royalty-free             | Only as 10–30 GB archives, no per-file download. Fine if a human downloads them.    |
| Free Firearm Sound Library and similar | Check per pack           | Real gunshots beat synthesised ones by a mile.                                      |

Rules:

- **Keep a `CREDITS.md`** next to the source files: per file, the source URL, title and licence. It costs a minute and settles every later question.
- **Check music separately.** Many "free" sites use a different, stricter licence for music than for SFX.
- **Don't commit raw library files** to a public repo if the licence forbids redistribution (Mixkit). Commit the build script and the credits; keep raw files local.
- The AI agent can't listen. It picks files by title and analyses them (onsets, envelope, spectrum). **A human must do a quick listen in Studio** before calling a pass done.

## Prepping files

Normalise every file before upload so the registry `volume` values mean something. Use `tools/prep_sfx.py` (ffmpeg + numpy):

1.  **Trim** leading and trailing silence (a 150 ms gap at the start makes clicks feel laggy).
2.  **Loudness-normalise per group** with a gated RMS. Targets that worked: UI −17 dBFS, SFX −14, Ambience −20, Music −18.
3.  **Peak-limit** at about −1 dBFS (0.89 linear) so layered sounds don't clip.
4.  **One-shots:** 2–3 ms fade-in, 40–80 ms fade-out, to kill clicks.
5.  **Loops:** crossfade the tail into the head for a seamless wrap. Check the loop point by ear; a bump every 6 s is very noticeable in an engine loop.
6.  **Encode Ogg Vorbis** at about q6, 44.1 kHz. Music loops end up 1.5–3 MB each; keep them under ~2 minutes.
7.  **Name the file exactly after the registry key** (`cash_collect.ogg`). The upload's asset name becomes the file name, which is how you map ids back later.

Build the final files from a script, not by hand, so a later "make it punchier" pass is a re-run with a new recipe.

## Uploading under the group

**Upload audio as the group that owns the game, never as a personal account.** Why: audio permissions are per creator. A sound uploaded to the developer's own account can fail to play in the group's experience, or sit as "not approved" for that universe.

- In Studio: **View \> Asset Manager \> Bulk Import**, and first set the upload target (creator) to the group.
- Bulk-import all files at once and keep the file names.
- Moderation takes from seconds to minutes per file. Wait until every one shows under Audio.
- AI agents generally can't upload audio themselves: the Open Cloud route needs an API key with `asset:write`, and Studio-session upload tools in MCP servers usually handle images only. Plan for **the developer to do the bulk import** and paste back the ids.

## Mapping uploads back to names

Two ways that worked:

1.  **Drag into the place:** select all the uploaded audio in Asset Manager and drag it into Workspace. Studio creates one `Sound` per asset, named after the file. A Luau script then walks `game:GetDescendants()`, matches `Sound.Name` to registry keys (ignore case, `.ogg`, spaces, ` (1)` suffixes), and prints `{name: id}` JSON. Delete the dragged Sounds afterwards.
2.  **Paste the id list:** the developer pastes the ids; the script calls `MarketplaceService:GetProductInfo(id, Enum.InfoType.Asset)` and maps `.Name` to the registry key.

Then a small script writes the ids into the registry file. Never hand-edit 50 ids.

## "Not approved" and fallback ids

A newly uploaded sound can log `sound <id> not approved` in output and play as silence. It happened to the default home ambience: home was silent for every player, and every session logged an error.

- **Keep the last working id** in a comment, or as `fallback = "..."` in the entry. When a v2 upload fails, point the entry back at v1 until the v2 is re-uploaded under the group.
- **Verify ids load before shipping:** `ContentProvider:PreloadAsync({sound})`, then check `sound.IsLoaded and sound.TimeLength > 0`. Do it for every id in the registry from a script, and list failures.
- Engine built-ins under `rbxasset://sounds/` are a safe fallback for a few cues (`electronicpingshort.wav`, `switch.wav`, `button.wav`, `clickfast.wav`, `snap.wav`, `hit.wav`, `victory.wav`, `collide.wav`, `splat.wav`). Not all of them exist on every build (`pop_mid.wav` and `swoosh.wav` failed), so probe them too.
- Audio reused from another of **your own** games usually loads, but re-probe before relying on it.

## Checklist

- Every source file has a URL and a licence in CREDITS.md; no Toolbox audio.
- No music from a source whose music licence forbids games.
- Files trimmed, loudness-normalised per group, limited, faded or loop-wrapped, named after their registry key.
- Uploaded with the **group** as the creator.
- Ids mapped by script, not by hand.
- Every id preloads with `IsLoaded` and `TimeLength > 0`; any "not approved" id has a fallback.
- A human listened to the new pass in Studio.

Previous: [[The sound registry]] · Next: [[Music and ambience]]
