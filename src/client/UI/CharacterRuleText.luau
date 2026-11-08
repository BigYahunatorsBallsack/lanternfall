--!strict
-- CharacterChoice renders native rule words and inline stat artwork with rows that wrap to their parent width.
local Widgets = require(script.Parent.Widgets)
local Icons = require(script.Parent.Icons)
local StatImages = require(script.Parent.StatImages)

export type Token = { text: string?, stat: string?, coefficient: number? }
local RuleText = {}

function RuleText.clear(parent: Frame)
	for _, child in parent:GetChildren() do
		child:Destroy()
	end
	parent.AutomaticSize = Enum.AutomaticSize.Y
	parent.Size = UDim2.new(parent.Size.X.Scale, parent.Size.X.Offset, 0, 0)
end

local function flow(parent: Frame, direction: Enum.FillDirection, wraps: boolean): UIListLayout
	return Widgets.create("UIListLayout", {
		FillDirection = direction,
		Wraps = wraps,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		ItemLineAlignment = Enum.ItemLineAlignment.Center,
		Padding = UDim.new(0, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

local function word(parent: Frame, text: string, order: number, textSize: number): TextLabel
	return Widgets.label({
		Name = `Word{order}`,
		Text = text,
		TextSize = textSize,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, textSize + 4),
		LayoutOrder = order,
		Parent = parent,
	})
end

function RuleText.render(parent: Frame, rows: { { Token } }, textSize: number)
	RuleText.clear(parent)
	flow(parent, Enum.FillDirection.Vertical, false).Padding = UDim.new(0, 3)
	for rowIndex, tokens in rows do
		local row = Widgets.create("Frame", {
			Name = `Row{rowIndex}`,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, textSize + 4),
			LayoutOrder = rowIndex,
			Parent = parent,
		})
		-- Roblox's native flex wrapping responds to parent resizing without estimated word widths or listeners.
		flow(row, Enum.FillDirection.Horizontal, true)
		local order = 0
		for _, token in tokens do
			if token.stat then
				assert(StatImages[token.stat], `No original stat image for character rule {token.stat}`)
				order += 1
				local scaling = Widgets.create("Frame", {
					Name = `Scaling{order}`,
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, textSize + 4),
					LayoutOrder = order,
					Parent = row,
				})
				flow(scaling, Enum.FillDirection.Horizontal, false)
				if token.coefficient ~= nil then
					word(scaling, `{token.coefficient}%`, 1, textSize).Name = "Coefficient"
				end
				local holder = Icons.holder(scaling, textSize + 3, 2)
				holder.Name = "Stat"
				Icons.draw(holder, "stat", token.stat)
			elseif token.text then
				-- Keep punctuation/spacing while breaking sentences at word boundaries for native line wrapping.
				if token.text ~= "" and not token.text:find("%S") then
					order += 1
					word(row, token.text, order, textSize)
				else
					for leading, text, trailing in token.text:gmatch("(%s*)(%S+)(%s*)") do
						order += 1
						word(row, leading .. text .. trailing, order, textSize)
					end
				end
			end
		end
	end
end

return RuleText
