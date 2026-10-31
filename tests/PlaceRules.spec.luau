-- Unit tests for Util/PlaceRules (Paket 15): which place a server is, the teleport tickets between hub and run place
-- (also tampered ones) and how quick join forms a group.

local Shared = game:GetService("ReplicatedStorage").Shared
local DangerRules = require(Shared.Util.DangerRules)
local PlaceRules = require(Shared.Util.PlaceRules)

local EXPERIENCES = {
	{ name = "Test", hub = 111, run = 222 },
	{ name = "Half", hub = 333, run = 0 },
}

local function isClass(id)
	return id == "BladeWarden" or id == "SparkMage"
end

local function isWeapon(id)
	return id == "SparkBolt" or id == "Blade"
end

local function ticket()
	local options = DangerRules.defaultOptions()
	options.danger = 3
	options.endless = true
	return {
		partyId = "party-1",
		leader = 7,
		group = { 7, 8 },
		options = options,
		picks = { [7] = { classId = "SparkMage", weaponId = "SparkBolt" }, [8] = { classId = "BladeWarden" } },
		hubJobId = "job-abc",
	}
end

describe("which place", function()
	it("knows the hub and the run place of an experience", function()
		expect((PlaceRules.resolve(111, EXPERIENCES))).toBe("Hub")
		expect((PlaceRules.resolve(222, EXPERIENCES))).toBe("Run")
		local _, experience = PlaceRules.resolve(222, EXPERIENCES)
		expect(experience.hub).toBe(111)
	end)

	it("runs everything in one server for unknown, unset and half-set places", function()
		expect((PlaceRules.resolve(0, EXPERIENCES))).toBe("Single")
		expect((PlaceRules.resolve(nil, EXPERIENCES))).toBe("Single")
		expect((PlaceRules.resolve(999, EXPERIENCES))).toBe("Single")
		expect((PlaceRules.resolve(333, EXPERIENCES))).toBe("Single") -- no run place yet
	end)
end)

