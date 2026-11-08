--!strict
-- Unit tests for WeaponService/WeaponTarget: a weapon keeps its enemy until it leaves range or another one is clearly
-- closer (Config.Combat.originalWeapons.targetSwitchRatio), so held weapons stop flicking between enemies.

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Services = game:GetService("ServerScriptService").Server.Services
local WeaponTarget = require(Services.WeaponService.WeaponTarget)

local RATIO = Config.Combat.originalWeapons.targetSwitchRatio

-- A context with enemies at fixed spots around an owner at the origin.
local function context(enemies: { [number]: { number } })
	local ctx = { x = 0, z = 0 }
	function ctx.nearestEnemies(_, x: number, z: number, range: number, maxCount: number, out: { number }): number
		local list = {}
		for id, spot in enemies do
			local distance = math.sqrt((spot[1] - x) ^ 2 + (spot[2] - z) ^ 2)
			if distance <= range then
				table.insert(list, { id = id, distance = distance })
			end
		end
		table.sort(list, function(a, b)
			return a.distance < b.distance
		end)
		local count = math.min(#list, maxCount)
		for k = 1, count do
			out[k] = list[k].id
		end
		return count
	end
	function ctx.enemyPosition(_, id: number): (number?, number?)
		local spot = enemies[id]
		if not spot then
			return nil, nil
		end
		return spot[1], spot[2]
	end
	return ctx :: any
end

describe("WeaponTarget", function()
	it("picks the nearest enemy first and keeps it while another is only a little closer", function()
		local weapon = { state = {} } :: any
		local enemies = { [1] = { 10, 0 }, [2] = { 0, 12 } }
		local out = {}
		expect(WeaponTarget.pick(weapon, context(enemies), 20, 1, out)).toBe(1)
		expect(out[1]).toBe(1)
		-- enemy 2 comes a bit closer than enemy 1, but not under the switch ratio: stay on enemy 1
		enemies[2] = { 0, 10 * RATIO + 0.5 }
		WeaponTarget.pick(weapon, context(enemies), 20, 1, out)
		expect(out[1]).toBe(1)
		-- clearly closer: switch
		enemies[2] = { 0, 10 * RATIO - 0.5 }
		WeaponTarget.pick(weapon, context(enemies), 20, 1, out)
		expect(out[1]).toBe(2)
	end)

	it("drops the kept enemy once it is dead or out of range", function()
		local weapon = { state = {} } :: any
		local enemies = { [1] = { 5, 0 }, [2] = { 0, 9 } }
		local out = {}
		WeaponTarget.pick(weapon, context(enemies), 10, 1, out)
		expect(out[1]).toBe(1)
		enemies[1] = { 15, 0 }
		WeaponTarget.pick(weapon, context(enemies), 10, 1, out)
		expect(out[1]).toBe(2)
		enemies[2] = nil
		expect(WeaponTarget.pick(weapon, context(enemies), 10, 1, out)).toBe(0)
		expect(weapon.state.targetId).toBe(nil)
	end)

	it("returns at most the asked number of targets, kept one first", function()
		local weapon = { state = { targetId = 3 } } :: any
		local enemies = { [1] = { 6, 0 }, [2] = { 7, 0 }, [3] = { 8, 0 } }
		local out = {}
		expect(WeaponTarget.pick(weapon, context(enemies), 20, 2, out)).toBe(2)
		expect(out[1]).toBe(3)
		expect(out[2]).toBe(1)
	end)
end)
