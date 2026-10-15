---
tags: [research, roclicks]
source: https://roclicks.gg/resources/workflow/top-lessons
retrieved: 2026-10-15
---
# The 12 lessons that mattered most

Hard-won, game-agnostic lessons for building Roblox games with AI coding agents. It covers thumbnails, 3D building, UI, sound and VFX, game design, and engineering.

Hard-won, game-agnostic lessons for building Roblox games with AI coding agents. It covers thumbnails, 3D building, UI, sound and VFX, game design, and engineering.

Everything here came out of real projects: a kids' strategy tycoon (the main source), plus idle, RNG, RPG, parkour and obby prototypes. Each rule names the bug or player problem it prevents. Specific games appear only as short worked examples.

## Sections

| Folder                                                              | Start with                                                     | What's inside                                                                                                                                                            |
|---------------------------------------------------------------------|----------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [[Game design overview|`game-design/`]]                   | [[Design checklist|design-checklist.md]] | Kid-friendly onboarding, the first-10-minutes audit, progression and pacing, combat feel, ethical monetization and Roblox compliance, analytics funnels, review process  |
| [[Engineering overview|`engineering/`]]                     | [[Engineering overview|README]]                        | Studio via MCP, multi-agent etiquette, safe saves (session locks, BindToClose), solo-in-a-shared-server isolation, performance, input, Open Cloud, push/diff/check tools |
| [[UI overview|`ui/`]]                                     | [[Checklists|checklists.md]]                      | HTML-first UI pipeline, style rules, measured GUI and input facts, reusable patterns (next-goal pill, upgrade preview, crate reel, loading screen), verifying UI         |
| [[Building overview|`building/`]]                         | [[Building overview|README]]                         | Stud-style worlds, meshes vs parts, EditableMesh, z-fighting, chunked maps, per-level upgrade visuals, placement and picking, verifying maps                             |
| [[Sound and VFX overview|`sound-vfx/`]]                             | [[Sound and VFX checklist|CHECKLIST.md]]                       | Sourcing and uploading audio, a sound registry, music and ambience, particle VFX, pooling and budgets, feedback "juice"                                                  |
| [[What makes a Roblox thumbnail click|`thumbnails/`]] | [[What makes a Roblox thumbnail click|README]]   | What makes a thumbnail click, the public thumbnail prompt, 30 idea patterns, the Google Flow and Meshy pipelines, picker and contact-sheet tools                         |

## The 12 lessons that mattered most

1.  **Never let a Robux prompt open by itself.** Hide paid surfaces until the tutorial is done. Show a "Delivering…" state so nobody pays twice. (`game-design/monetization-and-compliance.md`)
2.  **Saves need a session lock and a BindToClose that waits.** A transient 502 is not "Studio mode". (`engineering/data-and-saves.md`)
3.  **`input.Position` is GUI space.** Use `ScreenPointToRay`, or every pick is 58 px off. (`building/04-building-ux.md`, `ui/gui-input-facts.md`)
4.  **The tutorial is the core loop only.** About 6 do-it steps, ≤8 words each, server-enforced, can't soft-lock, and the first fight can't be lost. (`game-design/onboarding.md`)
5.  **Simulate progression across hundreds of seeds.** It finds walls that no playtest hits. (`game-design/progression-and-pacing.md`)
6.  **Studio is the source of truth when someone edits live.** Pull byte-exact and push through an all-or-nothing base-compare. Never use `set_script_source`. (`engineering/studio-mcp.md`)
7.  **One owner per file when several agents work at once.** Use workspace-attribute locks for playtests and the camera. (`engineering/multi-agent.md`)
8.  **Less on screen for kids.** Cash plus one "Next goal" that names the exact blocker. Reveal the rest progressively. (`ui/style-rules.md`, `ui/patterns.md`)
9.  **Update UI in place.** Rebuilding panels on a timer loses taps. Use one number formatter with a regression test. (`ui/verifying-ui.md`)
10. **Effects are layered particles, never part clusters.** Pool them with a generation counter. (`sound-vfx/`)
11. **Every upgrade must be visible**, walls included, within a part budget. (`building/03-progress-visuals.md`)
12. **Upload audio and assets under the group that owns the game**, and probe every id. Missing permissions render as silence or nothing. (`sound-vfx/sound-sourcing-and-upload.md`, `building/01-stud-style-and-materials.md`)

## Using this with an AI agent

Point the agent at the relevant folder before a task. For example: "read `engineering/multi-agent.md` and `engineering/fix-brief-template.md`, then…". The checklists use `- [ ]`, so you can paste them into a task. Tools are plain Python 3 and Luau with no game-specific paths.

## Notes

- No third-party assets are included (icon packs, toolbox models, reference images). The docs describe where to get them and their licence traps.
- Roblox policies change. Pages about monetization and compliance say "check current policy" where it matters.

Next: [[The order to build a Roblox game in]]
