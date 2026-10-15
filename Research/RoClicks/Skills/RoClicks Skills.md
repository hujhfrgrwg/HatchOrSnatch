---
tags: [research, roclicks]
source: https://roclicks.gg/skills
retrieved: 2026-10-15
---
# The AI skills behind the games.

Skills

A skill is a folder of instructions, scripts and templates that teaches an AI coding agent how to do one job well. These are the ones used to make Roblox games with Claude Code, cleaned up so they work in anyone's project. The guides on this site are the human-readable version of the same rules. [See what they make](https://roclicks.gg/showcase).

## Installing one

Download the zip and unzip it into your skills folder, so the skill sits at `~/.claude/skills/<name>/SKILL.md` (or `.claude/skills/` inside one project). Claude Code picks it up in the next session and uses it when a task matches.

    unzip roblox-vfx.zip -d ~/.claude/skills/

## Made for Roblox

- Idea to launch

  ### [[RoClicks Roblox game pipeline|Roblox game pipeline]]

  The conductor: takes a game from idea to launch in phases (concept, economy sim, world, models, systems, UI, VFX, audio, QA, launch, live updates). Each phase names the skill to use, what it must produce and the gate you approve. Ships with measured Studio gotchas, standing rules, parallel agent prompts and a GAME.md tracker.

  [Download16 KB](https://roclicks.gg/skills/roblox-game-pipeline.zip)[[RoClicks Roblox game pipeline|Read it]]

- UI

  ### [[RoClicks Roblox UI maker|Roblox UI maker]]

  Designs game UI in HTML first, from your style reference (stud style by default), with every state and a phone layout. Once you approve the mockups it exports them, uploads the art and builds a real ScreenGui with ready-made Luau modules (buttons, toasts, shops, crate reels, number formatting), then checks it with a mock render and property sweeps.

  [Download165 KB](https://roclicks.gg/skills/roblox-ui-maker.zip)[[RoClicks Roblox UI maker|Read it]]

- VFX

  ### [[RoClicks Roblox VFX|Roblox VFX]]

  Builds hits, slashes, explosions, projectiles, auras and camera shake from layered ParticleEmitters with custom textures and flipbooks. Includes an attribute-driven emit module, EditableMesh shapes (crescents, shockwaves, swirls) and a capture tool that freezes an effect at chosen moments so you can check it frame by frame.

  Built on [Roqer's roblox-animation-vfx skill](https://github.com/S4US/Roqer) (MIT).

  [Download84 KB](https://roclicks.gg/skills/roblox-vfx.zip)[[RoClicks Roblox VFX|Read it]]

- Building

  ### [[RoClicks Studify|Studify]]

  Builds maps, buildings and props in the modern stud style: studded plastic materials, chunky stepped shapes and dense small detail. A pastel palette, recipes for trees, hills, water, fences and plots, strict rules against z-fighting and gaps, and a screenshot-checked Studio workflow for copying a reference faithfully.

  [Download30 KB](https://roclicks.gg/skills/studify.zip)[[RoClicks Studify|Read it]]

- Trailers

  ### [[RoClicks Roblox trailer|Roblox trailer]]

  Makes gameplay trailers end to end. A Luau driver plays each shot so it looks hand-played, a camera rig adds dolly, orbit, crane and whip moves, and Python with ffmpeg cuts a 30-second Roblox video thumbnail plus a vertical Shorts edit, with QA contact sheets.

  [Download64 KB](https://roclicks.gg/skills/roblox-trailer.zip)[[RoClicks Roblox trailer|Read it]]

- Music

  ### [[RoClicks Roblox game score|Roblox game score]]

  Makes a custom soundtrack for a game: lobby and zone themes, combat music, intensity layers and reward stingers, generated locally with the ACE-Step music model. Covers planning cues in one key and tempo, seamless loops, mastering to game loudness and wiring it up in Studio with crossfades and ducking.

  [Download3 KB](https://roclicks.gg/skills/roblox-game-score.zip)[[RoClicks Roblox game score|Read it]]

## Other skills worth installing

Made by other people and used alongside the ones above. Get them from their own pages.

- [agent-browser↗](https://github.com/vercel-labs/agent-browser)

  Drives a real browser from the agent: open pages, click, fill forms, take screenshots. Used for scraping references and checking pages.

- [Scrapling↗](https://github.com/D4Vinci/Scrapling)

  Scraping that gets past anti-bot pages. Used to pull chart data and reference thumbnails from the web.

- [Jest Lua↗](https://github.com/Roblox/jest-roblox)

  Roblox's port of Jest for Luau. A skill built from its docs makes the agent write tests the way Jest Lua actually behaves, not how JavaScript Jest does.

- [claude-music↗](https://github.com/AgriciDaniel/claude-music)

  Local AI music generation and editing (ACE-Step). The game soundtrack skill above builds on it.

- [graphify↗](https://github.com/safishamsi/graphify)

  Turns a codebase or a folder of notes into a knowledge graph the agent can query. Useful on a big game before a refactor.

- [humanizer↗](https://github.com/blader/humanizer)

  Rewrites text so it stops reading like AI. Used on game descriptions, update logs and store copy.
