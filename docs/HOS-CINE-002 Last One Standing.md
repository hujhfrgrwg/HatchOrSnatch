---
tags: [cinematic, ui]
updated: 2026-10-17
ticket: HOS-CINE-002
---
# HOS-CINE-002 Last One Standing

When a crossing is about to start with **one Runner left**, every player in the match gets a 3.4 s cut-scene in the break before it (that break is 1.6 s longer, only then). It plays **once per match**: if the lone Runner keeps crossing, later solo crossings only show the top pill. Look and motion approved by Hunter on 2026-10-17 ("looks good upload", review page v3).

**Status:** in the place, not saved or published. Off switch: `GameConfig.Cinematic.LAST_STANDING_ENABLED = false` (the old "LAST ONE STANDING!" banner comes back).

Review page with both videos, before/after and every still: https://claude.ai/artifact/6D5JTtLnp7f2oLtePaKm65 (private to Hunter). Files: `docs/last-one-standing/ui/`.

## How it plays
| Time | Shot (Controllers/LastStanding `shotsFor`) | Card (template) |
|---|---|---|
| 0.0–1.2 s | Slow push-in on the Runner from the front, a little low, the Runner on the left third (12 → 8.5 studs, FOV 66 → 57). Gold beam + ground ring on the Runner. | `LS_Name`: the name in the hero gold (like RUNNERS WIN!) over rays, slams 2.4 → 1; the gold banner with the crown wipes in: LAST ONE STANDING. Low impact sound. |
| 1.2–2.2 s | Cut through a 0.2 s black dip. Wide and low on the Catcher wall, a slow 2-stud pan, FOV 70. | `LS_Vs`: red tilted VS over rays (a scale bounce, no flash, no shake), the red banner "21 CATCHERS" wipes in under the Catchers' feet. |
| 2.2–3.1 s | Cut through black. Behind the Runner, creeping in (10 → 9 studs), the Runner on the left third, the Catchers ahead. | `LS_FaceOff`: FACE OFF! banner drops in; the role line rises under it on a glass plate with the role's icon. |
| 3.1–3.4 s | Bars out, camera back (Custom on your Humanoid), aimed at the finish (Catchers: at the Runner). | Card fades. |

Role lines: lone Runner "It's all on you. Make it across to win it for the Runners."; Catchers "Catch &lt;name&gt; to win it for the Catchers."; anyone else "&lt;name&gt; crosses alone. Can they make it?".

During the solo crossing every match player sees `LS_Pill` under the match Status: "LAST ONE STANDING · &lt;name&gt;" (first solo crossing) or "LAST ONE STANDING · CROSSING n" (later ones). The tension music is UIController's (RunnersLeft ≤ 2), unchanged.

**Reduce effects:** no camera, bars or dim; `LS_Compact` (name, banner, role line) under the match Status, fading after ~2.5 s.

## Comfort rules (all cut-scenes, Hero or Chicken included)
`Controllers/Cinematic` clamps every shot of every spec (Hunter: "too zoomed in... a bit of motion sickness", then "you can do zoom ins... but be gentler"): FOV 50–70 at ≤ 12°/s (eased, never widening fast); never closer than 6 studs to a character in view; ≤ 5 studs/s and ≤ 25°/s within a shot; a cut between shots goes through a 0.2 s letterbox-black dip; `blendIn` swings are ignored. Each clamp warns once per spec ("[Cinematic] comfort: ..."). Values in the `COMFORT` table at the top of Cinematic; `GameConfig.Cinematic.COMFORT` can override any field.

The bars' ScreenGui (`EOS_Cinematic`) uses `ScreenInsets = None`, so bars, dip and vignette reach the screen edges under a phone notch (fixed 17 Oct after the phone playtest; before/after stills `HOS-CINE-002_notch_before/after.jpg` on the review page). The cards' `LastStandingUI` stays on `DeviceSafeInsets` so text clears the notch.

Cinematic also: hides every PlayerGui ScreenGui except TouchGui (thumbstick) and kept GUIs, overhead name tags (BillboardGuis in PlayerGui, on characters and NPC bodies, Humanoid names) and the mouse-lock centre dot, all restored after. The camera always comes back on: the end, a hard 4 s cap, respawn, any error, and the moment the Phase becomes CROSSING.

