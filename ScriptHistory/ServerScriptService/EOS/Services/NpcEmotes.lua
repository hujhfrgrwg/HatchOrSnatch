-- NpcEmotes (HOS-BOT-002, 17 Oct): lobby NPCs emote now and then, like players do.
--  * LOBBY bots only (never in a match), and only while standing: the emote holds the bot's lobby
--    walk (brain.pauseUntil) until it ends; a bot that starts moving anyway stops dancing
--  * uncommon and never in sync (developer, Oct 17): each bot rolls its own gap (EMOTE_INTERVAL_*,
--    first one EMOTE_FIRST_*); at most EMOTE_MAX_AT_ONCE bots emote in the whole lobby, and none
--    starts within EMOTE_GAP s of the last one ending
--  * picks: mostly COMMON emotes (the cheap end of the crate), now and then a rare+ one
--  * reactions: when a match's results end, maybe one lobby bot cheers (EMOTE_CHEER_*); when a real
--    player emotes, now and then a standing bot within EMOTE_COPY_RANGE copies them after 0.5-1.5 s
--    (EMOTE_COPY_CHANCE, once per bot per EMOTE_COPY_COOLDOWN)
--  * songs: clients play a bot's song quieter and shorter-range (EMOTE_SOUND_*, EmoteController)
--  * plays the same way a player's emote does: the clip (Shared/EmoteConfig animId) on the bot's
--    server Animator (replicates) and EOS_Emote on the body, so every client adds the song and
--    any EmoteFX prop construct (EmoteController watches NPC bodies too)
-- Numbers: GameConfig.Npc.EMOTE_* (read live). Kill switch: GameConfig.Npc.LOBBY_EMOTES (false stops them all).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local EmoteConfig = require(Shared:WaitForChild("EmoteConfig"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local NpcEmotes = {}

local N = GameConfig.Npc
local LOOP_MIN, LOOP_MAX = 6, 11 -- seconds a looping emote plays
local ONCE_MAX = 12 -- a one-shot emote ends with its clip (or by this)
local RARE_CHANCE = 0.15 -- picks above COMMON
local LEGENDARY_SHARE = 0.2 -- of those, the share that are legendary
local COPY_DELAY_MIN, COPY_DELAY_MAX = 0.5, 1.5
local COPY_PLAYER_COOLDOWN = 8 -- one copy chance per player per this many seconds
local MOVE_STOP = 3 -- studs/s: a bot moving faster than this ends its emote
local TICK = 0.25

-- results-end cheers: upbeat dances and gestures (no sits or naps)
local CHEERS = {
	"thumbs_up", "loser_dance", "idle_dance", "shuffle", "candy_dance", "neko_dance", "snappy_skip",
	"dramatic_bow", "boogie_down", "jumpstyle", "electro_shuffle", "orange_sway",
}

local rng = Random.new()
local npc: any = nil -- NpcService (passed in: it requires this module)
local state: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any -- bot -> { nextAt, track, untilT, id }
local copyReady: { [Player]: number } = {}
local lastEndAt = -math.huge -- when the last bot emote ended (EMOTE_GAP counts from here)
local idCache: { [string]: string } = {}

local function on(): boolean
	return GameConfig.Npc.LOBBY_EMOTES == true
end

local function clipId(e: any): string?
	if e.animId ~= nil and e.animId ~= "" then
		return "rbxassetid://" .. tostring(e.animId)
	end
	if idCache[e.id] then
		return idCache[e.id]
	end
	if not RunService:IsStudio() then
		return nil
	end
	local lib = ReplicatedStorage:FindFirstChild(EmoteConfig.LIBRARY)
	local seq = lib and lib:FindFirstChild(e.id)
	if not seq then
		return nil
	end
	local ok, cid = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(seq)
	end)
	if ok and cid then
		idCache[e.id] = cid
		return cid
	end
	return nil
end

local function pick(): string
	local want = "common"
	if rng:NextNumber() < RARE_CHANCE then
		want = if rng:NextNumber() < LEGENDARY_SHARE then "legendary" elseif rng:NextNumber() < 0.6 then "rare" else "epic"
	end
	local pool = {}
	for _, e in ipairs(EmoteConfig.LIST) do
		if e.rarity == want then
			table.insert(pool, e.id)
		end
	end
	return pool[rng:NextInteger(1, #pool)]
end

local function st(bot: any): any
	local s = state[bot]
	if not s then
		s = { nextAt = os.clock() + rng:NextNumber(N.EMOTE_FIRST_MIN, N.EMOTE_FIRST_MAX), copyAt = 0 }
		state[bot] = s
	end
	return s
end

local function alive(bot: any): boolean
	local m = bot.Character
	return m ~= nil and m.Parent ~= nil and bot.human ~= nil and bot.human.Health > 0
end

local function lobbyBot(bot: any): boolean
	return bot.kind == "LOBBY" and alive(bot) and bot:GetAttribute("EOS_InMatch") ~= true
end

local function speedOf(bot: any): number
	local v = bot.root.AssemblyLinearVelocity
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

-- standing around right now (its brain is in a pause, the body is still)
local function standing(bot: any): boolean
	local b = bot.brain
	return type(b) == "table" and type(b.pauseUntil) == "number" and os.clock() < b.pauseUntil and speedOf(bot) < 1
end

local function emotingCount(): number
	local n = 0
	for _, s in pairs(state) do
		if s.id or s.pending then
			n += 1
		end
	end
	return n
end

-- room for one more bot emote in the lobby right now
local function free(): boolean
	return emotingCount() < N.EMOTE_MAX_AT_ONCE and os.clock() >= lastEndAt + N.EMOTE_GAP
end

local function stop(bot: any)
	local s = state[bot]
	if not s or not s.id then
		return
	end
	if s.track then
		s.track:Stop(0.25)
		s.track:Destroy()
	end
	s.track, s.id, s.untilT = nil, nil, nil
	lastEndAt = os.clock()
	s.nextAt = lastEndAt + rng:NextNumber(N.EMOTE_INTERVAL_MIN, N.EMOTE_INTERVAL_MAX)
	if bot.Character then
		bot.Character:SetAttribute("EOS_Emote", "")
	end
end

local function hold(bot: any, untilT: number)
	local b = bot.brain
	if type(b) == "table" then
		b.pauseUntil = math.max(type(b.pauseUntil) == "number" and b.pauseUntil or 0, untilT + rng:NextNumber(0.5, 2))
	end
end

local function play(bot: any, id: string): boolean
	local e = EmoteConfig.get(id)
	local animator = bot.human and bot.human:FindFirstChildOfClass("Animator")
	local cid = e and clipId(e)
	if not e or not animator or not cid or not lobbyBot(bot) then
		return false
	end
	local s = st(bot)
	if s.id then
		stop(bot)
	end
	local a = Instance.new("Animation")
	a.AnimationId = cid
	local ok, t = pcall(function()
		return animator:LoadAnimation(a)
	end)
	if not ok or not t then
		return false
	end
	t.Priority = Enum.AnimationPriority.Action4
	t.Looped = not e.once
	t:Play(0.2)
	local now = os.clock()
	s.track, s.id = t, id
	s.untilT = now + (if e.once then ONCE_MAX else rng:NextNumber(LOOP_MIN, LOOP_MAX))
	if e.once then
		t.Stopped:Once(function()
			if s.track == t then
				stop(bot)
			end
		end)
	end
	hold(bot, s.untilT)
	bot.Character:SetAttribute("EOS_Emote", id)
	return true
end

local function step()
	local now = os.clock()
	local enabled = on()
	for _, bot in ipairs(npc.all()) do
		local s = st(bot)
		if s.id then
			-- end it: time up, switched off, left the lobby, or walking off
			if not enabled or not lobbyBot(bot) or now >= (s.untilT or 0) or speedOf(bot) > MOVE_STOP then
				stop(bot)
			else
				hold(bot, s.untilT) -- (a fresh brain after a match drops the old pause)
			end
		elseif enabled and now >= s.nextAt and lobbyBot(bot) and not s.pending then
			if not free() or not standing(bot) or not play(bot, pick()) then
				s.nextAt = now + rng:NextNumber(3, 8) -- busy (walking, or another bot's turn): try again soon
			end
		end
	end
	-- forget bodies that are gone
	for bot, s in pairs(state) do
		if not bot.Character or not bot.Character.Parent then
			if s.track then
				s.track:Destroy()
			end
			state[bot] = nil
		end
	end
end

-- stop a stroll, wait for the bot to settle, then play
local function playSoon(bot: any, id: string, delay: number)
	local s = st(bot)
	s.pending = true -- counts against EMOTE_MAX_AT_ONCE until it plays
	hold(bot, os.clock() + delay + 1)
	task.delay(delay, function()
		s.pending = nil
		if on() and lobbyBot(bot) and not s.id then
			play(bot, id)
		end
	end)
end

-- results ended: now and then one lobby bot cheers
local function cheer()
	if not on() or rng:NextNumber() >= N.EMOTE_CHEER_CHANCE or not free() then
		return
	end
	local pool = {}
	for _, bot in ipairs(npc.all()) do
		if lobbyBot(bot) and not st(bot).id and speedOf(bot) < MOVE_STOP then
			table.insert(pool, bot)
		end
	end
	local n = math.min(#pool, N.EMOTE_CHEER_MAX, N.EMOTE_MAX_AT_ONCE - emotingCount())
	for _ = 1, n do
		local bot = table.remove(pool, rng:NextInteger(1, #pool))
		playSoon(bot, CHEERS[rng:NextInteger(1, #CHEERS)], rng:NextNumber(0.2, 1.4))
	end
end

-- a real player just started an emote: maybe a bot nearby joins in
local function copy(plr: Player, char: Model)
	local id = char:GetAttribute("EOS_Emote")
	if not on() or type(id) ~= "string" or id == "" or not EmoteConfig.get(id) then
		return
	end
	local now = os.clock()
	if now < (copyReady[plr] or 0) then
		return
	end
	copyReady[plr] = now + COPY_PLAYER_COOLDOWN
	if rng:NextNumber() >= N.EMOTE_COPY_CHANCE or not free() then
		return
	end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local best, bestD = nil, N.EMOTE_COPY_RANGE
	for _, bot in ipairs(npc.all()) do
		if lobbyBot(bot) and not st(bot).id and now >= st(bot).copyAt and speedOf(bot) < MOVE_STOP then
			local d = (bot.root.Position - root.Position).Magnitude
			if d <= bestD then
				best, bestD = bot, d
			end
		end
	end
	if best then
		st(best).copyAt = now + N.EMOTE_COPY_COOLDOWN
		playSoon(best, id, rng:NextNumber(COPY_DELAY_MIN, COPY_DELAY_MAX))
	end
end

local function watchPlayer(plr: Player)
	local function hook(char: Model)
		char:GetAttributeChangedSignal("EOS_Emote"):Connect(function()
			copy(plr, char)
		end)
	end
	if plr.Character then
		hook(plr.Character)
	end
	plr.CharacterAdded:Connect(hook)
end

-- npcService: NpcService (all() = every bot table)
function NpcEmotes.init(npcService: any)
	npc = npcService
	task.spawn(function()
		while true do
			task.wait(TICK)
			local ok, err = pcall(step)
			if not ok then
				warn("[EOS] NpcEmotes: " .. tostring(err))
			end
		end
	end)
	for _, plr in ipairs(Players:GetPlayers()) do
		watchPlayer(plr)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(plr)
		copyReady[plr] = nil
	end)
	-- MatchService requires NpcService, so look it up once everything has loaded
	task.defer(function()
		local ok, MatchService = pcall(require, script.Parent.MatchService)
		if ok and MatchService.onResults then
			MatchService.onResults(function()
				task.delay(GameConfig.Timing.RESULTS, cheer)
			end)
		end
	end)
end

-- test hooks
NpcEmotes._play = play
NpcEmotes._stop = stop
NpcEmotes._cheer = cheer
NpcEmotes._state = state

return NpcEmotes
