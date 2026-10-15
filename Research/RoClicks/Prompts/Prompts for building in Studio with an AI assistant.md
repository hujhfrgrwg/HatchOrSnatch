---
tags: [research, roclicks]
source: https://roclicks.gg/resources/ai-prompts/ai-build-prompts
retrieved: 2026-10-15
---
# Prompts for building in Studio with an AI assistant

Copy-paste briefs for stud-style maps, detail props, game UI and VFX, written so the assistant checks its own work.

Copy the prompt with the button on its box, then paste it into your AI.

These assume an AI assistant connected to Roblox Studio (through an MCP server) that can run Luau, insert parts and take screenshots. Each brief tells it what to build, the rules of the style, and how to prove it's done.

## A stud-style map

``` text
Build a [THEME] map in stud style in Roblox Studio. Size: about [X by Z] studs. Zones: [LIST THE ZONES AND WHAT HAPPENS IN EACH].

Block it out FIRST: one plain placeholder part per zone, building footprint, hill, water body, path and spawn, each named for what it becomes. Screenshot the blockout from above, tell me what each block is, and STOP so I can adjust it in Studio. Only build the real thing after I say go.

Style rules for the real build:
- Plastic with the place's stud MaterialVariants (check MaterialService first and only use variants that exist; fall back to stud SurfaceTypes on all six faces).
- Pattern by role: structure gets one pattern, big fills another, rocks studs on top only, parts under 0.5 studs plain smooth plastic.
- Chunky, not blocky: whole-stud massing, 0.5 to 1 stud frames and trim, 0.1 to 0.4 stud fine detail. Break up any wall longer than 8 to 12 studs.
- Real altitude: a raised plateau, corner hills that look grown from the ground, a sunken area. Never one flat plane.
- No gaps anywhere. Close seams by overlapping parts, never by insetting them. No faces exactly coplanar on any axis (offset by 0.01).
- Neon only as a small accent. No random spheres.

Before showing me: apply the full lighting, take at least 12 screenshots from player height covering every zone plus 2 aerials, list every defect you see, fix them, and re-shoot the same angles.
```

## A detail prop

``` text
Build a [PROP] for a stud-style Roblox game, about [SIZE] studs. Reference: [ATTACH OR DESCRIBE].
Most of it is plain studded Parts. Put modelled detail (EditableMesh) on only 2 or 3 focal pieces, such as [A GEAR RING / A BEZEL / A WHEEL RIM]: small 0.2 to 0.4 stud chamfers, mouldings, recessed panels, bolts. Keep the silhouette crisp and chunky, not rounded off.
Make it read as a real machine: bolts, pipes with flanges, gears, gauges, hatches, vents, at most two small plastic indicator lamps. No neon strips, no decorative orbs.
EditableMesh isn't saved with the place, so leave a marker part where each mesh goes and bake the mesh on at runtime.
Screenshot it from the front, side and three-quarter views at player height and tell me what you'd improve before I look.
```

## Game UI, HTML first

``` text
Design the [SCREEN NAME] for my Roblox game in HTML/CSS first. Do NOT build it in Studio yet.
Style reference: [ATTACH IMAGE]. Before designing, read the reference into tokens (palette, panel shape, outline thickness, texture, font, button style, icon treatment) and show me those tokens.
- Fixed 1920x1080 stage, absolute pixels.
- Chrome (plates, panels) has empty interiors and no baked text. Every word is live text with a thick dark outline. Icons only from [MY ICON PACK], never emojis.
- Phone-readable: body text at least 26 design px, titles 40+, tap targets at least 124 design px.
- Show every state on one sheet: normal, hover, pressed, locked, unaffordable, empty, full, longest text, phone layout.
When I approve it, convert it to a real ScreenGui (TextSize = CSS font-size x 1.215), then verify with a property sweep: every visible label has TextFits, no siblings overlap, nothing escapes its parent, every image is loaded.
```

## A VFX effect

``` text
Make a [EFFECT, e.g. "fire punch impact"] VFX for my Roblox game, about [RADIUS] studs across, in a [STYLE] style with [MAIN COLOUR] as the main colour.
Build it ONLY from ParticleEmitters, Beams and Trails with textures. Never from 3D parts or sphere clusters.
- Store it as a template Model in ReplicatedStorage.VFX, emitters disabled, fired by EmitCount and EmitDelay attributes (delays counted from the effect's start).
- Layers: a short anticipation, a 1 to 2 frame flash, impact stars with a black twin behind them, streaks, a growing ring, smoke that outlives the flash, a few embers, and a PointLight that fades.
- Intensity only goes down after the flash, but the body (smoke, crescents) keeps growing for a fraction of a second, so it reads as an explosion, not a pop.
- Play it on clients from an UnreliableRemoteEvent carrying the effect name and a CFrame. Time it to the animation's "Impact" marker.
Capture it frame by frame from the player's camera and show me the key frames.
```

## A rule for every brief

End any long brief with the guardrails:

``` text
Don't start a playtest; verify in edit mode and give me a checklist to playtest myself. Don't upload or publish anything, and ask before spending any credits.
```

Previous: [[Prompts for AI 3D models]] · Next: [[Prompts for studying and planning a game]]
