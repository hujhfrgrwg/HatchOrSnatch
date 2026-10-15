---
tags: [research, roclicks]
source: https://roclicks.gg/resources/building/verifying-maps
retrieved: 2026-10-15
---
# Verifying maps and models

A map presented after four aerial shots, taken with only part of the lighting applied, came back as "still not good, double check your work with screenshots".

- [[#The screenshot survey]]
- [[#Photo booth for single models]]
- [[#Controlling the edit camera]]
- [[#Studio capture quirks]]
- [[#The 15 fps trap]]
- [[#Checks that are numbers, not pictures]]
- [[#Sharing one Studio between agents]]
- [[#Checklist]]

## The screenshot survey

A map presented after four aerial shots, taken with only part of the lighting applied, came back as "still not good, double check your work with screenshots". Aerials hide what players see at eye level: empty lanes, blocky props, parts clipping into each other, flat lighting.

For every map and every big 3D build:

1.  **Apply the full in-game lighting** first: Atmosphere, Bloom, ColorCorrection, SunRays, sky, time of day. Exactly what the game's map service applies at runtime.
2.  **Take 12+ player-height shots** covering every zone, plus 2 aerials.
3.  **Write down every defect.** Then fix them all.
4.  **Re-shoot the same angles** and compare.
5.  Only then show it to the developer, and describe what the shots show (the capture tools return images to the agent, not to the developer).

Also check:

- **Sun direction vs the main view.** A sun facing the player put every cliff face toward spawn in shadow and it read purple. Compare `Lighting:GetSunDirection()` with the main camera direction before judging colours.
- **Development GUIs** in StarterGui can cover edit-mode captures. Toggle `StarterGui.ShowDevelopmentGui` off for the shots and restore it.
- **Never grab the whole screen** with an OS screenshot to "see Studio". Studio is often not in front, and you capture the developer's private windows instead.
- For obbies, run a clearance scan: a box above every walkable surface must be empty, or corners of caps and canopies bump heads. Thin decorative plates on a walk surface catch feet and stop `Touched` firing on the part underneath; make them `CanCollide = false`.

## Photo booth for single models

For props and buildings, a "photo booth" catches what a scene hides:

- Build the model alone on a grid floor far from everything else.
- Shoot 8 orbit angles + top + a low close-up (about 10 shots per model).
- Know which way is front (for example, front = -Z, so +X shows screen-left).
- Batch ~5 models per reviewer pass. Run batches **sequentially**: there is one Studio camera.
- Delete the booth afterwards.

Common defects it caught:

- Details placed inside a solid box (invisible; make shells or hollows).
- Coplanar caps z-fighting.
- Pieces hovering 0.05-0.4 studs above their support.
- Pivots not on the floor, so the model sinks or floats when placed.

## Controlling the edit camera

**Set `Camera.Focus` as well as `Camera.CFrame`.** After `cam.CFrame = CFrame.lookAt(pos, target)` from a script, half a second later the camera kept `pos` but its rotation snapped back. The capture showed a different area and looked like a stale or wrong-window capture.

``` lua
local cam = workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Scriptable -- some builds ignore or flip CFrame otherwise
cam.CFrame = CFrame.lookAt(pos, target)
cam.Focus = CFrame.new(target)
task.wait(0.4) -- let it settle, then capture in the NEXT tool call

-- prove the shot is yours: what does the screen centre hit?
local vp = cam.ViewportSize
local ray = cam:ViewportPointToRay(vp.X / 2, vp.Y / 2)
local hit = workspace:Raycast(ray.Origin, ray.Direction * 5000)
print(hit and hit.Instance:GetFullName() or "nothing")
```

- Checking `cam.CFrame.Position` alone isn't enough: the position was right, the rotation wrong.
- Aiming at a model by hand keeps missing. A "frame the selection" tool action on the model is more reliable.
- Save and restore the developer's camera around your shots; don't leave it moved.

## Studio capture quirks

| Quirk                                                                                                                                                                      | What to do                                                                                                                                                         |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Tool calls issued in one response are not ordered.** A camera move and a capture raced and the capture came from the old camera. Destroy-then-import raced the same way. | Put camera moves and captures in separate turns, or do both in one `execute_luau`. Stage imports in ServerStorage and move them in the same script that uses them. |
| Capture returns a **2x retina image**; its pixel coordinates are not click coordinates.                                                                                    | Halve them, or read element positions from the engine.                                                                                                             |
| **BillboardGuis are never drawn** in captures (edit or play, even AlwaysOnTop).                                                                                            | Verify billboards by property sweep: Enabled, Adornee, Size, MaxDistance.                                                                                          |
| Some builds return **solid magenta** during a playtest; others draw ScreenGuis fine.                                                                                       | Try once. If magenta, verify GUIs by property sweep instead of retrying.                                                                                           |
| An edit-mode capture can return a **stale frame**.                                                                                                                         | Take the shot in a playtest, or move the camera and re-shoot.                                                                                                      |
| Particles **freeze** in edit mode; `PreSimulation` / `Stepped` don't fire in edit mode (Heartbeat does).                                                                   | Judge effects in a playtest; drive edit-mode animation from Heartbeat.                                                                                             |
| "Window minimized or not rendering" mid-session.                                                                                                                           | It may be the developer's window. Don't retry in a loop; ask.                                                                                                      |

**Edit-mode preview is the QA loop.** Screenshots work in edit mode, so `require` the builder from `execute_luau`, build into a preview folder, shoot, sweep, and destroy the preview before any playtest. Mark runtime-only previews `Archivable = false` so nothing gets saved by accident. Sound or effect modules run in edit mode can leave folders in services that get saved into the place (one left 88 sounds, 3 playing, that every client then heard): have runtime modules replace any folder they didn't create this session.

## The 15 fps trap

**An unfocused Studio window caps rendering at exactly 15 fps.** Disabling 672 sprites changed nothing: the number was 15.0 dead on, while server and client heartbeats were both 60/s.

- Before chasing a rendering "perf problem", check whether the number is suspiciously round.
- Don't A/B fps in an unfocused Studio. Both sides will read 15.
- Compare part counts, job queue lengths and ms-per-job instead; those don't depend on focus.
- For real fps numbers, the window must be focused, and say so in the report.

## Checks that are numbers, not pictures

Screenshots are for judgement. These prove things:

- Part counts per template, per chunk, per scene.
- Coplanar-face sweep count (should be 0 visible pairs).
- Floating-part scan: parts whose bottom isn't touching anything below within 0.05 studs.
- Ray hit at screen centre (proves the camera is where you think).
- Picking error in pixels across a grid of screen points.
- "Hidden" counts after LOD churn (for example, chunks with ground `Transparency = 1`: should be 0).
- `TextFits`, overlap and `IsLoaded` sweeps for any GUI in the shot.

## Sharing one Studio between agents

When several agents (or an agent and the developer) use one Studio:

- Use a lock attribute on Workspace for the camera (`CamLock` = owner, `CamLockT` = time). Refresh the time before every capture; a lock older than ~30 s may be taken by someone else.
- Never batch a capture with a lock attempt that might fail.
- Keep each `execute_luau` under ~15-20 s; long calls time out. Wait in the background, not in a Studio loop.
- If real input appears (right mouse, WASD) in your playtest, the developer is playing in it. Stop driving the client.

## Checklist

- Full lighting applied, 12+ eye-level shots + 2 aerials, defects listed, fixed, re-shot.
- Camera moved with CFrame + Focus, verified with a centre raycast.
- Captures in a separate turn from camera moves.
- Billboards checked by property, not by picture.
- No fps conclusions from an unfocused Studio.
- Preview folders destroyed; nothing runtime-only saved into the place.

Previous: [[Building UX placing, picking and selecting]] · Next: [[Tools pushing, pulling and checking code]]
