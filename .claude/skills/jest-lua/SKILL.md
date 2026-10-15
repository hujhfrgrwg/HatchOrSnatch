---
name: jest-lua
description: Write and run Luau unit tests with Jest Lua (Roblox's port of Jest, packages roblox/jest and roblox/jest-globals). Use when writing, fixing or reviewing *.spec.luau / *.spec.lua tests, setting up a Jest test runner in a Roblox place, mocking functions or timers, or when a test behaves differently from JavaScript Jest.
---

# Jest Lua

Roblox's port of Jest. The API follows JavaScript Jest 27, but **Lua forces deviations**. Write tests the way Jest Lua actually behaves, not the way JS Jest does. Read `references/Deviations.md` before writing any matcher, mock or `.each` table.

Source: the official docs from https://github.com/Roblox/jest-roblox (`docs/docs`, MIT, see `LICENSE`), copied into `references/`.

## The deviations that break JS-style tests
- **`expect(x).never.toBe(y)`**, not `.not` (`not` is a Lua keyword).
- **Matchers and `jest.fn` are called with `.`**, not `:` (`expect(a).toBe(b)`, `mock.mock.calls`).
- **`.each` takes tables, not tagged templates:** `test.each('a | b | expected', {1, 1, 2}, {1, 2, 3})('adds $a + $b', function(ref) ... end)`.
- **Custom matchers get `self` first:** `expect.extend({ toBeX = function(_, received, expected) ... end })`.
- **Arrays are 1-indexed:** `mockFn.mock.calls[1][1]` is the first argument of the first call; count calls with `#mockFn.mock.calls`.
- **`jest.fn()` returns two values:** `local mock, mockFn = jest.fn()`. `mock` is a callable table; pass `mockFn` (a real function) when the code under test needs a function.
- **`new mockFn()` is `mockFn.new()`.**
- **Truthiness is Lua's:** only `false` and `nil` are falsy, so `expect(0).toBeFalsy()` fails. Use `.toBeNil()` / `.never.toBeNil()` for nil checks.
- **Fake timers cover Roblox clocks:** `jest.useFakeTimers()` fakes `task.delay`, `task.wait`, `task.cancel`, `delay`, `tick`, `time`, `DateTime`, `os.time` and `os.clock`.
- **Globals are explicit:** `local JestGlobals = require(Packages.Dev.JestGlobals)` then `local describe, it, expect, jest = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.jest`.

## Setup (once per project)
`references/GettingStarted.md`: add `Jest` and `JestGlobals` as Wally dev dependencies, map `Packages` in `default.project.json`, add a `spec.lua` entrypoint that calls `Jest.runCLI(...)`, and run it in Studio or Open Cloud Luau Execution. Config options are in `references/Configuration.md` and `references/CLI.md`.

## Which reference to open
| Task | File |
|---|---|
| `describe` / `it` / `test` / `.each` / `.only` / `.skip` | `GlobalAPI.md` |
| Matchers (`toBe`, `toEqual`, `toThrow`, asymmetric matchers, `extend`) | `ExpectAPI.md`, `UsingMatchers.md` |
| `jest.fn`, mock return values, call inspection | `MockFunctions.md`, `MockFunctionAPI.md`, `JestObjectAPI.md` |
| Mocking Roblox globals (`game`, `DateTime`, `os`) | `GlobalMocks.md` |
| Fake timers (`task.delay`, `task.wait`) | `TimerMocks.md` |
| Promises and async | `TestingAsyncCode.md` |
| `beforeEach` / `afterAll` | `SetupAndTeardown.md` |
| Snapshots | `SnapshotTesting.md` |
| Running a subset | `TestFiltering.md` |
| Benchmarks | `JestBenchmarkAPI.md` |
| Upgrading from Jest Roblox 2 | `UpgradingToJest3.md` |

## Habits
- Keep logic you want to test in pure ModuleScripts that don't touch Instances, so they also run under Lune (see `Research/RoClicks/Tricks/Build your game outside Studio with Lune.md`).
- One behaviour per `it`. Name it as a sentence: `it("refunds the crate cost when the roll fails")`.
- Reset mocks in `beforeEach` (`jest.resetAllMocks()`); fake timers leak between tests otherwise.
