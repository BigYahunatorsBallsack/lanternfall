--!strict
-- Audited source TeamEvolution probabilities, camp means and EvolutionSceneEffect boost formulas; production wiring remains pending.
loadHelper("tests/helpers/RobloxMock.luau")
local E = require(game:GetService("ServerScriptService").Server.Services.SpawnDirector.NativeEnemyEvolution)
local function player(value, chance, dual)
	return { evolution = value, chanceStat = chance or 0, dual = dual or false }
end
describe("Native enemy team evolution", function()
	it("keeps an empty team inert without consuming a camp roll", function()
		local t = E.team({}, 0)
		local calls = 0
		expect(t.chance).toBe(0)
		expect(t.eliteChance).toBe(0)
		expect(E.hasCamp(t)).toBe(false)
		expect(E.drawMeca(t, function()
			calls += 1
			return 0
		end)).toBe(false)
		expect(calls).toBe(0)
	end)
	it("uses the actual saturation curve and separately capped elite chance", function()
		local t = E.team({ player(50) }, 0)
		expect(t.chance).toBeNear(0.25)
		expect(t.eliteChance).toBe(1)
		expect(t.mecaWeight).toBe(50)
		expect(t.mecaMagnitude).toBe(50)
		expect(t.mutantWeight).toBe(0)
	end)
	it("averages chances over every player and magnitudes over each participating camp", function()
		local t = E.team({ player(50), player(-100), player(0) }, 0)
		expect(t.chance).toBeNear(7 / 36)
		expect(t.eliteChance).toBeNear(2 / 3)
		expect(t.mecaMagnitude).toBe(50)
		expect(t.mutantMagnitude).toBe(100)
		expect(t.mecaWeight).toBe(50)
		expect(t.mutantWeight).toBe(100)
	end)
	it("adds nonzero dual evolution to both camp means regardless of its sign", function()
		local t = E.team({ player(10), player(30), player(-50, 0, true), player(0, 0, true) }, 0)
		expect(t.mecaWeight).toBe(90)
		expect(t.mutantWeight).toBe(50)
		expect(t.mecaMagnitude).toBe(30)
		expect(t.mutantMagnitude).toBe(50)
	end)
	it("applies chance modifiers and endless before per-player caps without changing magnitudes", function()
		expect(E.team({ player(50, 100) }, 0).chance).toBeNear(1 / 3)
		expect(E.team({ player(50, -200) }, 0).chance).toBeNear(0.25)
		local zero = E.team({ player(50, -100) }, 0)
		expect(zero.chance).toBe(0)
		expect(E.hasCamp(zero)).toBe(true)
		local endless = E.team({ player(50), player(0) }, 1000)
		expect(endless.chance).toBeNear(0.5)
		expect(endless.eliteChance).toBeNear(0.5)
		expect(endless.mecaMagnitude).toBe(50)
	end)
	it("retains the strict weighted boundary and source RNG consumption even for a single camp", function()
		local t = E.team({ player(50), player(-100) }, 0)
		expect(E.drawMeca(t, function()
			return 1 / 3
		end)).toBe(false)
		expect(E.drawMeca(t, function()
			return 0
		end)).toBe(true)
		local calls = 0
		expect(E.drawMeca(E.team({ player(50) }, 0), function()
			calls += 1
			return 1
		end)).toBe(false)
		expect(calls).toBe(1)
	end)
end)

describe("Source scene evolution selection", function()
	local function actor(role, changes)
		local a = {
			role = role or "Ordinary",
			lootStatsMatched = false,
			zoneEvolvedElites = false,
			meca = false,
			mutant = false,
			motherMeca = false,
			motherMutant = false,
		}
		for k, v in changes or {} do
			a[k] = v
		end
		return a
	end
	local positive = E.team({ player(50) }, 0)
	local empty = E.team({}, 0)
	local function noRoll()
		error("Source must not ask for a decision/roll on this branch")
	end
	it("excludes current-zone loot stats before any role or inherited flags", function()
		expect(E.select(positive, actor("Boss", { lootStatsMatched = true, meca = true }), noRoll, noRoll)).toBe(nil)
	end)
	it("makes a foot inherit its mother without rerolling or requiring a player camp", function()
		expect(E.select(empty, actor("Foot", { motherMeca = true, motherMutant = true }), noRoll, noRoll)).toBe("Meca")
		expect(E.select(empty, actor("Foot", { motherMutant = true }), noRoll, noRoll)).toBe("Mutant")
		expect(E.select(positive, actor("Foot"), noRoll, noRoll)).toBe(nil)
	end)
	it("uses primary team chance for ordinary bosses before inspecting existing flags", function()
		local called = 0
		local choice = E.select(positive, actor("Boss", { meca = true }), function(chance)
			expect(chance).toBeNear(0.25)
			called += 1
			return false
		end, noRoll)
		expect(choice).toBe(nil)
		expect(called).toBe(1)
	end)
	it("uses preselected evolved-zone elite flags and never rerolls an unevolved elite", function()
		expect(E.select(positive, actor("Elite", { zoneEvolvedElites = true }), noRoll, noRoll)).toBe(nil)
		expect(E.select(empty, actor("Elite", { zoneEvolvedElites = true, mutant = true }), noRoll, noRoll)).toBe(
			"Mutant"
		)
		expect(
			E.select(empty, actor("Elite", { zoneEvolvedElites = true, meca = true, mutant = true }), noRoll, noRoll)
		).toBe("Meca")
	end)
	it("honors inherited ordinary flags before checking for any current player camp", function()
		expect(E.select(empty, actor(nil, { meca = true }), noRoll, noRoll)).toBe("Meca")
		expect(E.select(empty, actor(nil, { mutant = true }), noRoll, noRoll)).toBe("Mutant")
		expect(E.select(empty, actor(), noRoll, noRoll)).toBe(nil)
	end)
	it("does not confuse a boost refusal with the source loot-stat exclusion", function()
		local a = actor(nil, { canBeBoosted = false })
		expect(E.select(positive, a, function(chance)
			expect(chance).toBeNear(0.25)
			return true
		end, function()
			return 0
		end)).toBe("Meca")
	end)
	it("lets an elite outside evolved zones follow the ordinary primary-chance branch", function()
		expect(E.select(positive, actor("Elite"), function(chance)
			expect(chance).toBeNear(0.25)
			return true
		end, function()
			return 0
		end)).toBe("Meca")
	end)
end)
describe("Source evolution boost percentages", function()
	it("caps Meca magnitude rather than the final HP percentage", function()
		local low = E.boost(true, 0)
		expect(low.hp).toBe(50)
		expect(low.damage).toBe(25)
		expect(low.speed).toBe(5)
		local high = E.boost(true, 999)
		expect(high.hp).toBe(650)
		expect(high.damage).toBe(50)
		expect(high.speed).toBe(25)
	end)
	it("keeps Mutant damage linear through150 while speed saturates at100", function()
		local middle = E.boost(false, 100)
		expect(middle.hp).toBe(265)
		expect(middle.damage).toBe(58)
		expect(middle.speed).toBe(25)
		local full = E.boost(false, 150)
		expect(full.hp).toBe(385)
		expect(full.damage).toBe(80)
		local capped = E.boost(false, 999)
		expect(capped.hp).toBe(745)
	end)
	it("uses Meca integer truncation but Mutant rounding for fractional HP magnitudes", function()
		expect(E.boost(true, 1.9).hp).toBe(52)
		expect(E.boost(false, 1.9).hp).toBe(30)
	end)
end)
