--!strict
-- Stable starting-equipment regressions; behavior checks use the real projectile modules.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Service = game:GetService("ServerScriptService").Server.Services.WeaponService
local Compute = require(Service.WeaponStats).compute
local function stats(id, tier, bonuses)
	return Compute(assert(Config.Weapons[id], id), tier, bonuses or {}, nil, Config.Player.minWeaponCooldown)
end
local function context(target)
	local serial, effects = 0, {}
	return {
		x = 0,
		z = 0,
		vx = 0,
		vz = 0,
		active = true,
		nearestEnemies = function(_, _, _, _, _, out)
			if target then
				out[1] = 1
				return 1
			end
			return 0
		end,
		enemyPosition = function()
			return 10, 0
		end,
		nextId = function()
			serial += 1
			return serial
		end,
		random = function()
			return 1
		end,
		emit = function(_, _, effect)
			table.insert(effects, effect)
		end,
		effects = effects,
	}
end
local function weapon(id, tier)
	return { uid = 1, id = id, config = Config.Weapons[id], tier = tier, state = {}, stats = stats(id, tier) }
end
describe("Native character starting weapons", function()
	it("connects seven runtime paths with source tier restrictions and keeps pending artwork unavailable", function()
		local Client = folderProxy("src/client", "Client")
		for _, id in
			{ "Anchor", "Mace", "MeatTenderizer", "Machinegun", "PanFlute", "CombatShotgun", "GrenadeLauncher" }
		do
			local w = assert(Config.Weapons[id], id)
			expect(w.behavior).toBe(id)
			expect(w.available).toBe(false)
			expect(Service.Behaviors:FindFirstChild(id) ~= nil).toBe(true)
			expect(Client.Controllers.WeaponRenderer.Visuals:FindFirstChild(id) ~= nil).toBe(true)
			for tier = w.minTier, 4 do
				expect(Config.Shop.weaponTierPrices[id][tier] > 0).toBe(true)
				expect(stats(id, tier).damage > 0).toBe(true)
			end
		end
		expect(Config.Weapons.Anchor.minTier).toBe(2)
		expect(Config.Weapons.CombatShotgun.minTier).toBe(2)
	end)
	it("uses native damage scaling, signed Attack Speed scaling and equipped penalties", function()
		expect(stats("Anchor", 2, { meleeDamage = 10, curse = 4 }).damage).toBe(58)
		expect(stats("Mace", 2, { meleeDamage = 5, attackSpeed = 20 }).damage).toBe(35)
		expect(Config.Weapons.Mace.heldStats[2].attackSpeed).toBe(-3)
		expect(stats("MeatTenderizer", 1, { meleeDamage = 3, hpRegen = 7 }).damage).toBe(25)
		expect(stats("PanFlute", 1, { luck = 100 }).damage).toBe(14)
		expect(Config.Weapons.Machinegun.heldStats[1].speed).toBe(-3)
	end)
	it("fires Machinegun without targets and retains its last aim", function()
		local w, ctx = weapon("Machinegun", 1), context(true)
		local fire = require(Service.Behaviors.Machinegun).fire
		expect(fire(w, ctx)).toBe(true)
		local first = w.state.projectiles[1]
		local empty = context(false)
		expect(fire(w, empty)).toBe(true)
		local last = w.state.projectiles[2]
		expect(last.dx).toBeNear(first.dx)
		expect(last.dz).toBeNear(first.dz)
		expect(require(Service.Behaviors.PanFlute).fire(weapon("PanFlute", 1), empty)).toBe(false)
	end)
	it("keeps the native random radian spread instead of making a wide degree fan", function()
		local w, ctx = weapon("PanFlute", 1), context(true)
		ctx.random = function()
			return 0.5
		end
		expect(require(Service.Behaviors.PanFlute).fire(w, ctx)).toBe(true)
		expect(#w.state.projectiles).toBe(5)
		local x, z = require(Shared.Util.WeaponPose).anchor(0, 0, 1, "PanFlute")
		local dx, dz = 10 - x, -z
		local length = math.sqrt(dx * dx + dz * dz)
		for _, shot in w.state.projectiles do
			expect(shot.dx).toBeNear(dx / length)
			expect(shot.dz).toBeNear(dz / length)
		end
	end)
	it("rounds native reload frames and applies the full negative attack speed factor", function()
		expect(stats("CombatShotgun", 2).reloadSeconds).toBeNear(109 / 60)
		expect(stats("CombatShotgun", 2, { attackSpeed = -100 }).reloadSeconds).toBeNear(218 / 60)
		expect(stats("Machinegun", 1, { attackSpeed = 50 }).cooldown).toBeNear(2 / 60)
		local w, ctx = weapon("Machinegun", 1), context(false)
		local fire = require(Service.Behaviors.Machinegun).fire
		for _ = 1, 60 do
			expect(fire(w, ctx)).toBe(true)
		end
		expect(w.state.reloadLeft).toBeNear(2)
		expect(fire(w, ctx)).toBe(false)
	end)
end)
