-- Unit tests for Config consistency and the remote validators.
-- Run: see README "Für Entwickler".

local Shared = game:GetService("ReplicatedStorage").Shared
local ConfigCheck = require(game:GetService("ServerScriptService").Server.ConfigCheck)
local Remotes = require(Shared.Net.Remotes)
local Validate = require(Shared.Net.Validate)

describe("Config", function()
	it("passes the startup check without problems", function()
		local problems = ConfigCheck.run()
		if #problems > 0 then
			error(table.concat(problems, "\n"))
		end
	end)
end)

describe("Remotes", function()
	it("gives every client intent a rate limit and validators", function()
		for name, definition in Remotes do
			if definition.direction == "toServer" then
				expect(definition.rateLimit ~= nil).toBe(true)
				expect(definition.args ~= nil).toBe(true)
			end
			expect(name ~= "").toBe(true)
		end
	end)

	it("accepts only known classes in SelectClass", function()
		local validator = Remotes.SelectClass.args[1]
		expect(validator("SparkMage")).toBe(true)
		expect(validator("NotAClass")).toBe(false)
		expect(validator(42)).toBe(false)
	end)

	it("accepts only booleans in SetReady", function()
		local validator = Remotes.SetReady.args[1]
		expect(validator(true)).toBe(true)
		expect(validator(false)).toBe(true)
		expect(validator("true")).toBe(false)
		expect(validator(nil)).toBe(false)
	end)

	it("accepts only listed debug commands", function()
		local validator = Remotes.DebugCommand.args[1]
		expect(validator("SkipToBoss")).toBe(true)
		expect(validator("GiveMeEmbers")).toBe(false)
	end)
end)

describe("Validate", function()
	it("keyOf rejects non-strings", function()
		local validator = Validate.keyOf({ a = 1 })
		expect(validator("a")).toBe(true)
		expect(validator(1)).toBe(false)
	end)
end)
