--!strict
-- Real lobby pet previews show source descriptions and computed values instead of an empty details panel.
local f = loadHelper("tests/helpers/NativeCharacterFixture.luau")("BeastMaster")
runScript(folderProxy("src/client", "Client"), "init.client.luau")
describe("Native pet tooltip lobby", function()
	it("shows Bonk Dog's damage, original five-second dash and all Beast Master scalings", function()
		f.world.click(f.world.gui("Lobby", "Start"))
		f.world.click(f.world.gui("Lobby", "BeastMaster"))
		f.world.advance(0.1)
		local text = f.world.gui("Lobby", "WeaponStats").Text
		expect(string.find(text, "Spawns a Bonk Dog pet that deals 10", 1, true) ~= nil).toBe(true)
		expect(string.find(text, "Every 5 seconds", 1, true) ~= nil).toBe(true)
		for _, stat in { "Melee Damage", "Ranged Damage", "Elemental Damage", "Engineering" } do
			expect(string.find(text, "60% " .. stat, 1, true) ~= nil).toBe(true)
		end
	end)
	it("keeps the selected Catling Gun's actual description on the difficulty page and after Back", function()
		local details = f.world.gui("Lobby", "WeaponDetails")
		expect(details.AutomaticCanvasSize).toBe(Enum.AutomaticSize.Y)
		details.CanvasPosition = Vector2.new(0, 120)
		f.world.click(f.world.gui("Lobby", "Start_CatlingGun"))
		expect(details.CanvasPosition.Y).toBe(0)
		local text = f.world.gui("Lobby", "WeaponStats").Text
		expect(string.find(text, "shoots bullets dealing 10", 1, true) ~= nil).toBe(true)
		f.world.click(f.world.gui("Lobby", "LobbyBack"))
		expect(f.world.gui("Lobby", "WeaponStats").Text).toBe(text)
		expect(#f.world.errors).toBe(0)
	end)
end)
