--!strict
-- Weapon shot looks: every projectile weapon has its own drawn shape, shots fly, flash and end without errors.

loadHelper("tests/helpers/RobloxMock.luau")

local Shared = game:GetService("ReplicatedStorage").Shared
local ShotLooks = require(Shared.Config.ShotLooks)
local renderer = folderProxy("src/client", "Client").Controllers.WeaponRenderer
local ShotShapes = require(renderer.ShotShapes)
local B7ProjectileVisual = require(renderer.B7ProjectileVisual)

local PROJECTILE_VISUALS = {
	"Blowgun",
	"Blunderbuss",
	"BoomerangAxe",
	"CactiClub",
	"CathedralEngine",
	"ChainGun",
	"ChainLightning",
	"CinderBreath",
	"CombatShotgun",
	"DEXtroyer",
	"Fireball",
	"GalvanicFork",
	"GhostScepter",
	"GrenadeLauncher",
	"HarpoonGun",
	"Javelin",
	"LaserGun",
	"LeechCarbine",
	"Machinegun",
	"Minigun",
	"MortarLantern",
	"NuclearLauncher",
	"Obliterator",
	"PanFlute",
	"ParticleAccelerator",
	"PotatoThrower",
	"Railgun",
	"RattleRepeater",
	"Revolver",
	"ScatterBell",
	"ShrapnelOrgan",
	"Shuriken",
	"Slingshot",
	"SniperGun",
	"SparkBolt",
	"ThunderSword",
	"TranqRifle",
	"WatchmanPistol",
	"WinterNeedle",
}

local function visibleCount(folder): number
	local count = 0
	for _, anchor in folder:GetChildren() do
		local gui = anchor:FindFirstChildWhichIsA("BillboardGui")
		local picture = gui and gui:FindFirstChild("Picture")
		if picture and picture.Visible then
			count += 1
		end
	end
	return count
end

local function frame(folder, number, now)
	return {
		number = number,
		now = now,
		dt = 1 / 60,
		floorY = 100,
		folder = folder,
		move = function(part, cframe)
			part.CFrame = cframe
		end,
		ownerPosition = function()
			return nil
		end,
		evolved = function()
			return false
		end,
	}
end

describe("Weapon shot looks", function()
	it("gives every projectile weapon its own look with a known shape", function()
		local shapes = {
			bullet = true,
			pellet = true,
			laser = true,
			lightning = true,
			orb = true,
			fireball = true,
			flame = true,
			icicle = true,
			arrow = true,
			dart = true,
			harpoon = true,
			thorn = true,
			rock = true,
			potato = true,
			shuriken = true,
			rocket = true,
			grenade = true,
		}
		for _, behavior in PROJECTILE_VISUALS do
			local look = ShotLooks.byBehavior[behavior]
			expect(look ~= nil).toBe(true)
			expect(shapes[look.shape]).toBe(true)
			expect(look.length > 0 and look.width > 0).toBe(true)
		end
	end)

	it("draws glowing shots without the dark rim and solid ones with it", function()
		for _, behavior in { "LaserGun", "GalvanicFork", "SparkBolt", "Fireball", "CinderBreath" } do
			expect(ShotLooks.byBehavior[behavior].rim).toBe(nil)
		end
		for _, behavior in { "WatchmanPistol", "Slingshot", "BoomerangAxe", "MortarLantern" } do
			expect(ShotLooks.byBehavior[behavior].rim).toBe(true)
		end
	end)

	it("builds each shape from rounded pieces", function()
		for _, behavior in PROJECTILE_VISUALS do
			local shot = ShotShapes.build(behavior, ShotShapes.lookOf(behavior))
			expect(#shot.fading > 0).toBe(true)
			expect(shot.sprite.picture.ImageTransparency).toBe(1)
		end
		expect(#ShotShapes.build("Rocket", ShotLooks.byBehavior.MortarLantern).flicker).toBe(1)
		expect(#ShotShapes.muzzleFlash().fading).toBe(3)
	end)

	it("flies, flashes at the barrel and ends for every weapon", function()
		workspace.CurrentCamera.CFrame = CFrame.new(0, 100, 0)
		for _, behavior in PROJECTILE_VISUALS do
			local visual = B7ProjectileVisual(Color3.new(1, 1, 1), behavior)
			local folder = Instance.new("Folder")
			local now = workspace:GetServerTimeNow()
			visual.effect({
				weapon = behavior,
				userId = 1,
				kind = "Fire",
				at = now,
				id = 7,
				x = 0,
				z = 0,
				dx = 1,
				dz = 0,
				speed = 50,
				range = 30,
			})
			visual.render(frame(folder, 1, now + 0.02))
			local shown = visibleCount(folder)
			local expected = if ShotLooks.byBehavior[behavior].muzzle then 2 else 1
			expect(shown).toBe(expected)
			visual.effect({ weapon = behavior, userId = 1, kind = "End", at = now, id = 7, distance = 5 })
			visual.render(frame(folder, 2, now + 0.5))
			expect(visibleCount(folder)).toBe(0)
			visual.clear()
		end
	end)
end)
