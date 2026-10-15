--!nonstrict
-- Generic server-side tutorial step machine.
-- Rules it enforces: actions done early count, goals are absolute, steps can
-- go backwards, rewards pay once, rejoin resumes, skip is allowed.
-- Wire `Tutorial.record(player, action)` into your game services, and call
-- `Tutorial.tick(player)` about once per second. `Hooks` is yours to fill.

local Tutorial = {}

export type State = {
	step: number,          -- index into STEPS, or #STEPS + 1 when done
	done: boolean,
	did: { [string]: boolean },   -- every action ever seen, whatever the step
	paid: { [string]: boolean },  -- reward already paid for this step id
	shownAt: number?,
}

-- Game-specific hooks (replace with your own services)
local Hooks = {
	getState = function(_player: Player): State? return nil end,
	count = function(_player: Player, _what: string): number return 0 end,
	battleRunning = function(_player: Player): boolean return false end,
	cash = function(_player: Player): number return 0 end,
	grant = function(_player: Player, _reward: { [string]: number }) end,
	send = function(_player: Player, _view: { [string]: any }) end,
	analytics = function(_player: Player, _stepId: string, _seconds: number) end,
}
Tutorial.Hooks = Hooks

-- Each step: id, card text (8 words max), done(), optional back(), reward.
local STEPS = {
	{ id = "collect", text = "Walk over your farm to collect",
	  done = function(p, st) return st.did.collect end,
	  reward = { cash = 50 } },
	{ id = "sell", text = "Sell your wheat for cash",
	  done = function(p, st) return st.did.sell end,
	  reward = { cash = 100 } },
	{ id = "train", text = "Train 3 soldiers", goal = 8,
	  -- absolute goal, so training early counts
	  done = function(p, st) return Hooks.count(p, "army") >= 8 end,
	  counter = function(p) return ("Soldiers %d / 8"):format(Hooks.count(p, "army")) end,
	  reward = { cash = 150 } },
	{ id = "attack", text = "Attack your neighbour!",
	  done = function(p, st) return st.did.tutorialWarStarted end,
	  back = function(p, st) -- army too small? go back to train
		if Hooks.count(p, "army") < 8 then return "train" end
		return nil
	  end },
	{ id = "win", text = "Watch your army win!",
	  done = function(p, st) return st.did.tutorialWarWon end,
	  back = function(p, st) -- no battle and not won: lost or left
		if not Hooks.battleRunning(p) and not st.did.tutorialWarWon then
			st.did.tutorialWarStarted = false
			return (Hooks.count(p, "army") < 8) and "train" or "attack"
		end
		return nil
	  end,
	  reward = { cash = 200, gems = 2 } },
	{ id = "upgrade", text = "Upgrade your farm",
	  done = function(p, st) return st.did.upgrade end,
	  onShow = function(p, st) -- guarantee affordability
		local need = 100 - Hooks.cash(p)
		if need > 0 then Hooks.grant(p, { cash = need }) end
	  end,
	  reward = { cash = 100, gems = 3 } },
}

local INDEX: { [string]: number } = {}
for i, s in ipairs(STEPS) do INDEX[s.id] = i end

local function view(p: Player, st: State)
	if st.done then
		Hooks.send(p, { done = true })
		return
	end
	local s = STEPS[st.step]
	Hooks.send(p, {
		step = st.step, total = #STEPS, id = s.id, text = s.text,
		counter = s.counter and s.counter(p) or nil,
	})
end

local function show(p: Player, st: State, i: number)
	st.step = i
	st.shownAt = os.clock()
	local s = STEPS[i]
	if s and s.onShow then s.onShow(p, st) end
	view(p, st)
end

local function finishStep(p: Player, st: State)
	local s = STEPS[st.step]
	if s.reward and not st.paid[s.id] then
		st.paid[s.id] = true
		Hooks.grant(p, s.reward)
	end
	Hooks.analytics(p, s.id, os.clock() - (st.shownAt or os.clock()))
	if st.step >= #STEPS then
		st.done = true
		view(p, st)
	else
		show(p, st, st.step + 1)
	end
end

-- Call from game code for every relevant action, at any time.
function Tutorial.record(p: Player, action: string)
	local st = Hooks.getState(p)
	if st then st.did[action] = true end
end

-- Call about once per second per player.
function Tutorial.tick(p: Player)
	local st = Hooks.getState(p)
	if not st or st.done then return end
	local s = STEPS[st.step]
	if s.back then
		local to = s.back(p, st)
		if to then
			show(p, st, INDEX[to])
			return
		end
	end
	if s.done(p, st) then
		-- pre-satisfied steps still show for ~1 s so the player sees the tick
		if os.clock() - (st.shownAt or 0) >= 1 then finishStep(p, st) end
	elseif s.counter then
		view(p, st)
	end
end

-- Call on join with the loaded save: resume, re-checked by the next tick.
function Tutorial.playerLoaded(p: Player)
	local st = Hooks.getState(p)
	if not st then return end
	if st.done then return end
	st.step = math.clamp(st.step, 1, #STEPS)
	show(p, st, st.step)
end

function Tutorial.skip(p: Player)
	local st = Hooks.getState(p)
	if not st or st.done then return end
	st.done = true
	view(p, st)
end

-- True while tutorial-only rules apply to THIS target (scope locks to it).
function Tutorial.isTutorialTarget(st: State, targetId: string, tutorialTargetId: string): boolean
	return not st.done and targetId == tutorialTargetId
end

return Tutorial
