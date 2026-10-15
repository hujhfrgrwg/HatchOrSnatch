--!strict
-- TagCache: a CollectionService-tag cache that works under StreamingEnabled.
--
-- Why: GetInstanceAddedSignal(tag) does NOT fire for an instance that streams in already carrying the tag,
-- which is how everything outside the spawn area arrives. A cache built from GetTagged at startup and
-- maintained from that signal freezes at whatever was loaded on join (measured: hundreds of tagged parts
-- streamed in, the handler fired zero times). Rebuild on a timer with a cheap change check instead.
-- GetInstanceRemovedSignal DOES fire on stream-out, so it is still used for cleanup.
--
--   local cache = TagCache.new("Pressable", function(inst) return inst:IsA("BasePart") end)
--   cache.Changed:Connect(function(list) rebuildOverlapFilter(list) end)
--   cache:onRemoved(function(inst) restPose[inst] = nil end)
--   ...
--   cache:destroy()

local CollectionService = game:GetService("CollectionService")

local TagCache = {}
TagCache.__index = TagCache

export type TagCache = typeof(setmetatable(
	{} :: {
		tag: string,
		filter: ((Instance) -> boolean)?,
		list: { Instance },
		set: { [Instance]: boolean },
		Changed: BindableEvent,
		_count: number,
		_alive: boolean,
		_conns: { RBXScriptConnection },
	},
	TagCache
))

function TagCache.new(tag: string, filter: ((Instance) -> boolean)?, period: number?): TagCache
	local changed = Instance.new("BindableEvent")
	local self = setmetatable({
		tag = tag,
		filter = filter,
		list = {},
		set = {},
		Changed = changed,
		_count = -1,
		_alive = true,
		_conns = {},
	}, TagCache)
	-- The signals are a fast path only; the timer below is what guarantees correctness.
	table.insert(self._conns, CollectionService:GetInstanceAddedSignal(tag):Connect(function()
		self:refresh(true)
	end))
	-- A stream-out plus a stream-in inside one period leaves the count unchanged; mark dirty on removal.
	table.insert(self._conns, CollectionService:GetInstanceRemovedSignal(tag):Connect(function()
		self._count = -1
	end))
	self:refresh(true)
	task.spawn(function()
		while self._alive do
			task.wait(period or 1)
			if self._alive then
				self:refresh(false)
			end
		end
	end)
	return self
end

-- Rebuild when the tagged count changed (cheap check) or when forced.
function TagCache.refresh(self: TagCache, force: boolean)
	local tagged = CollectionService:GetTagged(self.tag)
	if not force and #tagged == self._count then
		return
	end
	self._count = #tagged
	local list, set = {}, {}
	for _, inst in tagged do
		if not self.filter or self.filter(inst) then
			table.insert(list, inst)
			set[inst] = true
		end
	end
	self.list, self.set = list, set
	self.Changed:Fire(list)
end

-- Cleanup hook for per-instance state (rest poses, tweens). Streaming out fires this.
-- For pooled objects: RemoveTag on release and AddTag on acquire, so this runs and state resets.
function TagCache.onRemoved(self: TagCache, fn: (Instance) -> ())
	table.insert(self._conns, CollectionService:GetInstanceRemovedSignal(self.tag):Connect(function(inst)
		self.set[inst] = nil
		fn(inst)
	end))
end

function TagCache.destroy(self: TagCache)
	self._alive = false
	for _, c in self._conns do
		c:Disconnect()
	end
	self.Changed:Destroy()
end

return TagCache
