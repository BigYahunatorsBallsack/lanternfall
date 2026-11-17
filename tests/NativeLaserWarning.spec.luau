--!strict
-- A lasting laser warning stays a line after the ordinary flash interval rather than changing into a pool disc.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("NightWatch")
runScript(folderProxy("src/client", "Client"), "init.client.luau")
f.start("WatchmanPistol")
f.Weapons.setPaused(true)
describe("Native laser fallback warning", function()
	it("keeps its full visible strip through the active beam interval", function()
		local now = workspace:GetServerTimeNow()
		local warnings = {
			{
				shape = "Line",
				x = 40,
				z = 40,
				dx = 1,
				dz = 0,
				length = 60,
				radius = 2,
				startsAt = now,
				hitsAt = now + 0.1,
				endsAt = now + 1.2,
			},
		}
		require(f.Shared.Net).fireClient("BossTelegraphs", f.me, warnings)
		f.world.advance(0.4)
		local folder = assert(workspace:FindFirstChild("LanternfallBoss"))
		local visible = false
		for _, part in folder:GetDescendants() do
			if part:IsA("BasePart") and part.Transparency < 1 and math.abs(part.Size.Z - 60) < 1e-6 then
				visible = true
			end
		end
		expect(visible).toBe(true)
	end)
end)
