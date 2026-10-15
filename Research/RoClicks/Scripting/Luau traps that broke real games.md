---
tags: [research, roclicks]
source: https://roclicks.gg/resources/scripting/luau-traps
retrieved: 2026-10-15
---
# Luau traps that broke real games

Small language and engine traps, each of which caused a real bug: nil globals, ambiguous syntax, weak tables, remote queues.

## Language

- **A local used before its declaration is a nil global.** One function referencing a helper declared further down the file read `nil` and threw thousands of frame-loop errors. Declare locals above their first use (or forward-declare them).
- **`(x :: T).Prop = v` on the line after one ending in `)` parses as a call.** Luau reads it as calling the previous expression. Assign the cast to a local first.
- **Weak-keyed tables for registries that must persist end up empty.** The garbage collector clears them. Use strong tables and prune entries when `Parent` becomes nil.

## Engine

- **`PreloadAsync` fetches but doesn't decode.** Draw each unique image once in a hidden ScreenGui at boot to really warm it up.
- **Unused server-to-client remotes need a no-op listener.** Otherwise the client logs "Remote event invocation queue exhausted" and drops events.
- **Know whether an event carries the before or the after value.** A server that patches state before firing sends the new value; UI that assumed the old one showed wrong numbers.
- **Let replicated state land before reading it.** A short `task.wait(0.15)` before a popup reads counters avoids showing the previous value.
- **Some phones can't run `--!native`.** Leave it off small client modules.

## Defensive habits

- **Rate-limit warnings in frame loops** (once per message) and wrap `RenderStepped` bodies in `pcall`. One error at 60 fps buries everything else in the output.
- **Pooled objects need a generation counter** so delayed callbacks from a previous use don't act on the object's next life.
- **Guard optional APIs** (`if UI.PageChanged then`). An older copy of a module without the function killed a whole bridge.
- **Find UI by exported name,** never by `GetChildren` order or sorted index.
- **Tool output created in edit mode gets `Archivable = false`** so harness runs don't leave debris saved into the place.

Previous: [[Engineering tools]]
