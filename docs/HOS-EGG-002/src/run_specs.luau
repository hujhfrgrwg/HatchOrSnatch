-- HOS-EGG-002 spec runner for Lune: a minimal jest-lua-shaped shim (describe / it / expect with the matchers the
-- specs use). Run from this folder:  lune run run_specs.luau
local fails, passes = 0, 0
local path = {}

local function fmt(v: any): string
	return if type(v) == "string" then string.format("%q", v) else tostring(v)
end

local function expect(received: any)
	local function check(ok: boolean, msg: string)
		if not ok then
			error(msg, 3)
		end
	end
	local m = {}
	function m.toBe(expected: any)
		check(received == expected, ("expected %s, got %s"):format(fmt(expected), fmt(received)))
	end
	m.toEqual = m.toBe
	function m.toBeNil()
		check(received == nil, ("expected nil, got %s"):format(fmt(received)))
	end
	m.never = {
		toBe = function(expected: any)
			check(received ~= expected, ("expected not %s"):format(fmt(expected)))
		end,
		toBeNil = function()
			check(received ~= nil, "expected a value, got nil")
		end,
	}
	return m
end

local function describe(name: string, fn: () -> ())
	table.insert(path, name)
	fn()
	table.remove(path)
end

local function it(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	local full = table.concat(path, " > ") .. " > " .. name
	if ok then
		passes += 1
	else
		fails += 1
		print("FAIL  " .. full .. "\n      " .. tostring(err))
	end
end

local JestGlobals = { describe = describe, it = it, test = it, expect = expect }

local EggConfig = require("./EggConfig")
local EggLogic = require("./EggLogic")
EggLogic.setConfig(EggConfig)
require("./EggLogic.spec")(JestGlobals, EggLogic, EggConfig)

require("./ProfileIncubator.spec")(JestGlobals, EggLogic, EggConfig)

print(("%d passed, %d failed"):format(passes, fails))
if fails > 0 then
	error("specs failed")
end
