--!strict
-- Nightmare event execution through production services and the real projectile renderer; NativeNightmareSelection tests the public access gate.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch")
runScript(folderProxy("src/client", "Client"), "init.client.luau")
local Hell = require(f.S.BulletHellService)
local Danger = require(f.S.DangerService)
local Enemies = require(f.S.EnemySim)
local Feed = require(f.Shared.Net.ShotFeed)
local Renderer = require(folderProxy("src/client", "Client").Controllers.EnemyShotRenderer)
local originalOptions = f.Run.getRunOptions
local fired = {}
f.world.getRemote("EnemyShots").OnClientEvent:Connect(function(packet)
	for _, shot in Feed.decode(packet).fired do
		if shot.motion then
			table.insert(fired, shot)
		end
	end
end)
describe("Native bullet hell service", function()
	it("does not activate environmental projectiles in ordinary runs", function()
		f.start(f.class.startWeapons[1])
		f.world.advance(5)
		expect(Hell.isActive()).toBe(false)
		expect(#fired).toBe(0)
		expect(#f.Config.Difficulty.levels).toBe(7)
		expect(#f.world.errors).toBe(0)
	end)
	it("executes one of the actual early projectile waves and sends renderable curved shots", function()
		-- Isolate projectile execution from saved progression; the public access gate has its own real-flow tests.
		f.Run.getRunOptions = function()
			local options = originalOptions()
			options.danger = 6
			return options
		end
		f.start(f.class.startWeapons[1])
		if Danger.getNightmareEvent(1) ~= "bullet_hell" then
			f.nextWave()
		end
		expect(Danger.getNightmareEvent(f.Run.getWave())).toBe("bullet_hell")
		f.world.advance(7, 1 / 60)
		expect(Hell.isActive()).toBe(true)
		expect(#fired > 0).toBe(true)
		expect(Enemies.getShotCount() > 0).toBe(true)
		expect(Renderer.getCount() > 0).toBe(true)
		local Motion = require(f.Shared.Util.NativeBulletMotion)
		local now = workspace:GetServerTimeNow()
		local matched = false
		for _, part in workspace:FindFirstChild("LanternfallEnemyShots"):GetChildren() do
			if not part:IsA("BasePart") then
				continue
			end
			local position = part.CFrame.Position
			for _, shot in fired do
				local ox, oz = Motion.offset(math.max(0, now - shot.at), shot.dx, shot.dz, shot.speed, shot.motion)
				if math.abs(position.X - shot.x - ox) < 0.001 and math.abs(position.Z - shot.z - oz) < 0.001 then
					matched = true
				end
			end
		end
		expect(matched).toBe(true)
		local motion = fired[1].motion
		expect(motion.amplitudeX ~= 0 or motion.amplitudeZ ~= 0).toBe(true)
		expect(#f.world.errors).toBe(0)
	end)
	it("keeps the event plan stable and suppresses projectiles on a fog wave", function()
		local events = {}
		for wave = 1, 20 do
			events[wave] = Danger.getNightmareEvent(wave)
		end
		for wave = 1, 20 do
			expect(Danger.getNightmareEvent(wave)).toBe(events[wave])
		end
		local fog = 5
		while events[fog] ~= "fog_of_war" do
			fog += 1
		end
		while f.Run.getWave() < fog do
			f.nextWave()
		end
		f.world.advance(7)
		expect(Hell.isActive()).toBe(false)
		expect(Enemies.getShotCount()).toBe(0)
		expect(Renderer.getCount()).toBe(0)
		expect(#f.world.errors).toBe(0)
	end)
	it("clears lifecycle state and all environmental shots at the run end", function()
		assert(f.Run.endRun("Abandoned"))
		f.world.advance(0.1)
		expect(Hell.isActive()).toBe(false)
		expect(Enemies.getShotCount()).toBe(0)
		expect(Renderer.getCount()).toBe(0)
		expect(#f.world.errors).toBe(0)
	end)
end)