## What is where
| Piece | Path |
|---|---|
| Server | `ServerScriptService.EOS.Services.LastStandingService` (`moment(c, nextFinish)`): fires the `LastStanding` remote to real match players, extends PhaseEndsAt, once per match (`c.lastStandingShownAt`), sets state `LastStandingFirstWave` |
| Hook | `MatchService` WAVE_END, after `lineUp`: one line, `local extra = require(script.Parent.LastStandingService).moment(c, nextFinish)` (+ `extra` in that waitPhase) |
| Client | `StarterPlayerScripts.EOS.Controllers.LastStanding` (shots, cards, VFX, pill); `Controllers.Cinematic` (shared: bars, dim, HUD hide, camera, comfort); one line in `ClientMain` |
| UI | `StarterGui.LastStandingUI` (Root + FitScale + UIKit + AssetIds), `ReplicatedStorage.LastStandingTemplates` (LS_Name, LS_Vs, LS_FaceOff, LS_Compact, LS_Pill), `ServerStorage.LastStandingUIBuild` (Builder) |
| UI source | `UI/build.py` section "HOS-CINE-002" (pages `last_standing.html` exported, `last_standing_states.html` review, `last_standing_play*.html` animated); export config `ui_laststanding/rbx.json`; generated Luau `UI/roblox/ui_laststanding/` |
| Art | 10 images in group 228184582 (4 banners as outline + fill, 2 rays): `Assets/UI/laststanding/`, decal ids in `Assets/asset_ids.json`, image ids in `ui_laststanding/rbx/out/uploaded.json`. Icons reuse EOSUI's crown, runner, catcher, spectate. |
| Config | `GameConfig.Cinematic` (LAST_STANDING_ENABLED, LAST_STANDING_EXTRA 1.6, MAX_SECONDS 4, BAR_HEIGHT, BAR_TIME); `Net.TO_CLIENT` "LastStanding"; `Sound` "impact" (Pro Sound Effects "Boom Impact Deep Distant Thumping Hits Booming 1", 9125402735) |

## Runtime changes to the imported templates (Controllers/LastStanding)
- Every card is wrapped in a CanvasGroup so it fades as a whole.
- Names, the role plate and the pill re-fit around their real text (TextService); long names shrink to the column (900 design px on the name card, 1000 on the compact card).
- Role icon swapped per role (runner / catcher / spectate).
- `LS_Vs.VsTextBig.Rotation = -7` (the HTML tilt; the exporter drops a transform on an inline span).
- Banner wipes use a clipping holder frame created at runtime (no look of its own).
- `LastStandingUI`: Enabled, DisplayOrder 55 (above the bars at 50); Root fitted like the kit (`FitScale = min(w/1920, h/1080)`); the pill is lifted to the screen top on screens taller than 16:9.
- Not ported from the HTML preview: the shine sweep over the banners (it would be a look built in code; add it to the templates if wanted).

## Checks
- HTML: `?check` on `last_standing.html` and `last_standing_states.html`: no overflow, no broken images. Text ≥ 11 px on screen at 844×390 and iPhone SE 667×375.
- Studio: fit pass ×3 (worst 3.4 %, integer TextSize rounding); 22 images, 0 empty; PropertySweep at 1920×1080, 1366×768, 844×390: only CLIPPED on the rays (clipped between the bars on purpose) and the drop-shadow crescents (by design); no TEXT_NOFIT, no small text, no taps.
- Playtest: see below.

## Notes for the next person
- Build UI pages with `python -X utf8 build.py` on Windows (otherwise "·" becomes a broken glyph in every page). gen/bundle the same (`PYTHONUTF8=1`).
- The skill's `export.mjs` / `mockshot.mjs` use `new URL(import.meta.url).pathname`, which breaks on Windows (`C:\C:\...`); run a copy with `fileURLToPath`.
- The robloxstudio MCP's own `upload_asset` key is invalid/expired; `tools/upload/upload_assets.py` with `ROBLOX_OPEN_CLOUD_API_KEY` (as `HOS_ROBLOX_API_KEY`) and group 228184582 works.
- Real backgrounds for UI reviews: pose rigs in a non-archivable folder, set `workspace.CurrentCamera` (and `Focus`) to the shot, `capture_screenshot`, centre-crop to 16:9 (the Studio viewport's aspect follows its panels). Check that no playtest is running before and after every frame.
- Backups: `docs/backups/HOS-CINE-002_2026-10-17/`.

## Playtest
2026-10-17 08:05–08:06Z, self-closing 2-player test (PLAYTEST claimed, nothing else running): client 1 PC (Player1, forced to be the lone Runner), client 2 iPhone 14 landscape simulator (Catcher), 21 Catchers incl. NPCs.
- Server: `LastStandingShown -1@2` (once, wave 2); the WAVE_END break was 1.6 s longer; later solo crossings did not replay the moment.
- Both clients: name close-up → VS "21 CATCHERS" → FACE OFF! with the right role line ("It's all on you…" on PC, "Catch Player1 to win it for the Catchers." on the phone); camera back on the Humanoid, HUD and name tags back.
- During the crossing: the pill "LAST ONE STANDING · Player1" under the Status on both.
- All test windows closed after (checked by process).
- Clips (9 s, 1280×716, H.264): `docs/last-one-standing/playtest/last_standing_ingame_pc_runner.mp4`, `last_standing_ingame_phone_catcher.mp4`; stills `still_1_name.jpg` … `still_5_phone_catcher_faceoff.jpg`.

**Builder.fit bug, hand-fixed:** `Builder.fit` shrinks labels inside a "…Big" frame by the frame's UIScale. The big labels were set by hand after fitting (measured against the HTML: VS 388 px in game vs 389 in HTML): `LS_Name` name 92, `LS_Vs` VS 99, `LS_FaceOff` FACE OFF 93, `LS_Compact` name 93 (TextSize, both twins). **Re-run this correction (fit TextSize × the Big frame's scale) after any Builder rebuild.**
