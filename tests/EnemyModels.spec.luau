-- Enemy looks (client EnemyRenderer/Models): every type builds within the part budget, hidden parts and low-detail
-- trims are not moved, and a charger's rush path only shows during its wind-up.

loadHelper("tests/helpers/RobloxMock.luau")

local Models = require(folderProxy("src/client", "Client").Controllers.EnemyRenderer.Models)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local MAX_PARTS = 20 -- per plain enemy (DESIGN.md section 15)
local MAX_ELITE_PARTS = 25

local function posed(visual)
	return Models.pose(visual, CFrame.new(0, 0, 0), 0.5, 1, 1, 0.3, {}, {}, 0)
end

local function partNamed(visual, name)
	for _, part in visual.parts do
		if part.Name == name then
			return part
		end
	end
	return nil
end

describe("EnemyModels", function()
	it("builds every enemy type and its elite within the part budget", function()
		for id, kind in Config.Enemies.types do
			local visual = Models.build(kind.typeId)
			expect(visual.model.Name).toBe(id)
			expect(#visual.parts <= MAX_PARTS).toBe(true)
			for _, part in visual.parts do
				expect(part.Anchored and not part.CanCollide and not part.CanQuery).toBe(true)
			end
			local elite = Models.build(kind.typeId + Config.Enemies.elite.typeIdOffset)
			expect(elite.model.Name).toBe(`Elite{id}`)
			expect(#elite.parts <= MAX_ELITE_PARTS).toBe(true)
		end
	end)

	it("builds every boss and champion with its glow within the elite part budget (WP10)", function()
		local kinds = {}
		for _, kind in Config.Enemies.bosses do
			table.insert(kinds, kind)
		end
		for _, kind in Config.Enemies.champions do
			table.insert(kinds, kind)
		end
		expect(#kinds).toBe(10)
		for _, kind in kinds do
			local visual = Models.build(kind.typeId)
			expect(visual.model.Name).toBe(kind.id)
			expect(#visual.parts <= MAX_ELITE_PARTS).toBe(true)
			local lit = false
			for _, object in visual.model:GetDescendants() do
				lit = lit or object.ClassName == "PointLight"
			end
			expect(lit).toBe(true)
		end
	end)

	it("leaves out the small trims in low detail and brings them back", function()
		local visual = Models.build(Config.Enemies.types.Shadeling.typeId)
		local full = posed(visual)
		expect(full).toBe(#visual.parts)
		Models.setDetail(visual, true)
		local low = posed(visual)
		expect(low < full).toBe(true)
		local claw = partNamed(visual, "ClawLeft")
		expect(claw.LocalTransparencyModifier).toBe(1)
		expect(partNamed(visual, "Mask").LocalTransparencyModifier).toBe(0) -- the silhouette stays
		Models.setDetail(visual, false)
		expect(posed(visual)).toBe(full)
		expect(claw.LocalTransparencyModifier).toBe(0)
	end)

	it("does not move parts that are hidden", function()
		local charger = Models.build(Config.Enemies.types.Charger.typeId)
		local walking = posed(charger)
		Models.setMode(charger, Models.MODE_WINDUP)
		expect(posed(charger)).toBe(walking + 1) -- the rush path
		Models.setMode(charger, Models.MODE_RUSH)
		expect(posed(charger)).toBe(walking)

		local elite = Models.build(Config.Enemies.types.Brute.typeId + Config.Enemies.elite.typeIdOffset)
		local plain = posed(elite)
		for index, info in Config.Enemies.elite.affixes do
			Models.setAffix(elite, index)
			local expected = if info.id == "Summoner" then plain + 2 else plain -- two summoning wisps
			expect(posed(elite)).toBe(expected)
		end
	end)
end)
