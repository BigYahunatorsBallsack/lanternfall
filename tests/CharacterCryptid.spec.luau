--!strict
-- Cryptid's wave-completion unlock, original starts, living-tree rewards and dodge buffs through production services.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Catalog = require(Shared.Config.CharacterCatalog)
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local S = Server.Services
local Run, Stats, Weapons = require(S.RunDirector), require(S.StatService), require(S.WeaponService)
local Enemy, Data, Combat = require(S.EnemySim), require(S.PlayerDataService), require(S.CombatService)
local Shop = require(S.ShopService)
local me, peer = world.addPlayer("Owner", 1, true), world.addPlayer("Peer", 2, false)
local outsider = world.addPlayer("Lobby", 3, false)
world.advance(0.5)
local availability = Config.Classes.Cryptid.available
Config.Classes.Cryptid.available = true
for _, id in Catalog.Cryptid.startWeapons do
	assert(Config.Weapons[id], id).available = true
end
require(S.SpawnDirector).setPaused(true)
require(S.ExperienceService).setPaused(true)
require(S.LootService).setDropsPaused(true)
Run.setHoldWaves(true)
local function start(class, weapon)
	if Run.isOngoing() then
		Run.endRun("Abandoned")
	end
	if Run.getPhase() == "Ended" then
		world.advance(Config.Run.flow.resultsSeconds + 0.1)
	end
	assert(Run.selectClass(me, class))
	if weapon then
		assert(Weapons.selectStartWeapon(me, class, weapon))
	end
	assert(Run.launch({ me, peer }, require(Shared.Util.DangerRules).defaultOptions()))
	world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
	Weapons.setPaused(true)
	Enemy.killAll()
	for _, p in { me, peer } do
		Combat.protect(p, 10000)
	end
	peer.Character.HumanoidRootPart.Position = Vector3.new(200, 0, 200)
end
local function tree()
	return assert(Enemy.spawn("Tree", 40, 40, 1, 1))
end
local function endWave()
	Run.skipTo(require(Shared.Util.RunSchedule).wave(Run.getWave()).endsAt)
	expect(Run.getPhase()).toBe("Shop")
