--!strict
-- Original character text/icon ordering, native wrapping contracts and safe replacement through the real UI helpers.
local world = loadHelper("tests/helpers/RobloxMock.luau")
world.addPlayer("Owner", 1, true)
local Client = folderProxy("src/client", "Client")
local RuleText = require(Client.UI.CharacterRuleText)
local Images = require(Client.UI.StatImages)
local rows = {
	{ { text = "+20 Max HP" } },
	{
		{ text = "You explode for 30 (" },
		{ stat = "meleeDamage", coefficient = 300 },
		{ text = ") damage when you take damage" },
	},
}

local function holder()
	local parent = Instance.new("Frame")
	parent.Size = UDim2.fromOffset(360, 0)
	return parent
end

local function ordered(parent)
	local result = {}
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			table.insert(result, child)
		end
	end
	table.sort(result, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	return result
end

describe("Native character rule display", function()
	it("preserves original words, line order and atomic coefficient/icon order", function()
		local parent = holder()
		RuleText.render(parent, rows, 17)
		local lines = ordered(parent)
		expect(#lines).toBe(2)
		expect(lines[1].LayoutOrder).toBe(1)
		expect(lines[2].LayoutOrder).toBe(2)
		local text = ""
		local stat
		for _, part in ordered(lines[2]) do
			if part:IsA("TextLabel") then
				text ..= part.Text
			else
				stat = part
				text ..= "[scaling]"
			end
		end
		expect(text).toBe("You explode for 30 ([scaling]) damage when you take damage")
		assert(stat)
		local scaling = ordered(stat)
		expect(scaling[1].Text).toBe("300%")
		expect(scaling[2].Illustration:GetAttribute("IconKey")).toBe("stat:meleeDamage")
		expect(scaling[2].Illustration.StatArt.Image).toBe(Images.meleeDamage)
	end)

	it("uses content-sized words and wrapped rows which follow a narrow parent", function()
		local parent = holder()
		RuleText.render(parent, rows, 17)
		expect(parent.AutomaticSize).toBe(Enum.AutomaticSize.Y)
		expect(parent.Size.X.Offset).toBe(360)
		expect(parent.Size.Y.Offset).toBe(0)
		expect(parent:FindFirstChildOfClass("UIListLayout").FillDirection).toBe(Enum.FillDirection.Vertical)
		for _, row in ordered(parent) do
			expect(row.AutomaticSize).toBe(Enum.AutomaticSize.Y)
			expect(row.Size.X.Scale).toBe(1)
			local flow = row:FindFirstChildOfClass("UIListLayout")
			expect(flow.FillDirection).toBe(Enum.FillDirection.Horizontal)
			expect(flow.Wraps).toBe(true)
			for _, part in ordered(row) do
				expect(part.AutomaticSize).toBe(Enum.AutomaticSize.X)
			end
		end
		parent.Size = UDim2.fromOffset(128, 0)
		for _, row in ordered(parent) do
			expect(row.Size.X.Scale).toBe(1)
			expect(row:FindFirstChildOfClass("UIListLayout").Wraps).toBe(true)
		end
	end)

	it("replaces old rows and icons instead of duplicating them on render", function()
		local parent = holder()
		RuleText.render(parent, rows, 17)
		local old = ordered(parent)[2]
		RuleText.render(parent, { { { stat = "rangedDamage", coefficient = 50 } } }, 20)
		expect(old.Parent).toBe(nil)
		expect(#ordered(parent)).toBe(1)
		expect(#parent:GetChildren()).toBe(2) -- one layout and one row
		local stat = ordered(ordered(parent)[1])[1]
		local scaling = ordered(stat)
		expect(scaling[1].Text).toBe("50%")
		expect(scaling[2].Illustration.StatArt.Image).toBe(Images.rangedDamage)
	end)

	it("clears the dedicated parent and collapses its minimum height", function()
		local parent = holder()
		RuleText.render(parent, rows, 17)
		RuleText.clear(parent)
		expect(#parent:GetChildren()).toBe(0)
		expect(parent.Size.X.Offset).toBe(360)
		expect(parent.Size.Y.Offset).toBe(0)
		RuleText.clear(parent)
		expect(#parent:GetChildren()).toBe(0)
	end)

	it("supports an icon without a coefficient and rejects an unknown original stat image", function()
		local parent = holder()
		RuleText.render(parent, { { { stat = "elementalDamage" } } }, 17)
		local stat = ordered(ordered(parent)[1])[1]
		local children = ordered(stat)
		expect(#children).toBe(1)
		expect(children[1].Illustration.StatArt.Image).toBe(Images.elementalDamage)
		local ok = pcall(function()
			RuleText.render(parent, { { { stat = "ForgedStat" } } }, 17)
		end)
		expect(ok).toBe(false)
		world.advance(0.1)
		expect(#world.errors).toBe(0)
	end)

	it("retains explicit spacing between adjacent scaling groups", function()
		local parent = holder()
		RuleText.render(parent, {
			{
				{ stat = "meleeDamage", coefficient = 300 },
				{ text = " " },
				{ stat = "rangedDamage", coefficient = 300 },
			},
		}, 17)
		local parts = ordered(ordered(parent)[1])
		expect(#parts).toBe(3)
		expect(parts[2].Text).toBe(" ")
		expect(parts[1].Stat.Illustration.StatArt.Image).toBe(Images.meleeDamage)
		expect(parts[3].Stat.Illustration.StatArt.Image).toBe(Images.rangedDamage)
	end)
end)
