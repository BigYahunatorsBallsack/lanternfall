--!strict
-- Native controller config validation remains a concrete alternative to legacy boss plans and rejects missing bindings/ranges.
loadHelper("tests/helpers/RobloxMock.luau")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Check = require(game:GetService("ServerScriptService").Server.ConfigCheck)
local function changed(edit, id)
	id = id or "Therizinosaurus"
	local original = Config.Enemies
	local enemies, champions = table.clone(original), table.clone(original.champions)
	local kind = table.clone(champions[id])
	kind.nativeBoss = table.clone(kind.nativeBoss)
	kind.nativeBoss.shooting = table.clone(kind.nativeBoss.shooting)
	kind.nativeBoss.shooting.profiles = table.clone(kind.nativeBoss.shooting.profiles)
	champions[id], enemies.champions = kind, champions
	edit(kind.nativeBoss)
	Config.Enemies = enemies
	local ok, result = pcall(Check.run)
	Config.Enemies = original
	assert(ok, result)
	return table.concat(result, "\n")
end
describe("Native boss startup validation", function()
	it("rejects a missing independent damage record in a multi-damage native actor", function()
		local errors = changed(function(native)
			native.attacks = table.clone(native.attacks)
			native.attacks[2] = table.clone(native.attacks[2])
			native.attacks[2].damage = nil
		end, "Baryonyx")
		assert(string.find(errors, "attack 2 needs independent source damage", 1, true))
	end)
	it("rejects a negative locked recovery clock", function()
		local errors = changed(function(native)
			native.shooting.profiles[1] = table.clone(native.shooting.profiles[1])
			native.shooting.profiles[1].recoveryFrames = -1
		end, "Baryonyx")
		assert(string.find(errors, "profile 1 needs nonnegative recovery", 1, true))
	end)
	it("rejects a finite spawning clock without the original exhausted cooldown", function()
		local errors = changed(function(native)
			native.shooting.profiles[1] = table.clone(native.shooting.profiles[1])
			native.shooting.profiles[1].exhaustedFrames = nil
		end, "Diplodocus")
		assert(string.find(errors, "finite spawn 1 needs a nonnegative integer cap", 1, true))
	end)
	it("requires projectile geometry only for an actor that actually emits standard bullets", function()
		local errors = changed(function(native)
			native.projectileRadius = nil
		end)
		assert(string.find(errors, "bullet 2 needs range and radius", 1, true))
	end)
	it("accepts the source controller without a fake legacy BossBrain plan", function()
		expect(Config.Enemies.champions.Therizinosaurus.boss).toBe(nil)
		expect(#Check.run()).toBe(0)
	end)
	it("rejects an actor whose independent phase profile is missing", function()
		local errors = changed(function(native)
			native.shooting.profiles = { native.shooting.profiles[1] }
		end)
		assert(string.find(errors, "Native boss Therizinosaurus needs its implemented family", 1, true))
	end)
	it("rejects an invalid source attack range", function()
		local errors = changed(function(native)
			native.shooting.profiles[2] = table.clone(native.shooting.profiles[2])
			native.shooting.profiles[2].maxRange = -1
		end)
		assert(string.find(errors, "profile 2 needs valid speed, cooldown and range", 1, true))
	end)
	it("rejects a Silesaurus whose source movement bindings are missing", function()
		local errors = changed(function(native)
			native.movements = nil
		end, "Silesaurus")
		assert(string.find(errors, "Silesaurus needs all three source movements", 1, true))
	end)
	it("rejects a spawning profile whose source no-range-gate flag is missing", function()
		local errors = changed(function(native)
			native.shooting.profiles[1] = table.clone(native.shooting.profiles[1])
			native.shooting.profiles[1].unrestricted = nil
		end, "Silesaurus")
		assert(string.find(errors, "spawn 1 needs source summon rules", 1, true))
	end)
end)
