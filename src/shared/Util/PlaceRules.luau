--!strict
-- Pure rules for the hub and run places (Paket 15): which place a server is, the tickets a teleport carries and how
-- quick join forms a group. Used by PlaceService, PartyService and RunPlaceService; unit-tested in
-- tests/PlaceRules.spec.luau.
--
-- A ticket is the teleport data (TeleportOptions:SetTeleportData). It passes through the client, so the receiving
-- server checks every field here and then validates characters, weapons and the danger level like lobby input.

local DangerRules = require(script.Parent.DangerRules)
local Types = require(script.Parent.Parent.Net.Types)

export type Role = "Hub" | "Run" | "Single"

export type Experience = { name: string, hub: number, run: number }

-- What a player's character choice was in the hub.
export type Pick = { classId: string, weaponId: string? }

-- Hub -> run place: the group, its options and everyone's picks.
export type RunTicket = {
	partyId: string, -- names the group, so the hub can put the party back together afterwards
	leader: number,
	group: { number }, -- userIds, in order
	options: Types.RunOptions,
	picks: { [number]: Pick },
	hubJobId: string?, -- the hub server they came from; "Back to hub" tries to return there
}

-- Run place -> hub: the party to rebuild.
export type HubTicket = {
	partyId: string,
	leader: number,
	group: { number },
}

local TICKET_VERSION = 1
local MAX_ID_LENGTH = 64

local PlaceRules = {}

-- Which place `placeId` is: the hub or run place of a listed experience, otherwise "Single" (lobby and arena in one
-- server, like before Paket 15). Ids of 0 are not set yet and never match.
function PlaceRules.resolve(placeId: number?, experiences: { Experience }): (Role, Experience?)
	if not placeId or placeId == 0 then
		return "Single", nil
	end
	for _, experience in experiences do
		if experience.hub == placeId and experience.run ~= 0 then
			return "Hub", experience
		elseif experience.run == placeId and experience.hub ~= 0 then
			return "Run", experience
		end
	end
	return "Single", nil
end

local function isUserId(value: any): boolean
	return typeof(value) == "number" and value == math.floor(value) and value > 0 and value < 2 ^ 53
end

local function isId(value: any): boolean
	return typeof(value) == "string" and #value > 0 and #value <= MAX_ID_LENGTH
end

local function isFiniteNumber(value: any): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- A list of 1..maxSize different userIds, or nil.
local function readGroup(value: any, maxSize: number): { number }?
	if typeof(value) ~= "table" then
		return nil
	end
	local group = {}
	local seen = {}
	for index = 1, maxSize + 1 do
		local userId = value[index]
		if userId == nil then
			break
		end
		if index > maxSize or not isUserId(userId) or seen[userId] then
			return nil
		end
		seen[userId] = true
		table.insert(group, userId)
	end
	return if #group > 0 then group else nil
end

-- Run options from untrusted data: missing or broken fields fall back to the defaults, then DangerRules.clean.
function PlaceRules.readOptions(value: any): Types.RunOptions
	local options = DangerRules.defaultOptions()
	if typeof(value) == "table" then
		for _, key in { "danger", "enemyHp", "enemyDamage", "enemySpeed", "enemyCount" } do
			if isFiniteNumber(value[key]) then
				(options :: any)[key] = value[key]
			end
		end
		options.endless = value.endless == true
	end
	return DangerRules.clean(options)
end

local function writeOptions(options: Types.RunOptions): { [string]: any }
	return {
		danger = options.danger,
		endless = options.endless,
		enemyHp = options.enemyHp,
		enemyDamage = options.enemyDamage,
		enemySpeed = options.enemySpeed,
		enemyCount = options.enemyCount,
	}
end

