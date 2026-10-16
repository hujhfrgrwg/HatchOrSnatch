--!strict
-- DataService: ProfileV2 persistence (GDD 9, TEST_PLAN B).
--  * One key per player ("p_<UserId>"), schemaVersion + ProfileLogic.migrate on every load.
--  * Every write is a TRANSFORM run inside UpdateAsync on the latest stored value, so a retry can
--    never write a stale snapshot, and settlement transforms are exact-once via the ledger.
--  * Session lock (`_session`) in the same key, 180 s lease, refreshed on every write.
--  * Studio is MEMORY-ONLY unless workspace attribute UseDataStore = true, and even then it uses a
--    separate "_STUDIO_TEST" store so playtests never touch live saves.
--  * Failed writes stay queued and retry with backoff (15 s doubling to 5 min).

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("EOS"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local QuestConfig = require(Shared:WaitForChild("QuestConfig"))
local Net = require(Shared:WaitForChild("Net"))
local ProfileLogic = require(ServerScriptService.EOS.Core.ProfileLogic)
local Analytics = require(script.Parent.Analytics)

local CFG = GameConfig.Data
local DataService = {}

DataService.SESSION = HttpService:GenerateGUID(false) -- per server (JobId is empty in Studio)
DataService.mode = "unknown" -- "datastore" | "memory"

-- ===== store adapters =====

-- Memory store: same UpdateAsync contract, deep copies through JSON (catches aliasing bugs),
-- optional injected failures for tests (MemoryStore.failNext).
local MemoryStore = {}
MemoryStore.__index = MemoryStore
function MemoryStore.new()
	return setmetatable({ data = {} :: { [string]: string }, failures = 0, calls = 0 }, MemoryStore)
end
function MemoryStore:UpdateAsync(key: string, fn: (any) -> any): any
	self.calls += 1
	if self.failures > 0 then
		self.failures -= 1
		error("MemoryStore: injected failure (502)")
	end
	local raw = self.data[key]
	local old = if raw then HttpService:JSONDecode(raw) else nil
	local new = fn(old)
	if new == nil then
		return old -- aborted write: like DataStore, returns current value without writing
	end
	self.data[key] = HttpService:JSONEncode(new)
	return HttpService:JSONDecode(self.data[key])
end
function MemoryStore:failNext(n: number)
	self.failures = n
end
DataService.MemoryStore = MemoryStore

local store: any = nil

local function pickStore()
	local useDS = true
	local name = CFG.STORE_NAME
	if RunService:IsStudio() then
		name = CFG.STUDIO_STORE_NAME
		useDS = workspace:GetAttribute(CFG.STUDIO_USE_DATASTORE_ATTRIBUTE) == true
	end
	if useDS then
		local ok, ds = pcall(function()
			return DataStoreService:GetDataStore(name)
		end)
		if ok then
			store = ds
			DataService.mode = "datastore"
			print(("[EOS] DataService: DataStore '%s'"):format(name))
			return
		end
		warn("[EOS] DataService: GetDataStore failed, falling back to memory: " .. tostring(ds))
	end
	store = MemoryStore.new()
	DataService.mode = "memory"
	print("[EOS] DataService: MEMORY-ONLY (Studio). Set workspace attribute UseDataStore=true to test the Studio test store.")
end

local function isStudioApiOff(err: any): boolean
	local s = tostring(err)
	return RunService:IsStudio() and (string.find(s, "StudioAccessToApisNotAllowed", 1, true) ~= nil or string.find(s, "403", 1, true) ~= nil)
end

-- ===== sessions =====

type Session = {
	player: Player,
	key: string,
	profile: any, -- latest known (optimistic) profile
	queue: { { label: string, fn: (any) -> () } },
	saving: boolean,
	nextRetryAt: number,
	backoff: number,
	noSave: boolean,
	loaded: boolean,
	leaving: boolean,
}

local sessions: { [Player]: Session } = {}
local loadedSignal = Instance.new("BindableEvent")
local changedSignal = Instance.new("BindableEvent")
DataService.Loaded = loadedSignal.Event -- (player, profile)
DataService.Changed = changedSignal.Event -- (player, profile)
local leaveHooks: { (Player) -> () } = {}
local pushPending: { [Player]: boolean } = {}

local function keyFor(userId: number): string
	return CFG.KEY_PREFIX .. tostring(userId)
end

local function utcCtx()
	return { utcDate = ProfileLogic.utcDate(os.time()), questConfig = QuestConfig, ledgerSize = CFG.LEDGER_SIZE }
end
DataService.utcCtx = utcCtx

local function lockIsForeign(p: any): boolean
	local s = p and p._session
	return type(s) == "table" and s.id ~= DataService.SESSION and type(s.t) == "number" and os.time() - s.t < CFG.LOCK_LEASE
end

local function strip(p: any): any
	local c = ProfileLogic.deepCopy(p)
	c._session = nil
	return c
end

local function pushProfile(plr: Player)
	if pushPending[plr] then
		return
	end
	pushPending[plr] = true
	task.delay(0.15, function()
		pushPending[plr] = nil
		local s = sessions[plr]
		if s and s.loaded and plr.Parent and typeof(plr) == "Instance" then
			local p = s.profile
			plr:SetAttribute("EOS_Gold", p.gold)
			plr:SetAttribute("EOS_Gems", p.gems)
			local pet = if p.equippedPet ~= "" then ProfileLogic.petById(p, p.equippedPet) else nil
			plr:SetAttribute("EOS_PetFamily", pet and pet.family or "")
			plr:SetAttribute("EOS_PetSpecies", pet and pet.species or "")
			plr:SetAttribute("EOS_PetRarity", pet and pet.rarity or "")
			plr:SetAttribute("EOS_Wins", p.stats.wins)
			plr:SetAttribute("EOS_BestTier", p.stats.lifetimeBestTier)
			plr:SetAttribute("EOS_Captures", p.stats.captures)
			plr:SetAttribute("EOS_PetsHatched", p.stats.petsHatched or 0)
			Net.event("ProfileState"):FireClient(plr, ProfileLogic.clientView(p, QuestConfig))
			changedSignal:Fire(plr, p)
		end
	end)
end
DataService.pushProfile = pushProfile

-- Run queued transforms against the store, in order. Stops at the first failure.
local function flush(s: Session): boolean
	if s.saving or s.noSave then
		return false
	end
	if #s.queue == 0 then
		return true
	end
	s.saving = true
	local allOk = true
	while #s.queue > 0 do
		local op = s.queue[1]
		local refused = false
		local ok, result = pcall(function()
			return store:UpdateAsync(s.key, function(old)
				local prof = ProfileLogic.migrate(old)
				if lockIsForeign(prof) then
					refused = true
					return nil
				end
				op.fn(prof)
				prof._session = if s.leaving and #s.queue == 1 and op.label == "release" then nil else { id = DataService.SESSION, t = os.time() }
				return prof
			end)
		end)
		if ok and not refused then
			table.remove(s.queue, 1)
			if result then
				local prof = ProfileLogic.migrate(result)
				-- keep optimistic changes still queued on top of the stored truth
				for _, rest in ipairs(s.queue) do
					rest.fn(prof)
				end
				s.profile = prof
			end
			s.backoff = 0
		elseif refused then
			-- another server owns the save: never overwrite it
			s.noSave = true
			allOk = false
			Analytics.warn("PersistenceError", "lock" .. s.key, "save refused: another server holds the lock for " .. s.key, { userId = s.player.UserId, reason = "LOCK_TAKEN" })
			if s.player.Parent and not s.leaving then
				s.player:Kick("Your save is open in another server. Please rejoin in a moment.")
			end
			break
		else
			allOk = false
			s.backoff = math.clamp(if s.backoff == 0 then CFG.FAILED_SAVE_BACKOFF_MIN else s.backoff * 2, CFG.FAILED_SAVE_BACKOFF_MIN, CFG.FAILED_SAVE_BACKOFF_MAX)
			s.nextRetryAt = os.clock() + s.backoff
			Analytics.warn("PersistenceError", "write" .. s.key, "save failed for " .. s.key .. ": " .. tostring(result) .. " (retry in " .. s.backoff .. "s)", { userId = s.player.UserId, reason = "WRITE_FAILED", label = op.label })
			break
		end
	end
	s.saving = false
	return allOk
end

-- Try a few quick write attempts (B07: retry without duplicate credit thanks to the ledger).
local function flushWithRetries(s: Session)
	for attempt = 1, CFG.WRITE_RETRIES do
		if flush(s) or s.noSave then
			return
		end
		if attempt < CFG.WRITE_RETRIES then
			task.wait(attempt)
		end
	end
end

-- ===== public API =====

-- Queue a transform: applied to the cached profile now (for the UI) and to the store ASAP.
-- fn must be idempotent or naturally guarded (ledger / claimed flags), since a retry re-runs it.
function DataService.update(plr: Player, label: string, fn: (any) -> ()): boolean
	local s = sessions[plr]
	if not s or not s.loaded then
		return false
	end
	fn(s.profile)
	if s.noSave then
		pushProfile(plr)
		return true
	end
	table.insert(s.queue, { label = label, fn = fn })
	pushProfile(plr)
	task.spawn(flushWithRetries, s)
	return true
end

-- Like update, but waits until the change is in the store (Robux receipts: Roblox must only hear
-- "granted" once the Gems are saved). fn must be ledger-guarded: a retried receipt re-runs it.
-- Returns true when saved (or in a no-save session such as practice), false on timeout / lock loss.
function DataService.commit(plr: Player, label: string, fn: (any) -> (), timeout: number?): boolean
	local s = sessions[plr]
	if not s or not s.loaded then
		return false
	end
	fn(s.profile)
	if s.noSave then
		pushProfile(plr)
		return true
	end
	local op = { label = label, fn = fn }
	table.insert(s.queue, op)
	pushProfile(plr)
	local t0 = os.clock()
	while os.clock() - t0 < (timeout or 15) do
		flush(s)
		if not table.find(s.queue, op) then
			return true
		end
		if s.noSave then
			return false
		end
		task.wait(0.5)
	end
	return false
end

function DataService.get(plr: Player): any?
	local s = sessions[plr]
	return if s and s.loaded then s.profile else nil
end

function DataService.isLoaded(plr: Player): boolean
	local s = sessions[plr]
	return s ~= nil and s.loaded
end

function DataService.onLeaving(fn: (Player) -> ())
	table.insert(leaveHooks, fn)
end

-- Apply a match settlement exactly once (B01-B06). Returns (applied, summary).
function DataService.settle(plr: Player, settlement: any): (boolean, any)
	local s = sessions[plr]
	if not s or not s.loaded then
		return false, { reason = "NOT_LOADED" }
	end
	if settlement.isTest then
		Analytics.log("RewardGranted", { userId = plr.UserId, matchId = settlement.matchId, test = true, skipped = true })
		return false, { reason = "TEST_MATCH" }
	end
	local applied, summary = false, nil
	DataService.update(plr, "settle:" .. settlement.key, function(p)
		local a, sum = ProfileLogic.applySettlement(p, settlement, utcCtx())
		if applied == false and summary == nil then
			applied, summary = a, sum -- first (optimistic) application decides what we report
		end
	end)
	if applied then
		Analytics.log("RewardGranted", { userId = plr.UserId, matchId = settlement.matchId, eggTier = settlement.eggTier, material = summary.material, gold = summary.gold, gems = summary.gems })
		for _, q in ipairs(summary.quests) do
			Analytics.log("QuestProgressed", { userId = plr.UserId, questId = q.id, from = q.from, to = q.to })
		end
	else
		Analytics.log("DuplicateGrantPrevented", { userId = plr.UserId, matchId = settlement.matchId, key = settlement.key })
	end
	return applied, summary
end

-- ===== load / leave =====

local function load(plr: Player)
	local s: Session = {
		player = plr,
		key = keyFor(plr.UserId),
		profile = nil,
		queue = {},
		saving = false,
		nextRetryAt = 0,
		backoff = 0,
		noSave = false,
		loaded = false,
		leaving = false,
	}
	sessions[plr] = s
	local started = os.clock()
	local delays = CFG.LOAD_RETRY_DELAYS
	local attempt = 0
	while plr.Parent do
		attempt += 1
		local lockedBy = nil
		local steal = os.clock() - started > CFG.LOCK_WAIT
		local ok, result = pcall(function()
			return store:UpdateAsync(s.key, function(old)
				local prof = ProfileLogic.migrate(old)
				if lockIsForeign(prof) and not steal then
					lockedBy = prof._session
					return nil
				end
				-- today's quests go into the stored copy too: the first save re-reads the store, and a
				-- cache-only ensureDaily would be wiped by it (quests then vanished until a match settled)
				ProfileLogic.ensureDaily(prof, ProfileLogic.utcDate(os.time()), QuestConfig)
				prof._session = { id = DataService.SESSION, t = os.time() }
				return prof
			end)
		end)
		if ok and not lockedBy then
			local prof = ProfileLogic.migrate(result)
			ProfileLogic.ensureDaily(prof, ProfileLogic.utcDate(os.time()), QuestConfig)
			s.profile = prof
			s.loaded = true
			if steal then
				warn("[EOS] took over a stale session lock for " .. s.key)
			end
			break
		elseif ok and lockedBy then
			plr:SetAttribute("EOS_LoadStatus", "Loading your save...")
			task.wait(3)
		elseif isStudioApiOff(result) then
			print("[EOS] Studio API access is off: switching to MEMORY-ONLY saves")
			store = MemoryStore.new()
			DataService.mode = "memory"
		else
			Analytics.warn("PersistenceError", "load" .. s.key, "load failed for " .. s.key .. ": " .. tostring(result), { userId = plr.UserId, reason = "LOAD_FAILED", attempt = attempt })
			if attempt > #delays then
				if plr.Parent then
					plr:Kick("We couldn't load your save. Please rejoin.")
				end
				sessions[plr] = nil
				return
			end
			task.wait(delays[attempt])
		end
	end
	if not plr.Parent or not s.loaded then
		sessions[plr] = nil
		return
	end
	plr:SetAttribute("EOS_Loaded", true)
	plr:SetAttribute("EOS_LoadStatus", nil)
	plr:SetAttribute("EOS_AFK", s.profile.afkPreference == true)
	plr:SetAttribute("EOS_Volunteer", s.profile.volunteerPreference == true)
	plr:SetAttribute("EOS_IsNew", s.profile.stats.matchesCompleted == 0)
	pushProfile(plr)
	Analytics.log("SessionStart", { userId = plr.UserId, mode = DataService.mode })
	loadedSignal:Fire(plr, s.profile)
end

local releasing: { [Player]: boolean } = {}
local function release(plr: Player)
	local s = sessions[plr]
	if not s or releasing[plr] then
		return
	end
	releasing[plr] = true
	for _, hook in ipairs(leaveHooks) do
		local ok, err = pcall(hook, plr)
		if not ok then
			warn("[EOS] leave hook failed: " .. tostring(err))
		end
	end
	if s.loaded and not s.noSave then
		s.leaving = true
		table.insert(s.queue, { label = "release", fn = function() end })
		for _ = 1, CFG.WRITE_RETRIES do
			if flush(s) then
				break
			end
			task.wait(1)
		end
	end
	Analytics.log("SessionEnd", { userId = plr.UserId })
	sessions[plr] = nil
	releasing[plr] = nil
end

function DataService.init()
	pickStore()
	Players.PlayerAdded:Connect(function(plr)
		task.spawn(load, plr)
	end)
	for _, plr in ipairs(Players:GetPlayers()) do
		if not sessions[plr] then
			task.spawn(load, plr)
		end
	end
	Players.PlayerRemoving:Connect(function(plr)
		task.spawn(release, plr)
	end)
	game:BindToClose(function()
		for _, plr in ipairs(Players:GetPlayers()) do
			task.spawn(release, plr)
		end
		local deadline = os.clock() + 28
		while os.clock() < deadline and (next(sessions) ~= nil or next(releasing) ~= nil) do
			task.wait(0.25)
		end
	end)
	-- autosave / retry / lease refresh loop
	task.spawn(function()
		local lastTouch: { [Player]: number } = {}
		while true do
			task.wait(5)
			for plr, s in pairs(sessions) do
				if s.loaded and not s.noSave and not s.saving then
					if #s.queue > 0 and os.clock() >= s.nextRetryAt then
						task.spawn(flush, s)
					elseif os.clock() - (lastTouch[plr] or 0) > CFG.AUTOSAVE_INTERVAL then
						lastTouch[plr] = os.clock()
						table.insert(s.queue, { label = "touch", fn = function() end })
						task.spawn(flush, s)
					end
				end
			end
		end
	end)
end

-- Test hooks (Studio edit-mode / runtime evals only)
function DataService._store(): any
	return store
end
function DataService._setStore(s: any)
	store = s
	DataService.mode = "memory"
end
DataService._load = load
DataService._release = release
function DataService._session(plr: Player): any
	return sessions[plr]
end

return DataService