end
describe("Native Cryptid package", function()
	it("requires finishing a wave with ten living trees, rather than merely seeing ten", function()
		expect(Config.Classes.Cryptid.nativeCodeReady).toBe(true)
		expect(availability).toBe(false)
		expect(Run.selectClass(me, "Cryptid")).toBe(false)
		start("NightWatch")
		for _ = 1, 9 do
			tree()
		end
		endWave()
		expect(Data.isUnlocked(me, "characters", "Cryptid")).toBe(false)
		start("NightWatch")
		for _ = 1, 10 do
			tree()
		end
		world.advance(0.2)
		expect(Data.isUnlocked(me, "characters", "Cryptid")).toBe(false)
		Run.endRun("Defeat")
		expect(Data.isUnlocked(me, "characters", "Cryptid")).toBe(false)
		start("NightWatch")
		for _ = 1, 10 do
			tree()
		end
		endWave()
		expect(Data.isUnlocked(me, "characters", "Cryptid")).toBe(true)
		expect(Data.isUnlocked(peer, "characters", "Cryptid")).toBe(true)
		expect(Data.isUnlocked(outsider, "characters", "Cryptid")).toBe(false)
	end)
	it("selects every original starting weapon, including Molotov, and preserves the source penalties", function()
		Data.unlockAll(me)
		for _, id in Catalog.Cryptid.startWeapons do
			start("Cryptid", id)
			expect(Weapons.getWeapons(me)[1].id).toBe(id)
			expect(Stats.getStat(me, "trees")).toBe(6)
			expect(Stats.getStat(me, "dodgeCap")).toBe(70)
			expect(Stats.getStat(me, "lifeSteal")).toBe(-100)
			expect(Stats.getStat(me, "range")).toBe(-100)
		end
	end)
	it("tracks current living trees for regeneration and awards twelve materials and XP per survivor", function()
		start("Cryptid", "BrassKnuckles")
		local first = tree()
		tree()
		tree()
		world.advance(0.2)
		expect(Stats.getStat(me, "hpRegen")).toBe(9)
		Enemy.damage(first, 1000, me)
		world.advance(0.2)
		expect(Stats.getStat(me, "hpRegen")).toBe(6)
		local own, other = Shop.getShards(me), Shop.getShards(peer)
		endWave()
		expect(Shop.getShards(me) - own).toBe(24)
		expect(Shop.getShards(peer) - other).toBe(0)
		expect(require(S.ExperienceService).getLevel(me)).toBe(1)
		expect(require(S.ExperienceService).getProgress(me).xp).toBe(8)
		expect(require(S.ExperienceService).getLevel(peer)).toBe(0)
	end)
	it("adds attack speed per dodge only to its owner and clears the bonus at wave end", function()
		start("Cryptid", "BrassKnuckles")
		local other = Stats.getStat(peer, "attackSpeed")
		for _ = 1, 3 do
			Combat.Dodged:Fire(me)
		end
		expect(Stats.getStat(me, "attackSpeed")).toBe(9)
		expect(Stats.getStat(peer, "attackSpeed")).toBe(other)
		endWave()
		expect(Stats.getStat(me, "attackSpeed")).toBe(0)
	end)
	it("ignites a nearby target from the real Molotov puddle after the weapon has been removed", function()
		for tier = 1, 4 do
			start("Cryptid", "Molotov")
			for _, weapon in Weapons.getWeapons(me) do
				Weapons.removeWeapon(me, weapon.uid)
			end
			assert(Weapons.addWeapon(me, "Molotov", tier))
			Stats.addStats(me, { critChance = -100 })
			local at = me.Character.HumanoidRootPart.Position
			local a = assert(Enemy.spawn("Brute", at.X + 12, at.Z, 1000, 1, nil, nil, 0))
			local b = assert(Enemy.spawn("Brute", at.X + 12, at.Z + 4, 1000, 1, nil, nil, 0))
			local aHp, bHp = Enemy.getHealth(a), Enemy.getHealth(b)
			Weapons.setPaused(false)
			world.advance(0.4)
			for _, w in Weapons.getWeapons(me) do
				Weapons.removeWeapon(me, w.uid)
			end
			expect(Enemy.getHealth(a) < aHp).toBe(true)
			expect(Enemy.getHealth(b)).toBe(bHp)
			local hp = Enemy.getHealth(b)
			world.advance(1.1)
			expect(Enemy.getHealth(b) < hp).toBe(true)
			expect(#world.errors).toBe(0)
		end
	end)
	it("applies the enemy-material penalty through the existing cooperative drop calculation", function()
		start("Cryptid", "BrassKnuckles")
		local random = require(S.RandomService)
		local original = random.number
		local xp = require(S.ExperienceService)
		xp.setPaused(false)
		expect(require(Shared.Util.CharacterEconomy).materialValue(1, { "Cryptid", "NightWatch" }, true)).toBeNear(
			1.073076923076923
		) -- native two-player material factor before the averaged -25% penalty
		local lastValue
		local connection = world.getRemote("XpOrbs").OnClientEvent:Connect(function(events)
			for index = 4, #events.orbs, 4 do
				lastValue = events.orbs[index]
			end
		end)
		local ok, err = pcall(function()
			for _, roll in { 0.99, 0.01 } do
				random.number = function(channel, player)
					return if channel == "Loot" then roll else original(channel, player)
				end
				lastValue = nil
				local before = xp.getOrbCount()
				local id = assert(Enemy.spawn("Shadeling", 40, 40, 1, 1))
				Enemy.damage(id, 1000, me)
				expect(xp.getOrbCount() - before).toBe(1)
				world.advance(0.2)
				expect(lastValue).toBe(if roll == 0.99 then 1 else 2)
			end
		end)
		connection:Disconnect()
		random.number = original
		xp.setPaused(true)
		assert(ok, err)
	end)
	it("adds Scared Sausage to intrinsic burning and previews the native integer rounding", function()
		start("Cryptid", "Molotov")
		assert(Stats.addItem(me, "SmolderingWick"))
		assert(Stats.addItem(me, "SmolderingWick"))
		assert(Stats.addStats(me, { elementalDamage = 1.5, damage = 50 }))
		local weapon = Weapons.getWeapons(me)[1]
		expect(weapon.stats.burnDamage).toBe(9)
		local sheet
		world.getRemote("Stats").OnClientEvent:Connect(function(value)
			sheet = value
		end)
		assert(Stats.addStats(me, { luck = 1 }))
		local ui = require(folderProxy("src/client", "Client").UI.OfferText)
		expect(ui.stats("Molotov", 1, sheet).burnDamage).toBe(9)
		local _, text = ui.weapon("Molotov", 1, sheet)
		expect(text:find("4x9", 1, true) ~= nil).toBe(true)
	end)
end)
