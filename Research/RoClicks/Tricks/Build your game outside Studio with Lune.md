---
tags: [research, roclicks]
source: https://roclicks.gg/resources/tricks/build-outside-studio-with-lune
retrieved: 2026-10-15
---
# Build your game outside Studio with Lune

Lune runs Luau on your computer and reads and writes Roblox place files. Build the whole place from code, test logic without Studio, and model meshes in a loop your AI can see.

[Lune](https://github.com/lune-org/lune) is a standalone Luau runtime: it runs Roblox's language on your own computer, outside Studio, with files, processes and the network available. Its `@lune/roblox` library has Roblox's datatypes (Vector3, CFrame, Color3 and the rest) and can open and save `.rbxl`, `.rbxlx`, `.rbxm` and `.rbxmx` files.

For an AI agent that matters a lot. Studio is slow to drive, can't be screenshotted reliably, and every push goes through a tool call. Lune is just a command: the agent runs it, reads the output, fixes, runs it again, as many times as it takes.

## Install

``` text
aftman add lune-org/lune     (or: rokit add lune-org/lune, or download a release from GitHub)
lune --version
```

## Trick 1: build the whole place file from code

Keep every script as a `.luau` file in your project, and have one Lune script assemble the place: each script into its service, the folders, the lighting. Then open the result in Studio.

``` text
-- tools/build.luau   run with: lune run tools/build.luau
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Instance = roblox.Instance

local game = Instance.new("DataModel")
local function script(class, name, path, parent)
    local s = Instance.new(class)
    s.Name = name
    s.Source = fs.readFile(path)
    s.Parent = parent
    return s
end

script("Script", "Server", "src/Server/Server.server.luau", game:GetService("ServerScriptService"))
script("ModuleScript", "Config", "src/Shared/Config.luau", game:GetService("ReplicatedStorage"))
-- A new DataModel has no StarterPlayerScripts yet: make it.
local sps = Instance.new("StarterPlayerScripts")
sps.Parent = game:GetService("StarterPlayer")
script("LocalScript", "Client", "src/Client/Client.client.luau", sps)

fs.writeFile("MyGame.rbxlx", roblox.serializePlace(game, true))
```

**The step further: run your map code during the build.** If the map is built by code (`Map.build()`), run that same function inside the Lune build, so the place opens with the world already visible in edit mode. It also proves the build code actually runs before Studio ever sees it. Lune doesn't have every Roblox service and method, so:

- Load each module with `luau.load(source, { environment = env })` and give it a `require` that loads the other modules the same way.
- Fake the services Lune lacks: a `RunService` whose `IsStudio()` returns true, stub `TweenInfo.new` and `RaycastParams.new`.
- Add missing methods with `roblox.implementMethod("Model", "PivotTo", ...)` and `GetPivot`.

At runtime the server builds the same map from the same code, so the saved place and the live game never drift apart.

## Trick 2: test game logic without Studio

Anything that is plain Luau (economy maths, upgrade costs, roll odds, save data migration, a pacing simulation) can run in Lune in milliseconds. Put it in modules that don't touch Instances, and an agent can run a hundred simulated players through your progression before you open Studio once.

``` text
lune run sim/pacing.luau     -- prints time to each upgrade for a simulated player
```

## Trick 3: model meshes in a loop your AI can see

Write a small stand-in for `EditableMesh` in Lune (the same `AddVertex`, `AddTriangle`, colour and UV calls) that saves an `.obj` file instead. Then the loop is:

1.  `lune run meshlab/run Crate` builds the model from `models/Crate.luau` and writes `out/Crate.obj`.
2.  Blender renders it headless (`blender -b -P render.py -- out/Crate.obj out/Crate.png`), lit like a Studio baseplate.
3.  The agent looks at the PNG, fixes the model code, and repeats.

The same model file runs on a real `EditableMesh` in Studio when it's done, so what you previewed is what you get.

## Gotchas

- **`CFrame.lookAt` in Lune 0.10.5 is wrong for any direction with a Z component** (only straight ±X comes out right). Build the rotation matrix yourself until you've checked your version. This one turned a forest of trees into scattered sticks.
- **Lune is not Studio.** Physics, rendering, players, replication and most services don't exist. Keep the code you run in Lune to pure logic and Instance building.
- **Saved meshes.** An EditableMesh isn't saved with the place. Store mesh "spots" in the place and rebuild the meshes when the game starts.

## Paste this into your agent

``` text
Set up a Lune build for this Roblox game so you can build and check it without Studio:
1. Install Lune if missing (aftman, rokit, or a GitHub release) and confirm lune --version.
2. Write tools/build.luau: create a DataModel with @lune/roblox, put every .luau file from src/ into the right service (Server -> ServerScriptService, Shared -> ReplicatedStorage, Client -> StarterPlayerScripts), and save it as a .rbxlx with roblox.serializePlace.
3. If the map is built by code, run that build function inside the Lune script too: load modules with luau.load and a custom environment and require, fake any services Lune lacks (RunService.IsStudio, TweenInfo, RaycastParams), and add missing methods with roblox.implementMethod (Model:PivotTo, Model:GetPivot).
4. Move pure logic (economy, costs, odds) into modules that don't touch Instances, and add a lune run script that simulates a player through the progression and prints the times.
5. Run everything, fix what breaks, and tell me the command to rebuild the place.
Do not open or playtest Studio; I will open the built place myself.
```

Related: [[Get scripts and images into Studio fast|get scripts and images into Studio fast]], and [Jest Lua](https://github.com/Roblox/jest-roblox) when you want real unit tests.

Previous: [[AI 3D models that fit a stud-style game]]
