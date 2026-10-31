--!strict
-- In-memory stand-in for ProfileStore with the calls PlayerDataService uses (StartSessionAsync, Profile.Data,
-- AddUserId, Reconcile, Save, EndSession, IsActive, OnSessionEnd; since Paket 16 LastSavedData and OnAfterSave). PlayerDataService uses it when the place has no
-- DataStoreService (the test runner); tests/PlayerData.spec.luau also uses it to refuse a load or to end a session
-- as if another server took it. Data lives only as long as the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in value do
		copy[key] = deepCopy(item)
	end
	return copy
end

-- Adds keys that are missing in target from template, like ProfileStore's Reconcile.
local function reconcile(target: any, template: any)
	for key, value in template do
		if type(key) == "string" then
			if target[key] == nil then
				target[key] = deepCopy(value)
			elseif type(target[key]) == "table" and type(value) == "table" then
				reconcile(target[key], value)
			end
		end
	end
end

local Profile = {}
Profile.__index = Profile

local MemoryStore = {}
MemoryStore.__index = MemoryStore

function MemoryStore.new(template: any)
	return setmetatable({
		template = template,
		saved = {} :: { [string]: any }, -- what the "DataStore" holds per key
		active = {} :: { [string]: any }, -- open sessions per key
		refused = {} :: { [string]: boolean },
		saves = 0, -- how often anything was written (tests)
		failing = false, -- tests: saves do nothing, like a DataStore outage (Paket 16)
	}, MemoryStore)
end

function MemoryStore.StartSessionAsync(self: any, key: string, params: any?): any
	if self.refused[key] then
		return nil
	end
	if params and params.Cancel and params.Cancel() then
		return nil
	end
	local old = self.active[key]
	if old then -- like ProfileStore: a new session takes over a locked profile, the old one ends
		old:_finish()
	end
	local stored = self.saved[key]
	local profile = setmetatable({
		Data = if stored then deepCopy(stored) else deepCopy(self.template),
		LastSavedData = if stored then deepCopy(stored) else deepCopy(self.template),
		Key = key,
		UserIds = {},
		OnSessionEnd = Signal.new(),
		OnAfterSave = Signal.new(),
		store = self,
		active = true,
	}, Profile)
	self.active[key] = profile
	return profile
end

-- Tests: StartSessionAsync for this key returns nil (DataStore down or locked for too long).
function MemoryStore.refuse(self: any, key: string, refused: boolean)
	self.refused[key] = refused or nil
end

-- Tests: what is stored for a key right now (a copy).
function MemoryStore.peek(self: any, key: string): any
	return deepCopy(self.saved[key])
end

-- Tests: put data under a key, e.g. an old schema version.
function MemoryStore.put(self: any, key: string, data: any)
	self.saved[key] = deepCopy(data)
end

-- Tests: while failing, saves write nothing and OnAfterSave stays quiet (Paket 16: receipts wait for a save).
function MemoryStore.setFailing(self: any, failing: boolean)
	self.failing = failing
end

-- Tests: another server opens the profile; this server's session ends.
function MemoryStore.takeOver(self: any, key: string)
	local profile = self.active[key]
	if profile then
		profile:_finish()
	end
end

function Profile.IsActive(self: any): boolean
	return self.active
end

function Profile.AddUserId(self: any, userId: number)
	if not table.find(self.UserIds, userId) then
		table.insert(self.UserIds, userId)
	end
end

function Profile.Reconcile(self: any)
	reconcile(self.Data, self.store.template)
end

function Profile.Save(self: any)
	if self.active and not self.store.failing then
		self.store.saved[self.Key] = deepCopy(self.Data)
		self.store.saves += 1
		self.LastSavedData = deepCopy(self.Data)
		self.OnAfterSave:Fire(self.LastSavedData)
	end
end

function Profile._finish(self: any)
	if not self.active then
		return
	end
	self:Save()
	self.active = false
	if self.store.active[self.Key] == self then
		self.store.active[self.Key] = nil
	end
	self.OnSessionEnd:Fire()
end

function Profile.EndSession(self: any)
	self:_finish()
end

return MemoryStore
