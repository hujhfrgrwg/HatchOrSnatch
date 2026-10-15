---
tags: [research, roclicks]
source: https://roclicks.gg/resources/scripting
retrieved: 2026-10-15
---
# Engineering

[Resources](https://roclicks.gg/) / Engineering

Saves that never lose data, Studio through MCP, many agents in one Studio, performance and input.

## Paste-ready for this topic

- [[Build your game outside Studio with Lune|TricksBuild your game outside Studio with Lune]]
- [[Get scripts and images into Studio fast|TricksGet scripts and images into Studio fast]]

1.  [[Engineering overview|01Engineering overviewSystems and workflow for making a Roblox game with one or more AI agents driving Studio through MCP. Every rule names the bug it prevents.2 min read]]
2.  [[Driving Roblox Studio through MCP|02Driving Roblox Studio through MCPHow an AI coding agent reads, writes and tests a live Studio place without breaking it. Every rule here comes from a bug that cost at least one session.7 min read]]
3.  [[Many agents, one Studio|03Many agents, one StudioHow to run several AI agents (and a human collaborator) against one live place without anyone overwriting anyone.6 min read]]
4.  [[Fix brief template|04Fix brief templateA shared brief for parallel fix agents. Copy it into the project (e.g. reviews/FIXBRIEF.md), fill in the \<...\> parts, and give each agent a short prompt naming its owned files and bug ids plus "read...3 min read]]
5.  [[Data and saves|05Data and savesSave bugs are invisible in Studio, because Studio playtests usually run memory-only. These are the rules that came out of a save-layer review of a live game; every one prevents silent progress loss.8 min read]]
6.  [[Solo in a shared server games|06"Solo in a shared server" gamesMany tycoons, idle games and PvE campaigns are really single-player, but Roblox servers hold several players.6 min read]]
7.  [[Performance|07PerformanceKids play on phones, tablets and Chromebooks. Most "the game feels bad" reports turn out to be hitches, lost taps or slow pop-in. Rules with the numbers that justified them.7 min read]]
8.  [[Input|08InputInput bugs look like "the button sometimes doesn't work" or "my airstrike landed on my own army". They come from several listeners hearing the same event, and from mixing up coordinate spaces.5 min read]]
9.  [[Open Cloud creating developer products from a script|09Open Cloud: creating developer products from a scriptCreating 20 developer products by hand in the Creator Dashboard is slow and error-prone (typos in prices, missing icons, ids pasted into the wrong config line).3 min read]]
10. [[Engineering tools|10Engineering toolsSmall, game-agnostic tools for an agent working on a live Studio place. Python needs only the standard library (plus zstandard for some .rbxm files). Luau tests need the luau CLI.2 min read]]
11. [[Luau traps that broke real games|11Luau traps that broke real gamesSmall language and engine traps, each of which caused a real bug: nil globals, ambiguous syntax, weak tables, remote queues.1 min read]]
