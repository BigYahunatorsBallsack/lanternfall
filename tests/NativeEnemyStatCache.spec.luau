--!strict
-- Source EntityService caches global factors by stat key while applying each caller's own base and boost after the cache.
loadHelper("tests/helpers/RobloxMock.luau")
local S = game:GetService("ServerScriptService").Server.Services
local function cache()
	return require(S.EnemySim.NativeEnemyStatCache).new()
end
local function context()
	return {
		players = { { health = 0, damage = 0, speed = 0, curse = 0, burningSpeed = 0 } },
		danger = { health = 0, damage = 0, speed = 0 },
		accessibility = { health = 1, damage = 1, speed = 1 },
		endless = 0,
		curseEnabled = true,
	}
end
describe("Native source enemy factor cache", function()
	it("converts integer source arguments before factors but leaves damage floating until final rounding", function()
		local c, ctx = cache(), context()
		expect(c:health(6.5, 0, ctx)).toBe(6)
		expect(c:health(6.5, 150, ctx)).toBe(15)
		expect(c:damage(21.2, 30, ctx)).toBe(28)
		ctx.accessibility.speed = 1.014
		expect(c:speed(255, 0, false, ctx)).toBe(259)
		expect(c:speed(255, 50, false, ctx)).toBe(388)
	end)
	it("combines co-op, average Curse and the separate HP/damage endless curves", function()
		local c, ctx = cache(), context()
		ctx.players = {
			{ health = 0, damage = 0, speed = 0, curse = 0, burningSpeed = 0 },
			{ health = 0, damage = 0, speed = 0, curse = 200, burningSpeed = 0 },
		}
		ctx.endless = 2
		expect(c:health(10, 0, ctx)).toBe(130) -- 10*1.3*(1+2*2.25*(1+sqrt(100)/10))
		expect(c:damage(10, 0, ctx)).toBe(41) -- round(10*1.08*(1+2*(1+sqrt(100)/25)))
	end)
	it("multiplies each player's speed factor and applies accessibility, danger and endless speed", function()
		local c, ctx = cache(), context()
		ctx.players = {
			{ health = 0, damage = 0, speed = 10, curse = 0, burningSpeed = 0 },
			{ health = 0, damage = 0, speed = -20, curse = 0, burningSpeed = 0 },
		}
		ctx.accessibility.speed, ctx.danger.speed, ctx.endless = 0.75, 10, 2
		expect(c:speed(200, 0, false, ctx)).toBe(167)
	end)
	it("floors individual speed stats before burning additions and preserves the source first-caller cache", function()
		local c, ctx = cache(), context()
		ctx.players[1].speed, ctx.players[1].burningSpeed = -100, -50
		expect(c:speed(100, 0, true, ctx)).toBe(-25) -- (-75-50)% -> -.25, no final speed clamp in source
		expect(c:speed(100, 0, false, ctx)).toBe(-25)
		c:clear()
		expect(c:speed(100, 0, false, ctx)).toBe(25)
	end)
	it("keeps independent cached stat keys until explicit clear, without caching per-call bases or boosts", function()
		local c, ctx = cache(), context()
		expect(c:health(10, 0, ctx)).toBe(10)
		ctx.players[1].health = 100
		ctx.players[1].damage = 100
		expect(c:health(20, 50, ctx)).toBe(30)
		expect(c:damage(20, 0, ctx)).toBe(40) -- damage key first use sees the changed context
		ctx.players[1].damage = 200
		expect(c:damage(30, 50, ctx)).toBe(90)
		c:clear()
		expect(c:health(10, 0, ctx)).toBe(20)
		expect(c:damage(10, 0, ctx)).toBe(30)
	end)
	it("uses the source .01 HP/damage minima, while speed boost has no such clamp", function()
		local c, ctx = cache(), context()
		ctx.players[1].health, ctx.players[1].damage = -200, -200
		expect(c:health(10000, -200, ctx)).toBe(1)
		expect(c:damage(10000, -200, ctx)).toBe(1)
		expect(c:speed(100, -150, false, ctx)).toBe(-50)
	end)
	it("ignores negative average Curse and absent Curse effects without changing the endless baseline", function()
		local c, ctx = cache(), context()
		ctx.players[1].curse, ctx.endless = -100, 2
		expect(c:health(100, 0, ctx)).toBe(550)
		expect(c:damage(100, 0, ctx)).toBe(300)
		c:clear()
		ctx.players[1].curse, ctx.curseEnabled = 10000, false
		expect(c:health(100, 0, ctx)).toBe(550)
		expect(c:damage(100, 0, ctx)).toBe(300)
	end)
	it("caps only the endless speed addition at1.75 and preserves independent cache instances", function()
		local a, b, ctx = cache(), cache(), context()
		ctx.endless = 100
		expect(a:speed(100, 0, false, ctx)).toBe(275)
		ctx.endless = 0
		expect(a:speed(100, 0, false, ctx)).toBe(275)
		expect(b:speed(100, 0, false, ctx)).toBe(100)
	end)
end)
