--!strict
-- Tests the bitmap API boundary and allocation fallback; mock calls do not claim real device/EditableImage acceptance.
local world = loadHelper("tests/helpers/RobloxMock.luau")
-- The lightweight mock omits this existing engine constant.
Vector2.zero = Vector2.new(0, 0)
local Client = folderProxy("src/client", "Client")
local Surface = require(Client.Controllers.NativeFogController.Surface)
local Sources = require(Client.Controllers.NativeFogController.Sources)
local Shared = game:GetService("ReplicatedStorage").Shared
local Raster = require(Shared.Util.NativeFogRaster)
local Asset = game:GetService("AssetService")
describe("Native fog surface", function()
	it("writes exactly one RGBA buffer to a blank in-memory image and destroys it", function()
		local destroyed, writes = false, 0
		local allocated
		local image = {
			WritePixelsBuffer = function(_, origin, size, pixels)
				expect(origin.X).toBe(0)
				expect(origin.Y).toBe(0)
				expect(size.X).toBe(192)
				expect(size.Y).toBe(108)
				expect(buffer.len(pixels)).toBe(192 * 108 * 4)
				writes += 1
			end,
			Destroy = function()
				destroyed = true
			end,
		}
		Asset.CreateEditableImage = function(_, options)
			allocated = options.Size
			return image
		end
		_G.Content = {
			fromObject = function(value)
				expect(value).toBe(image)
				return "mock-in-memory-content"
			end,
		}
		local parent = Instance.new("Frame")
		local surface = Surface.new(parent, 16 / 9)
		expect(surface.bitmap).toBe(true)
		expect(allocated.X).toBe(192)
		surface.write(Raster.draw(surface.width, surface.height, 20, {}))
		expect(writes).toBe(1)
		expect(#parent:GetChildren()).toBe(1)
		surface.destroy()
		expect(destroyed).toBe(true)
		expect(#parent:GetChildren()).toBe(0)
	end)
	it("renders and frees GUI fallback cells when the device image budget returns nil", function()
		Asset.CreateEditableImage = function()
			return nil
		end
		local parent = Instance.new("Frame")
		local surface = Surface.new(parent, 16 / 9)
		expect(surface.bitmap).toBe(false)
		expect(surface.height).toBe(36)
		expect(#parent:GetChildren()).toBe(64 * 36)
		surface.write(Raster.draw(64, 36, 20, {}))
		for _, cell in parent:GetChildren() do
			expect(cell.BackgroundTransparency).toBe(0)
		end
		surface.destroy()
		expect(#parent:GetChildren()).toBe(0)
	end)
	it("collects real blast events, ignores puddles, fades and clears them when fog stops", function()
		local Explosion = require(Client.Controllers.WeaponRenderer.Visuals.Explosion)
		local Fire = require(Client.Controllers.WeaponRenderer.Visuals.FirePuddle)
		Sources.setEnabled(true)
		Explosion.effect({ kind = "Blast", x = 10, z = 20, radius = 1, at = 100 })
		Fire.effect({ kind = "Puddle", x = 30, z = 40, radius = 1, duration = 2, at = 100 })
		local function values(at)
			local result = {}
			Sources.visit(at, function(x, z, kind, age, fade)
				result[kind] = { x = x, z = z, age = age, fade = fade }
			end)
			return result
		end
		local lights = values(100.375)
		expect(lights.structure.fade).toBe(0.5)
		expect(lights.structure.x).toBe(10)
		expect(lights.fire).toBe(nil)
		expect(values(100.5).structure).toBe(nil)
		Explosion.effect({ kind = "Blast", x = 0, z = 0, radius = 1, at = 103 })
		Sources.setEnabled(false)
		expect(next(values(103))).toBe(nil)
		expect(#world.errors).toBe(0)
	end)
end)
