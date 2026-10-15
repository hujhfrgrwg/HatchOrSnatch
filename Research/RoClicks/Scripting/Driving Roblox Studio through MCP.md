---
tags: [research, roclicks]
source: https://roclicks.gg/resources/scripting/studio-mcp
retrieved: 2026-10-15
---
# Driving Roblox Studio through MCP

How an AI coding agent reads, writes and tests a live Studio place without breaking it. Every rule here comes from a bug that cost at least one session.

How an AI coding agent reads, writes and tests a live Studio place without breaking it. Every rule here comes from a bug that cost at least one session.

- [[#Pick one MCP server]]
- [[#Guard every write with a landmark]]
- [[#Pushing code: never through set_script_source]]
- [[#Pulling code: byte-exact]]
- [[#The require cache lies]]
- [[#Edit mode vs playtest]]
- [[#Stalled bridges and stray processes]]
- [[#Screenshots and the camera]]
- [[#Checklist]]

## Pick one MCP server

Two Studio MCP servers can be connected at once (the community `robloxstudio` server and the built-in `Roblox_Studio` one). Their tool lists overlap: script read and write, Luau execution, screenshots, play and stop. Pick one and say so in the project's agent instructions.

- **Default to the community server** (`@chrrxs/robloxstudio-mcp`). It has `import_rbxm` / `export_rbxm` (disk-to-Studio and Studio-to-disk), separate `eval_server_runtime` / `eval_client_runtime` during a playtest, `get_runtime_logs`, `multiplayer_playtest`, and retry-safe `operation_id`s.
- **The one exception is uploads.** The community server's `upload_asset` needs an Open Cloud key or a cookie in its environment. The built-in server's `upload_image` uploads through the logged-in Studio session. It only takes http(s) URLs (serve the folder with `python3 -m http.server 8791 --bind 127.0.0.1`) and needs its own `studio_id` from `list_roblox_studios`. It takes a batch and returns a path-to-id map.
- **Why one server:** an agent that silently mixes servers ends up targeting two different Studio windows (see the next section) and uses tooling the developer chose not to.

## Guard every write with a landmark

With two Studio windows open, the MCP's "active instance" can **flip silently** between them, including mid-session, after a reconnect, and reliably after a play/stop. Worse, different tools can route to different windows at the same moment.

- Pass `instance_id` explicitly on every call when the server supports it (`get_connected_instances`). Ids change every time Studio reopens a place, so look them up per session.

- Make the **first line of every mutating `execute_luau`** an assertion on something only the target place has:

  ``` lua
  assert(game.Name == "MyGame" and workspace:FindFirstChild("MyGameMap"), "wrong place")
  ```

- Bulk tools with no guard (multi-edit, set_properties) should be bracketed by a guarded `execute_luau` before and after.

- **Why:** there is no way to copy scripts between Studio windows over MCP. One wrong-window build means re-emitting every file, and a cleanup script in the wrong window deletes someone else's work.

## Pushing code: never through set_script_source

`set_script_source` and `edit_script_lines` **expand `\n` inside string literals into real newlines** in transit. A line like `print("a\nb")` arrives split in two and the script fails with `Malformed string; did you forget to finish it?`, pointing at a line that looks fine. The push itself reports success; the error only shows in the runtime log.

Push through a Roblox XML model instead:

1.  Write the `.luau` file to disk.
2.  Wrap it in `.rbxmx` (see `tools/stage.py`, or the minimal shape below).
3.  `import_rbxm` with the **file path**. The source goes disk to Studio without passing through the JSON transport, and without spending context tokens a second time.

``` xml
<roblox version="4">
  <Item class="ModuleScript" referent="RBX0">
    <Properties>
      <string name="Name">Foo</string>
      <ProtectedString name="Source"><![CDATA[ ...luau... ]]></ProtectedString>
    </Properties>
  </Item>
</roblox>
```

- Escape `]]>` inside the source as `]]]]><![[Many agents, one Studio|CDATA[>`.
- For `class="Script"` add `<token name="RunContext">1</token>` (0 Legacy, 1 Server, 2 Client).
- Import into `ServerStorage` as a staging folder, then copy `.Source` onto the live scripts in one guarded `execute_luau` (see [multi-agent.md]]). Importing straight on top of a live folder replaces things other agents own.
- **Tool calls in one response are not ordered.** "Destroy old folder" and "import new folder" sent together can land import-first and then get destroyed. Sequence them across turns, or import into a staging name and do the swap in one script.

## Pulling code: byte-exact

When a collaborator edits live in Studio, Studio is the source of truth. Pull before you edit.

- `execute_luau` returning `.Source` works for small scripts, but big results get truncated or saved to a side file, and the JSON round trip can alter escapes.
- **Byte-exact route:** `export_rbxm` the folder to a binary `.rbxm` on disk, then extract every script with `tools/rbxm_extract.py`. This is also how you take a full snapshot for reviewers.
- Use `tools/fingerprint.luau` plus `tools/snapshot_diff.py` to check which scripts changed since your last pull without downloading any source.

## The require cache lies

- `execute_luau` runs in **its own Luau context**. `require(module)` there returns a *fresh* copy, not the running game's. Reading internal state from it reports the probe's own copy. To observe runtime state, have the module publish it (`SetAttribute` on an instance) or check side effects.
- **That cache persists across `execute_luau` calls.** Require a config, push a new source, require it again: you still get the old table. A verification pass can "confirm" stale numbers.
  - To check an edited module, read `.Source` back, or `loadstring(mod.Source)()` (needs LoadStringEnabled in edit context, which the plugin has), or clone the module and require the clone.
  - A module that requires an edited config gets the cached config too, so clone the config as well.
- Only trust `require` for modules you have not edited this session.

## Edit mode vs playtest

- **Instance changes made during a playtest are discarded on Stop.** `execute_luau` targets the edit DataModel even mid-playtest, so `Instance.new`, `:Destroy()` and property writes look applied and then vanish. Script source edits through `ScriptEditorService:UpdateSourceAsync` survive. Stop first; verify again with nothing running.
- **Edit-mode verification works when play mode is wedged.** Import the modules, `require` the services and drive them with a mock player table (`UserId`, `GetAttribute`, `SetAttribute`, `FindFirstChild`, `Character`). This also keeps load off a weak machine.
- `workspace.StreamingEnabled` can only be set in edit mode (a running script gets "lacking capability Plugin"). Set it with `set_properties`; in game code only `warn` if it is off.
- `execute_luau` calls time out at about 30 s. Build in batches and never loop-wait inside one call; wait in a background shell instead.

## Stalled bridges and stray processes

Symptoms seen repeatedly:

- `multiplayer_playtest start` or `solo_playtest start` times out; peers stay **"queued; not_executed"**.
- Every later start says "a test is already running" while no peers are registered.
- A child Studio process (`-editpid`, `--task EditFile`) stays alive for 10+ minutes.
- `capture_screenshot` reports "window appears minimized or not rendering".

What to do:

- Stop, wait, retry **once**. Then report it rather than looping. Each retry loads the machine.
- The real fix is **a Studio restart**, which loses unsaved work, so ask the developer to save and restart. Team Create keeps work across a crash, a local file does not.
- Meanwhile verify in edit mode (above).
- **Never kill Studio processes blindly.** A failed `launch` left two `RobloxStudio --task` strays that ignored SIGTERM and blinded the real Studio; but killing the wrong pid kills the developer's session. List with `ps aux | grep RobloxStudio`, show the developer what you would kill, and only `kill -9` strays you started. Never use the server's `launch` action to get a fresh place: ask the developer to do File \> New.

**Unfocused Studio is capped at 15 fps** (exactly). Frame-rate A/B tests in a background window are meaningless; ask for the window to be focused, or compare script time with the profiler instead.

## Screenshots and the camera

- Studio has **one viewport camera** and `capture_screenshot` captures it. Several agents moving it capture each other's views; follow the camera lock in [[Many agents, one Studio|multi-agent.md]].
- Setting `cam.CFrame` alone can keep the position but snap the rotation back. Set `cam.Focus` to the target in the same call, wait about 0.4 s, then capture. Prove the shot is yours with a centre `ViewportPointToRay` plus `workspace:Raycast` and print what it hit.
- Captures are 2x retina. Their pixels are **not** click coordinates: halve them, or read a button's `AbsolutePosition + AbsoluteSize / 2` and add the GUI inset (58 px) for `simulate_mouse_input`.
- Captures never draw BillboardGuis. ScreenGuis draw during a playtest in current builds; older builds returned solid magenta. Verify GUIs by a property sweep (`TextFits`, overlap of sibling `AbsolutePosition`/`AbsoluteSize`, `IsLoaded` per asset) when the capture is useless.
- If the developer is playing inside your playtest (real right-mouse or WASD `InputBegan` events show up), stop driving the client.

## Checklist

- One MCP server named in the agent instructions; the other used only for uploads.
- `instance_id` on every call; a landmark `assert` as line 1 of every mutating `execute_luau`.
- Code goes in through `.rbxmx` + `import_rbxm`, never `set_script_source`.
- Pull Studio source byte-exact before editing anything a collaborator may have touched.
- Never trust `require` for a module edited this session.
- Stop the playtest before making instance changes.
- On a stalled bridge: retry once, then ask for a Studio restart. Never kill unknown processes.

Previous: [[Engineering overview]] · Next: [[Many agents, one Studio]]
