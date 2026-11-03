-- Enemy looks (client EnemyRenderer/Models): every type builds within the part budget, hidden parts and low-detail
-- trims are not moved, and a charger's rush path only shows during its wind-up.

loadHelper("tests/helpers/RobloxMock.luau")

local Models = require(folderProxy("src/client", "Client").Controllers.EnemyRenderer.Models)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local EnemyKinds = require(game:GetService("ReplicatedStorage").Shared.Util.EnemyKinds)
local Catalog = require(folderProxy("src/client", "Client").Controllers.EnemyRenderer.MeshCatalog)

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
			expect(next(visual.meshSkins) ~= nil).toBe(true)
			for _, part in visual.parts do
				expect(part.Anchored and not part.CanCollide and not part.CanQuery and not part.CanTouch).toBe(true)
			end
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
		local claw = partNamed(visual, "Fins")
		expect(claw.LocalTransparencyModifier).toBe(1)
		expect(partNamed(visual, "Body").LocalTransparencyModifier).toBe(0) -- the silhouette stays
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

	it("preserves authored mesh proportions and moves each limb through the shared rig", function()
		local catalog = require(folderProxy("src/client", "Client").Controllers.EnemyRenderer.MeshCatalog)
		for id, look in catalog do
			local kind = EnemyKinds.get(id)
			assert(kind)
			local visual = Models.build(kind.typeId)
			local motions = {}
			for i, part in visual.parts do
				motions[visual.anims[i]] = true
				local skin = visual.meshSkins[part]
				if not skin then
					continue
				end
				local item
				for _, candidate in look.pieces do
					if candidate.name == part.Name then
						item = candidate
					end
				end
				assert(item)
				expect(skin.mesh.MeshType).toBe(Enum.MeshType.FileMesh)
				expect(skin.mesh.MeshId:match("^rbxassetid://%d+$") ~= nil).toBe(true)
				expect(skin.mesh.TextureId:match("^rbxassetid://%d+$") ~= nil).toBe(true)
				expect(skin.mesh.Scale.X * item.meshSize.X).toBeNear(part.Size.X)
				expect(skin.mesh.Scale.Y * item.meshSize.Y).toBeNear(part.Size.Y)
				expect(skin.mesh.Scale.Z * item.meshSize.Z).toBeNear(part.Size.Z)
			end
			local expected = {
				Shadeling = { 2, 5, 6 },
				Brute = { 2, 5, 6 },
				Spitter = { 2, 7 },
				Charger = { 2, 3, 4 },
				Splitling = { 2, 5, 6 },
				AbyssShadeling = { 2, 5, 6 },
				AbyssBrute = { 2, 5, 6 },
				Stalker = { 2, 5, 6 },
				Skulker = { 2, 7 },
				Thornback = { 2, 3, 4 },
				Looter = { 2 },
				Gobbler = { 2, 3, 4, 5, 6 },
				Reaper = { 2, 3, 4, 5, 6 },
				Herald = { 2, 7 },
				Mender = { 2, 7 },
				Splitter = { 2 },
				BroodEgg = { 2 },
				Tree = { 2 },
				LanternEater = { 2, 3, 4, 5, 6 },
				HollowSeer = { 2, 7 },
				Abbot = { 2, 7 },
				MireJaw = { 2, 3, 4, 5, 6 },
				Monolith = { 2, 3, 4, 5, 6 },
				StoneSeraph = { 2, 7 },
				BrassRam = { 2, 3, 4 },
				Flayer = { 2, 5, 6 },
				SickleWraith = { 2, 3, 4, 5, 6 },
				BroodMatron = { 2, 3, 4 },
			}
			assert(expected[id], id .. " has no movement expectation")
			for _, motion in expected[id] do
				expect(motions[motion]).toBe(true)
			end
		end
	end)

	it("restores textured looks after hit flashes, status effects and pool reuse", function()
		for id in Catalog do
			local kind = EnemyKinds.get(id)
			assert(kind)
			local visual = Models.build(kind.typeId)
			local original = {}
			local materials = {}
			for part, skin in visual.meshSkins do
				original[part] = skin.mesh.VertexColor
				materials[part] = part.Material
			end
			Models.setStatus(visual, true, true, true)
			Models.setFlash(visual, true)
			for _, skin in visual.meshSkins do
				expect(skin.mesh.TextureId).toBe("")
			end
			Models.setFlash(visual, false)
			for part, skin in visual.meshSkins do
				expect(skin.mesh.TextureId).toBe(skin.texture)
				expect(skin.mesh.VertexColor.X).toBe(part.Color.R)
				expect(skin.mesh.VertexColor.Z < skin.mesh.VertexColor.X).toBe(true)
			end
			Models.reset(visual)
			for part, skin in visual.meshSkins do
				expect(part.Material).toBe(materials[part])
				expect(skin.mesh.TextureId).toBe(skin.texture)
				expect(skin.mesh.VertexColor.X).toBe(original[part].X)
				expect(skin.mesh.VertexColor.Y).toBe(original[part].Y)
				expect(skin.mesh.VertexColor.Z).toBe(original[part].Z)
			end
		end
	end)

	it("keeps mesh armor recognizable through a hit and restores it when its affix changes", function()
		local armored
		for i, info in Config.Enemies.elite.affixes do
			if info.id == "Armored" then
				armored = i
			end
		end
		assert(armored)
		for id in Config.Enemies.types do
			if id == "Tree" then
				continue
			end
			local visual = Models.build(Config.Enemies.types[id].typeId + Config.Enemies.elite.typeIdOffset)
			Models.setAffix(visual, armored)
			local armorCount = 0
			for part, skin in visual.meshSkins do
				if not skin.armor then
					continue
				end
				armorCount += 1
				local steel = part.Color
				expect(part.Material).toBe(Enum.Material.Metal)
				Models.setFlash(visual, true)
				Models.setFlash(visual, false)
				expect(part.Color).toBe(steel)
				expect(skin.mesh.VertexColor.X).toBe(steel.R)
				Models.setAffix(visual, 0)
				expect(part.Material).toBe(Enum.Material.SmoothPlastic)
				expect(part.Color == steel).toBe(false)
				Models.setAffix(visual, armored)
			end
			expect(armorCount > 0).toBe(true)
		end
	end)
	it("uses authored anatomy for every ordinary enemy and preserves each warning footprint", function()
		for _, kind in Config.Enemies.types do
			if kind.id == "Tree" then
				continue
			end
			local visual = Models.build(kind.typeId)
			expect(next(visual.meshSkins) ~= nil).toBe(true)
			if not (kind.pulse or kind.slash or kind.charge) then
				continue
			end
			local warning = visual.telegraph
			assert(warning)
			if kind.pulse then
				expect(warning.Size.Y).toBeNear(kind.pulse.radius * 2)
			elseif kind.slash then
				expect(warning.Size.Y).toBeNear((kind.slash.radius + Config.Simulation.playerRadius) * 2)
			end
			local before = posed(visual)
			Models.setMode(visual, Models.MODE_WINDUP)
			expect(posed(visual)).toBe(before + 1)
			expect(warning.Transparency < 1).toBe(true)
			Models.reset(visual)
			expect(warning.Transparency).toBe(1)
			expect(posed(visual)).toBe(before)
		end
	end)

	it("keeps anchored eggs still while rendering a moving crowd", function()
		for _, id in { "BroodEgg" } do
			local kind = EnemyKinds.get(id)
			assert(kind)
			local visual = Models.build(kind.typeId)
			local a, b = {}, {}
			Models.pose(visual, CFrame.new(), 0, 1, 0, 0, {}, a, 0)
			Models.pose(visual, CFrame.new(), 1.7, 1, 3, 1, {}, b, 0)
			for i, frame in a do
				expect(frame.Position.X).toBeNear(b[i].Position.X)
				expect(frame.Position.Y).toBeNear(b[i].Position.Y)
				expect(frame.Position.Z).toBeNear(b[i].Position.Z)
			end
		end
	end)

	it(
		"preloads every ordinary, boss and champion look and cleans up temporary models even on fetch failure",
		function()
			local provider = game:GetService("ContentProvider")
			for _, fails in { false, true } do
				local captured
				rawset(provider, "PreloadAsync", function(_, models)
					captured = models
					if fails then
						error("simulated content fetch failure")
					end
				end)
				local ok, err = pcall(Models.preload)
				rawset(provider, "PreloadAsync", nil)
				assert(ok, tostring(err))
				assert(captured)
				expect(#captured).toBe(27)
				local seen = {}
				for _, model in captured do
					seen[model.Name] = true
					expect(#model:GetChildren()).toBe(0)
				end
				for id in Catalog do
					expect(seen[id]).toBe(true)
				end
			end
		end
	)
end)