describe("run ticket", function()
	it("survives the trip as teleport data", function()
		local data = PlaceRules.runTicket(ticket())
		expect(data.picks["7"].classId).toBe("SparkMage") -- string keys only
		local parsed = PlaceRules.parseRunTicket(data, 8, 4, isClass, isWeapon)
		expect(parsed ~= nil).toBe(true)
		expect(parsed.partyId).toBe("party-1")
		expect(parsed.leader).toBe(7)
		expect(#parsed.group).toBe(2)
		expect(parsed.options.danger).toBe(3)
		expect(parsed.options.endless).toBe(true)
		expect(parsed.picks[7].weaponId).toBe("SparkBolt")
		expect(parsed.picks[8].classId).toBe("BladeWarden")
		expect(parsed.picks[8].weaponId).toBe(nil)
		expect(parsed.hubJobId).toBe("job-abc")
	end)

	it("refuses tickets for someone else, of another kind or version, and broken groups", function()
		local data = PlaceRules.runTicket(ticket())
		expect(PlaceRules.parseRunTicket(data, 9, 4, isClass, isWeapon)).toBe(nil)
		expect(PlaceRules.parseRunTicket(nil, 7, 4, isClass, isWeapon)).toBe(nil)
		expect(PlaceRules.parseRunTicket("x", 7, 4, isClass, isWeapon)).toBe(nil)
		local wrongKind = PlaceRules.runTicket(ticket())
		wrongKind.kind = "Hub"
		expect(PlaceRules.parseRunTicket(wrongKind, 7, 4, isClass, isWeapon)).toBe(nil)
		local oldVersion = PlaceRules.runTicket(ticket())
		oldVersion.lf = 99
		expect(PlaceRules.parseRunTicket(oldVersion, 7, 4, isClass, isWeapon)).toBe(nil)
		local tooBig = PlaceRules.runTicket(ticket())
		tooBig.group = { 7, 8, 9, 10, 11 }
		expect(PlaceRules.parseRunTicket(tooBig, 7, 4, isClass, isWeapon)).toBe(nil)
		local twice = PlaceRules.runTicket(ticket())
		twice.group = { 7, 7 }
		expect(PlaceRules.parseRunTicket(twice, 7, 4, isClass, isWeapon)).toBe(nil)
		local strange = PlaceRules.runTicket(ticket())
		strange.group = { 7, "8" }
		expect(PlaceRules.parseRunTicket(strange, 7, 4, isClass, isWeapon)).toBe(nil)
		local noParty = PlaceRules.runTicket(ticket())
		noParty.partyId = string.rep("x", 200)
		expect(PlaceRules.parseRunTicket(noParty, 7, 4, isClass, isWeapon)).toBe(nil)
	end)

	it("cleans tampered options and drops unknown picks", function()
		local data = PlaceRules.runTicket(ticket())
		data.options = { danger = 99, endless = "yes", enemyHp = 0 / 0, enemyDamage = math.huge, enemySpeed = "fast" }
		data.picks["7"] = { classId = "Hacker", weaponId = "SparkBolt" }
		data.picks["8"] = { classId = "BladeWarden", weaponId = "Nuke" }
		data.leader = 12345
		local parsed = PlaceRules.parseRunTicket(data, 7, 4, isClass, isWeapon)
		local defaults = DangerRules.defaultOptions()
		expect(parsed.options.danger).toBe(5) -- clamped to the highest level; the run place caps it per player
		expect(parsed.options.endless).toBe(false)
		expect(parsed.options.enemyHp).toBe(defaults.enemyHp)
		expect(parsed.options.enemyDamage).toBe(defaults.enemyDamage)
		expect(parsed.options.enemySpeed).toBe(defaults.enemySpeed)
		expect(parsed.picks[7]).toBe(nil)
		expect(parsed.picks[8].classId).toBe("BladeWarden")
		expect(parsed.picks[8].weaponId).toBe(nil)
		expect(parsed.leader).toBe(7) -- a leader outside the group falls back to the first member
	end)
end)

describe("hub ticket", function()
	it("carries the party back", function()
		local data = PlaceRules.hubTicket({ partyId = "party-1", leader = 8, group = { 7, 8 } })
		local parsed = PlaceRules.parseHubTicket(data, 7, 4)
		expect(parsed.partyId).toBe("party-1")
		expect(parsed.leader).toBe(8)
		expect(PlaceRules.parseHubTicket(data, 9, 4)).toBe(nil)
		expect(PlaceRules.parseHubTicket(PlaceRules.runTicket(ticket()), 7, 4)).toBe(nil)
	end)
end)

describe("quick join", function()
	it("fills a group in arrival order and keeps parties together", function()
		local ids, total =
			PlaceRules.quickGroup({ { id = 1, size = 1 }, { id = 2, size = 3 }, { id = 3, size = 2 } }, 4)
		expect(#ids).toBe(2)
		expect(ids[1]).toBe(1)
		expect(ids[2]).toBe(2)
		expect(total).toBe(4)
		ids, total = PlaceRules.quickGroup({ { id = 1, size = 3 }, { id = 2, size = 2 }, { id = 3, size = 1 } }, 4)
		expect(#ids).toBe(2) -- the party of 2 waits, the solo player fills the group
		expect(ids[2]).toBe(3)
		expect(total).toBe(4)
		ids, total = PlaceRules.quickGroup({}, 4)
		expect(#ids).toBe(0)
		expect(total).toBe(0)
	end)

	it("plays the lowest danger level of the group", function()
		expect(PlaceRules.quickOptions({ 3, 1, 4 }).danger).toBe(1)
		expect(PlaceRules.quickOptions({ 2 }).endless).toBe(false)
		expect(PlaceRules.quickOptions({}).danger).toBe(DangerRules.defaultOptions().danger)
	end)
end)