-- Teleport data for the run place. Picks are keyed by tostring(userId): teleport data must not mix key types.
function PlaceRules.runTicket(ticket: RunTicket): { [string]: any }
	local picks = {}
	for userId, pick in ticket.picks do
		picks[tostring(userId)] = { classId = pick.classId, weaponId = pick.weaponId }
	end
	return {
		lf = TICKET_VERSION,
		kind = "Run",
		partyId = ticket.partyId,
		leader = ticket.leader,
		group = table.clone(ticket.group),
		options = writeOptions(ticket.options),
		picks = picks,
		hubJobId = ticket.hubJobId,
	}
end

-- Reads the teleport data a player arrived with on the run place; nil if it is no valid run ticket for `userId`.
-- `isClass(id)` and `isWeapon(id)` tell known ids (Config); a pick with unknown ids is left out, not the ticket.
function PlaceRules.parseRunTicket(
	data: any,
	userId: number,
	maxSize: number,
	isClass: (string) -> boolean,
	isWeapon: (string) -> boolean
): RunTicket?
	if typeof(data) ~= "table" or data.lf ~= TICKET_VERSION or data.kind ~= "Run" then
		return nil
	end
	local group = readGroup(data.group, maxSize)
	if not group or not table.find(group, userId) or not isId(data.partyId) then
		return nil
	end
	local leader = if isUserId(data.leader) and table.find(group, data.leader) then data.leader else group[1]
	local picks: { [number]: Pick } = {}
	if typeof(data.picks) == "table" then
		for _, member in group do
			local pick = data.picks[tostring(member)]
			if typeof(pick) == "table" and typeof(pick.classId) == "string" and isClass(pick.classId) then
				local weaponId = pick.weaponId
				picks[member] = {
					classId = pick.classId,
					weaponId = if typeof(weaponId) == "string" and isWeapon(weaponId) then weaponId else nil,
				}
			end
		end
	end
	return {
		partyId = data.partyId,
		leader = leader,
		group = group,
		options = PlaceRules.readOptions(data.options),
		picks = picks,
		hubJobId = if isId(data.hubJobId) then data.hubJobId else nil,
	}
end

-- Teleport data for the way back to the hub.
function PlaceRules.hubTicket(ticket: HubTicket): { [string]: any }
	return {
		lf = TICKET_VERSION,
		kind = "Hub",
		partyId = ticket.partyId,
		leader = ticket.leader,
		group = table.clone(ticket.group),
	}
end

function PlaceRules.parseHubTicket(data: any, userId: number, maxSize: number): HubTicket?
	if typeof(data) ~= "table" or data.lf ~= TICKET_VERSION or data.kind ~= "Hub" then
		return nil
	end
	local group = readGroup(data.group, maxSize)
	if not group or not table.find(group, userId) or not isId(data.partyId) then
		return nil
	end
	local leader = if isUserId(data.leader) and table.find(group, data.leader) then data.leader else group[1]
	return { partyId = data.partyId, leader = leader, group = group }
end

-- Quick join: the queue's entries in arrival order (a solo player or a whole party, `size` players each) fill the
-- first group, keeping parties together; entries that do not fit wait for the next group. Returns the entries of
-- the first group and its player count.
function PlaceRules.quickGroup(entries: { { id: number, size: number } }, maxSize: number): ({ number }, number)
	local ids = {}
	local total = 0
	for _, entry in entries do
		if total + entry.size <= maxSize then
			table.insert(ids, entry.id)
			total += entry.size
			if total == maxSize then
				break
			end
		end
	end
	return ids, total
end

-- Quick join groups play the lowest danger level any of their leaders picked, with default sliders (assumption:
-- nobody is pulled above the level they chose).
function PlaceRules.quickOptions(dangers: { number }): Types.RunOptions
	local options = DangerRules.defaultOptions()
	local lowest = math.huge
	for _, danger in dangers do
		lowest = math.min(lowest, danger)
	end
	if lowest ~= math.huge then
		options.danger = lowest
	end
	return DangerRules.clean(options)
end

return PlaceRules
