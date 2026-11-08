--!strict
-- Doctor's complete code package and all three starts; real art remains gated outside this fixture.
local world = loadHelper("tests/helpers/RobloxMock.luau")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Server = game:GetService("ServerScriptService").Server
runScript(Server, "init.server.luau")
local S = Server.Services
local Run, Stats, Weapons = require(S.RunDirector), require(S.StatService), require(S.WeaponService)
local Combat, Enemy, Data = require(S.CombatService), require(S.EnemySim), require(S.PlayerDataService)
local me, peer = world.addPlayer("Doctor", 1, true), world.addPlayer("Peer", 2, false)
world.advance(0.5)
local originalAvailability = Config.Classes.Doctor.available
Config.Classes.Doctor.available = true
Config.Weapons.MeatTenderizer.available = true -- local artwork upload is deliberately absent in production
Data.get(me).achievements[require(Shared.Util.CharacterAccess).challengeKey("chal_medicine")] = true
Data.refresh(me)
Run.setHoldWaves(true)
local function start(id)
	if Run.isOngoing() then
		Run.endRun("Abandoned")
	end
	if Run.getPhase() == "Ended" then
		world.advance(Config.Run.flow.resultsSeconds + 0.1)
	end
	assert(Run.selectClass(me, "Doctor"))
	assert(Weapons.selectStartWeapon(me, "Doctor", id))
	assert(Run.launch({ me, peer }, require(Shared.Util.DangerRules).defaultOptions()))
	world.advance(Config.Run.flow.allReadyCountdownSeconds + 0.5)
	require(S.SpawnDirector).setPaused(true)
	Enemy.killAll()
	Combat.protect(me, 10000)
	Combat.protect(peer, 10000)
	peer.Character.HumanoidRootPart.Position = Vector3.new(200, 0, 200)
end
describe("Native Doctor package", function()
	it("declares ready code and exact rules without exposing unuploaded character art", function()
		expect(Config.Classes.Doctor.nativeCodeReady).toBe(true)
		expect(originalAvailability).toBe(false)
		expect(#Config.Classes.Doctor.startWeapons).toBe(3)
		expect(Config.Classes.Doctor.description:find("+200 %% Attack Speed with Medical weapons") ~= nil).toBe(true)
	end)
	it("starts and deals damage with every original weapon", function()
		for _, id in { "Scissors", "LeechCarbine", "MeatTenderizer" } do
			start(id)
			expect(Weapons.getWeapons(me)[1].id).toBe(id)
			expect(Stats.getStat(me, "hpRegen")).toBe(5)
			expect(Stats.getStat(me, "harvesting")).toBe(5)
			expect(Stats.getStat(me, "attackSpeed")).toBe(-100)
			local position = me.Character.HumanoidRootPart.Position
			local target = assert(Enemy.spawn("Brute", position.X + 5, position.Z, 100, 1, nil, nil, 0))
			local hp = Enemy.getHealth(target)
			world.advance(2)
			expect(Enemy.getHealth(target) < hp).toBe(true)
			expect(Weapons.getDamageStats(me)[id].damage > 0).toBe(true)
		end
	end)
	it("doubles regeneration gains, halves Armor gains and keeps medical Attack Speed local", function()
		assert(Stats.addStats(me, { hpRegen = 3, armor = 4 }))
		expect(Stats.getStat(me, "hpRegen")).toBe(11)
		expect(Stats.getStat(me, "armor")).toBe(2)
		expect(Stats.getStat(peer, "hpRegen")).toBe(0)
		local Compute = require(S.WeaponService.WeaponStats).compute
		local sheet = require(Shared.Util.CharacterRules).weaponSheet("Doctor", Stats.getSheet(me))
		local base = Compute(Config.Weapons.Scissors, 1, {}, nil, Config.Player.minWeaponCooldown)
		local medical = Compute(Config.Weapons.Scissors, 1, sheet, nil, Config.Player.minWeaponCooldown)
		local plain = Compute(Config.Weapons.WatchmanPistol, 1, {}, nil, Config.Player.minWeaponCooldown)
		local ordinary = Compute(Config.Weapons.WatchmanPistol, 1, sheet, nil, Config.Player.minWeaponCooldown)
		expect(medical.cooldown).toBeNear(base.cooldown / 2)
		expect(ordinary.cooldown).toBeNear(plain.cooldown * 2)
		Enemy.killAll()
		Combat.drainPlayer(me, 2)
		local hp = Combat.getHp(me)
		world.advance(1 / require(Shared.Util.StatMath).regenPerSecond(11) + 0.02)
		expect(Combat.getHp(me)).toBe(hp + 1)
		expect(#world.errors).toBe(0)
	end)
end)
