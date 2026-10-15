---
tags: [research, roclicks]
source: https://roclicks.gg/resources/scripting/tools
retrieved: 2026-10-15
---
# Engineering tools

Small, game-agnostic tools for an agent working on a live Studio place. Python needs only the standard library (plus zstandard for some .rbxm files). Luau tests need the luau CLI.

Small, game-agnostic tools for an agent working on a live Studio place. Python needs only the standard library (plus `zstandard` for some `.rbxm` files). Luau tests need the `luau` CLI.

| File                                                                               | Kind                | What it does                                                                                       |
|------------------------------------------------------------------------------------|---------------------|----------------------------------------------------------------------------------------------------|
| [stage.py](https://roclicks.gg/resources/code/engineering/tools/stage.py)                             | Python              | Wraps edited sources (plus their base copies) into one `.rbxmx` with a unique folder name          |
| [stage_apply.luau](https://roclicks.gg/resources/code/engineering/tools/stage_apply.luau)             | Luau (execute_luau) | All-or-nothing base-compare apply of a staged folder                                               |
| [rbxm_extract.py](https://roclicks.gg/resources/code/engineering/tools/rbxm_extract.py)               | Python              | Snapshot exporter: every script in a binary `.rbxm` to `.luau` files, byte-exact                   |
| [fingerprint.luau](https://roclicks.gg/resources/code/engineering/tools/fingerprint.luau)             | Luau (execute_luau) | Path, size and hash of every script in Studio, no source text                                      |
| [snapshot_diff.py](https://roclicks.gg/resources/code/engineering/tools/snapshot_diff.py)             | Python              | Diff two trees, or a Studio fingerprint against a local tree                                       |
| [game_check.py](https://roclicks.gg/resources/code/engineering/tools/game_check.py)                   | Python              | Syntax-check every `.luau` before staging; optional lints                                          |
| [SessionStore.luau](https://roclicks.gg/resources/code/engineering/tools/SessionStore.luau)           | Luau module         | Saves with session lock, retry/backoff, kick on failed load, idempotent receipts, BindToClose wait |
| [mock_datastore.luau](https://roclicks.gg/resources/code/engineering/tools/mock_datastore.luau)       | Luau                | Mock DataStore + fake clock + fake players for plain-luau tests                                    |
| [test_sessionstore.luau](https://roclicks.gg/resources/code/engineering/tools/test_sessionstore.luau) | Luau test           | 20 checks of SessionStore against the mock (`luau test_sessionstore.luau`)                         |
| [Scheduler.luau](https://roclicks.gg/resources/code/engineering/tools/Scheduler.luau)                 | Luau module         | Time-budgeted coroutine jobs                                                                       |
| [devproducts.py](https://roclicks.gg/resources/code/engineering/tools/devproducts.py)                 | Python              | List/create developer products via Open Cloud; key from a chmod-600 file, never printed            |

## The push loop

``` bash
# 1. pull (Studio is the source of truth)
#    MCP: export_rbxm ServerScriptService.Game -> /tmp/sss.rbxm
python3 rbxm_extract.py /tmp/sss.rbxm snapshot/ServerScriptService
cp snapshot/ServerScriptService/Game/Services/Data.luau base/Data.luau   # your base copy
cp snapshot/ServerScriptService/Game/Services/Data.luau src/server/Services/Data.luau

# 2. edit src/..., then check
python3 game_check.py src --lint

# 3. stage with a unique name
python3 stage.py --name Stage_FixA_1 "ServerScriptService/Game/Services/Data=src/server/Services/Data.luau@base/Data.luau"

# 4. MCP: import_rbxm build/Stage_FixA_1.rbxmx into ServerStorage
# 5. MCP: execute_luau with stage_apply.luau (STAGE_NAME = "Stage_FixA_1")
#    -> "ok  ServerScriptService/Game/Services/Data"   or   "CONFLICT (nothing applied): ..."
```

## Snapshots and drift

- Extract each exported folder into `snapshot/<date>/<Service>/` (e.g. an export of `ServerScriptService.Game` goes into `snapshot/<date>/ServerScriptService`). Then paths match `fingerprint.luau`, which writes them relative to the service's parent.
- `python3 snapshot_diff.py snapshot/<date> src` shows which disk files are stale.
- Before editing, run `fingerprint.luau`, save its output, and `python3 snapshot_diff.py --fingerprint fp.txt snapshot/<date>` to see what a collaborator changed since the snapshot, with no source download.

## The mock-DataStore pattern

For any save module, inject the Roblox bits (`store`, `clock`, `time`, `wait`, `spawn`, `warn`) instead of reading globals, so plain `luau` can run it. The mock store deep-copies in and out, can be told to throw a queue of errors, and the fake `wait` advances time instantly and calls an `onWait` hook (that is how the test makes "another server" release its lock after three waits). See [[Data and saves|../data-and-saves.md]].

For modules you cannot change to take injected dependencies, generate shimmed copies: prepend a header that defines `game`, `script` and a `require` that resolves instance paths to files, and keep line numbers shifted by a known amount.

Previous: [[Open Cloud creating developer products from a script]] · Next: [[Luau traps that broke real games]]
