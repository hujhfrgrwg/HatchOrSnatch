---
tags: [research, roclicks, hub]
updated: 2026-10-15
source: https://roclicks.gg
retrieved: 2026-10-15
---
# RoClicks Index

[RoClicks](https://roclicks.gg) is a free Roblox-dev site of guides written for AI agents driving Studio. Every rule on it says which bug it came from. All 108 guide pages were saved here on 2026-10-15 (copied from the Faceoff repo).

> [!warning] Their art style is a default, not a rule
> RoClicks is written for **stud-style simulators** (bright plastic, stud textures, pastel palettes, no MeshParts). Take their *process*, *engine facts* and *checks* always. Take their *look* only if Hatch or Snatch's own style guide says so; once it has one, it wins over every stud, palette and "no MeshParts" rule here.

## Folders
| Folder | Hub | What's in it |
|---|---|---|
| Building | [[RoClicks Building]] | Map and model building with an agent: scale, verification, seams, push/pull tools |
| Tricks | [[RoClicks Tricks]] | Lune, map remakes from video, 12-screenshot check, getting scripts/images into Studio |
| UI | [[RoClicks UI]] | HTML-first UI pipeline, measured GUI/input facts, verification, HUD/feedback patterns |
| VFX | [[RoClicks VFX]] | Impact anatomy, particles, beams/trails, pooling and budgets, colour/value |
| Animation | [[RoClicks Animation]] | Hitstop and impact frames, procedural R6, rigging |
| Scripting | [[RoClicks Engineering]] | Studio MCP, many agents on one Studio, Luau traps, saves, input, performance, Open Cloud |
| Game Design | [[RoClicks Game design]] | First-10-minutes audit, onboarding, progression, combat feel, monetization compliance, analytics |
| Thumbnails | [[RoClicks Thumbnails]] | What makes a thumbnail click, idea patterns, image-model prompting, review checklist |
| Video and Audio | [[RoClicks Sound & video]] | Sound registry and uploads, music loops, Roblox-legal trailers |
| Workflow | [[RoClicks Workflow]] | Build order, the 12 lessons that mattered most, launch week |
| Prompts | [[RoClicks Prompts]] | 10 copy-paste prompts: thumbnails, HTML UI + import, Studio builds, 3D models, planning, music |
| Skills | [[RoClicks Skills]] | What each of their six Claude skills does |
| (root) | [[RoClicks Assets]], [[RoClicks Snippets and Tools]] | Asset libraries (VFX texture pack, UI Resources, Poly Haven) and the code index |

## Map building: the philosophy worth keeping
From [[Building overview]], [[Verifying maps and models]], [[Check a build with 12 screenshots before showing anyone]], [[Remake a map 11 from a gameplay video]] and [[No gaps seams, openings and transparent parts]]:

1. **Build scripts, not hand edits.** The agent writes Luau builder modules, pushes them as model files and runs them. A build you can re-run is a build you can fix.
2. **Blockout, then stop.** Lay one named placeholder per zone, screenshot it, and let Hunter move things before any detail.
3. **Survey before you build.** Read real positions from the place; guessed coordinates are banned. Re-survey after any manual edit.
4. **Preview in edit mode,** then delete the preview before playtesting.
5. **Measure, don't eyeball.** Screenshots are for judgement; numbers are proof: part counts, coplanar-face sweep = 0, floating-part scan, ray hit at screen centre.
6. **12+ player-height screenshots under the full game lighting** plus 2 aerials, list every defect, fix, re-shoot the same angles. Aerials hide what players see.
7. **No coplanar faces, no gaps.** Close seams by overlapping parts (never by leaving a gap), and offset by 0.001 so faces never share a plane.
8. **Remakes: the reference is the spec.** Pull stills, use the ~5-stud avatar as a ruler, sample median colours, compare each landmark side by side, ask about anything unseen.
9. **Never find map content by one fixed parent,** and never `WaitForChild` a map container without a timeout ([[Scale and maps]]).
10. **An unfocused Studio renders at exactly 15 fps.** Don't benchmark fps in it.

## Lune: what it really does
[[Build your game outside Studio with Lune]]. Lune runs Luau outside Studio and reads/writes `.rbxl`/`.rbxm`. Three uses:
- **Build the place or a map from code.** One Lune script assembles scripts and runs map-builder code, so the saved place opens with the world built. Needs fakes for services Lune lacks.
- **Test pure logic without Studio.** Economy, pacing and odds (hatch rates, for example) run in milliseconds.
- **Model meshes in a loop the agent can see.** Model code writes `.obj`, Blender renders it headless, the agent looks at the PNG and fixes it.

HTML is the **UI** pipeline, not part of Lune: design screens in HTML/CSS, then convert to a ScreenGui ([[HTML-first UI pipeline]], [[The HTML UI prompt recreate a UI from a screenshot]], [[The UI import prompt HTML to a Roblox ScreenGui]]). Caveat from the page: `CFrame.lookAt` is wrong in Lune 0.10.5.

## By task
- **Pushing scripts:** [[Get scripts and images into Studio fast]] (use `.rbxmx` + import, never `set_script_source` for big scripts), [[Tools pushing, pulling and checking code]].
- **UI:** [[Measured GUI and input facts]] (TextSize = CSS × 1.215, the 58 px inset), [[Verifying UI]], [[Checklists]].
- **VFX:** [[Anatomy of an impact]], [[FX controller, pooling and budgets]], [[Colour, value and brightness in effects]].
- **Combat feel:** [[Combat feel]], [[Hits that feel heavy hitstop, impact frames and shake]].
- **MCP and agents:** [[Driving Roblox Studio through MCP]], [[Many agents, one Studio]], [[Luau traps that broke real games]].
- **Launch and growth:** [[What makes a Roblox thumbnail click]], [[Roblox-legal gameplay trailers]], [[Launch and the first week]], [[Monetization and compliance]].

## Code and skills
- **53 code files** (snippets and tools, e.g. `ZFightSweep.luau`, `stage_rbxmx.py`, `rbxm_src.py`, `PropertySweep.luau`) in `Research/RoClicks/Code/`, same folders as the site. Index: [[RoClicks Snippets and Tools]].
- **Skills in `.claude/skills/`** (load automatically in every session):

| Skill | From | Needs installed first |
|---|---|---|
| roblox-game-pipeline, roblox-ui-maker, roblox-vfx, studify, roblox-trailer, roblox-game-score | RoClicks | Python 3 + PIL/numpy, Node 22, Chrome (UI maker); ffmpeg (trailer); ACE-Step (score) |
| agent-browser | [vercel-labs/agent-browser](https://github.com/vercel-labs/agent-browser) (Apache-2.0) | `npm i -g agent-browser && agent-browser install` |
| scrapling | [D4Vinci/Scrapling](https://github.com/D4Vinci/Scrapling) (BSD-3) | `pip install "scrapling[all]>=0.4.15"` then `scrapling install` |
| jest-lua | Built from the [Roblox/jest-roblox](https://github.com/Roblox/jest-roblox) docs (MIT) | Wally `roblox/jest` dev dependency in the place |
| claude-music + 11 sub-skills | [AgriciDaniel/claude-music](https://github.com/AgriciDaniel/claude-music) (MIT) | its `install.sh` / `install.ps1` (ACE-Step, local GPU) |
| graphify | [safishamsi/graphify](https://github.com/safishamsi/graphify) (Apache-2.0) | `uv tool install graphifyy` |
| humanizer | [blader/humanizer](https://github.com/blader/humanizer) (MIT) | nothing |

Not in Git: the **VFX texture pack** (1,936 textures, about 458 MB, links in [[RoClicks Assets]]). Download it on the PC instead.
