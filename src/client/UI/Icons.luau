--!strict
-- Scalable UI illustrations with uploaded character, weapon, and item art.
local Widgets = require(script.Parent.Widgets)
local Theme = require(script.Parent.Theme)
local WeaponImages = require(script.Parent.WeaponImages)
local ContentProvider = game:GetService("ContentProvider")
local CharacterPortraits = require(script.Parent.CharacterPortraits)
local ItemImages = require(script.Parent.ItemImages)
local StatImages = require(script.Parent.StatImages)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local PrimaryStatArt = require(script.Parent.PrimaryStatArt)
local Icons = {}
local rgb = Color3.fromRGB
local INK, IVORY, GOLD = Theme.stroke, rgb(236, 231, 206), rgb(221, 174, 80)
local palettes = {
	CandleScholar = rgb(190, 154, 211),
	DuelMaestro = rgb(197, 126, 114),
	FarSeer = rgb(130, 178, 176),
	ManyHands = rgb(201, 170, 122),
	MarbleHost = rgb(174, 169, 160),
	NightWatch = rgb(131, 153, 193),
	SoleConductor = rgb(170, 135, 198),
	SparkMage = rgb(115, 180, 202),
	TwinLedger = rgb(204, 182, 103),
}

local function shape(
	root: Frame,
	x: number,
	y: number,
	w: number,
	h: number,
	color: Color3,
	turn: number?,
	round: number?,
	outline: boolean?
): Frame
	local frame = Widgets.create("Frame", {
		Name = "InkShape",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x / 100, y / 100),
		Size = UDim2.fromScale(w / 100, h / 100),
		Rotation = turn or 0,
		Parent = root,
	})
	if round then
		Widgets.corner(UDim.new(round, 0)).Parent = frame
	end
	if outline ~= false then
		Widgets.create("UIStroke", { Color = INK, Thickness = 2, Parent = frame })
	end
	return frame
end

local function character(root: Frame, id: string)
	local imageId = CharacterPortraits[id]
	if imageId then
		local portraitScale = if id == "MarbleHost" then 0.84 else 1
		Widgets.create("ImageLabel", {
			Name = "CharacterPortrait",
			BackgroundTransparency = 1,
			Image = imageId,
			ScaleType = Enum.ScaleType.Fit,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(portraitScale, portraitScale),
			Parent = root,
		})
		return
	end
	local c = palettes[id] or GOLD
	shape(root, 50, 84, 58, 14, INK, 0, 0.5, false)
	shape(root, 50, 57, 58, 66, c, -4, 0.43)
	shape(root, 35, 87, 16, 12, IVORY, -12, 0.3)
	shape(root, 65, 87, 16, 12, IVORY, 12, 0.3)
	shape(root, 31, 54, 16, 29, c, -10, 0.4)
	shape(root, 69, 54, 16, 29, c, 10, 0.4)
	shape(root, 50, 49, 44, 18, INK, 0, 0.3)
	shape(root, 40, 48, 7, 5, IVORY, -8, 0.1, false)
	shape(root, 60, 48, 7, 5, IVORY, 8, 0.1, false)
	if id == "SparkMage" or id == "CandleScholar" or id == "SoleConductor" then
		shape(root, 50, 24, 33, 28, c, 45, 0.12)
		shape(root, 50, 33, 66, 10, c, -4, 0.2)
		shape(root, 50, 23, 10, 10, GOLD, 45, 0.1)
	elseif id == "NightWatch" then
		shape(root, 50, 29, 54, 21, IVORY, -4, 0.25)
		shape(root, 50, 24, 10, 29, c, -4, 0.2)
	elseif id == "FarSeer" then
		shape(root, 50, 35, 54, 10, IVORY, -8, 0.1)
		shape(root, 66, 26, 9, 30, c, 30, 0.2)
	elseif id == "MarbleHost" then
		shape(root, 39, 28, 24, 24, IVORY, -20, 0.2)
		shape(root, 62, 29, 21, 24, IVORY, 17, 0.2)
	elseif id == "ManyHands" then
		shape(root, 15, 65, 14, 23, c, 30, 0.4)
		shape(root, 85, 65, 14, 23, c, -30, 0.4)
	else
		shape(root, 50, 31, 58, 9, GOLD, -5, 0.15)
		shape(root, 62, 22, 10, 25, GOLD, 18, 0.15)
	end
	shape(root, 50, 69, 15, 15, GOLD, 45, 0.2)
end

local blades = {
	RitualDirk = true,
	DuskSabre = true,
	LamplighterPike = true,
	OrbitBlades = true,
	WinterNeedle = true,
	SpiritFlint = true,
	RuneAwl = true,
}
local guns = {
	WatchmanPistol = true,
	RattleRepeater = true,
	ScatterBell = true,
	ShrapnelOrgan = true,
	CinderBreath = true,
	LeechCarbine = true,
	CathedralEngine = true,
	MortarLantern = true,
	GalvanicFork = true,
}
local function weapon(root: Frame, id: string)
	if id == "FoundryKey" then
		shape(root, 47, 61, 15, 58, rgb(155, 174, 181), 32, 0.15)
		shape(root, 65, 29, 35, 35, rgb(155, 174, 181), 32, 0.3)
		shape(root, 72, 21, 16, 23, Theme.button, 32, 0.1, false)
		shape(root, 34, 82, 7, 7, INK, 0, 0.5, false)
	elseif id == "Shockwave" then
		shape(root, 43, 65, 13, 53, rgb(151, 108, 76), 30, 0.1)
		shape(root, 59, 30, 60, 32, rgb(155, 174, 181), 30, 0.15)
		shape(root, 59, 30, 13, 35, GOLD, 30, 0.1)
	elseif id == "ThornTrail" then
		shape(root, 50, 53, 17, 67, rgb(113, 155, 83), 24, 0.3)
		for i = 1, 3 do
			shape(root, 33 + i * 8, 20 + i * 16, 26, 13, rgb(146, 181, 104), -24, 0.1)
		end
	elseif guns[id] then
		root.Rotation = -22
		shape(root, 43, 68, 18, 35, rgb(151, 108, 76), -8, 0.12)
		shape(root, 51, 42, 59, 22, rgb(159, 169, 167), 0, 0.1)
		shape(root, 83, 41, 15, 13, INK, 0, 0.05)
		shape(root, 28, 42, 13, 30, GOLD, 0, 0.1)
		shape(root, 53, 36, 25, 5, IVORY, 0, 0.1, false)
		if id ~= "WatchmanPistol" then
			shape(root, 62, 63, 12, 20, INK, 12, 0.1)
		end
		if id == "ScatterBell" or id == "ShrapnelOrgan" then
			shape(root, 74, 34, 34, 8, IVORY, 0, 0.1)
		elseif id == "CinderBreath" or id == "CathedralEngine" then
			shape(root, 50, 18, 30, 18, GOLD, 0, 0.25)
		elseif id == "MortarLantern" then
			shape(root, 68, 38, 46, 27, rgb(102, 130, 98), 0, 0.2)
		end
	elseif blades[id] then
		root.Rotation = 32
		shape(root, 50, 33, if id == "DuskSabre" then 19 else 13, 52, IVORY, 0, 0.12)
		shape(root, 54, 34, 3, 39, rgb(155, 178, 183), 0, 0.1, false)
		shape(root, 50, 63, 39, 9, GOLD, 0, 0.12)
		shape(root, 50, 78, 12, 24, rgb(139, 95, 71), 0, 0.12)
	elseif id == "BrassKnuckles" or id == "TithePalm" then
		shape(root, 50, 59, 53, 39, GOLD, -12, 0.3)
		for i = 1, 4 do
			shape(root, 20 + i * 13, 39, 13, 23, IVORY, -12, 0.3)
		end
	elseif id == "Gravestone" then
		shape(root, 50, 49, 48, 65, rgb(154, 160, 164), -20, 0.2)
		shape(root, 51, 38, 29, 7, INK, -20, 0.1, false)
		shape(root, 52, 49, 7, 33, INK, -20, 0.1, false)
	elseif id == "BoomerangAxe" or id == "WraithHatchet" then
		shape(root, 48, 61, 12, 65, rgb(141, 101, 68), 30, 0.1)
		shape(root, 54, 30, 50, 28, IVORY, 30, 0.15)
		shape(root, 54, 30, 10, 30, GOLD, 30, 0.1)
	else
		shape(root, 43, 65, 11, 55, GOLD, 28, 0.15)
		shape(root, 61, 31, 34, 34, rgb(127, 198, 207), 20, 0.3)
		shape(root, 61, 30, 14, 14, IVORY, 45, 0.1)
	end
end

local function stat(root: Frame, id: string)
	if id == "maxHp" or id == "hpRegen" or id == "lifeSteal" then
		shape(root, 50, 57, 41, 41, rgb(220, 104, 92), 45, 0.12)
		shape(root, 35, 39, 35, 35, rgb(220, 104, 92), 0, 0.5)
		shape(root, 65, 39, 35, 35, rgb(220, 104, 92), 0, 0.5)
		shape(root, 50, 53, 39, 27, rgb(220, 104, 92), 0, 0.1, false)
		if id == "hpRegen" then
			shape(root, 50, 51, 10, 31, IVORY, 0, 0.1, false)
			shape(root, 50, 51, 31, 10, IVORY, 0, 0.1, false)
		elseif id == "lifeSteal" then
			shape(root, 41, 49, 8, 22, IVORY, -12, 0.2, false)
			shape(root, 59, 49, 8, 22, IVORY, 12, 0.2, false)
		end
	elseif id == "engineering" then
		weapon(root, "FoundryKey")
	elseif id == "dodge" then
		shape(root, 53, 48, 44, 57, IVORY, 20, 0.5)
		shape(root, 47, 40, 6, 10, INK, 0, 0.2, false)
		shape(root, 62, 43, 6, 10, INK, 0, 0.2, false)
		shape(root, 20, 38, 21, 5, GOLD, 0, 0.1, false)
		shape(root, 18, 52, 15, 5, GOLD, 0, 0.1, false)
	elseif id == "armor" then
		shape(root, 50, 49, 54, 64, rgb(135, 173, 198), 0, 0.3)
		shape(root, 50, 47, 9, 48, IVORY, 0, 0.1, false)
		shape(root, 50, 43, 37, 8, IVORY, 0, 0.1, false)
	elseif id == "harvesting" then
		shape(root, 50, 57, 7, 65, GOLD, 0, 0.1)
		for i = 1, 3 do
			shape(root, 37, 15 + i * 15, 24, 12, GOLD, 32, 0.3)
			shape(root, 63, 15 + i * 15, 24, 12, GOLD, -32, 0.3)
		end
	elseif id == "luck" then
		for _, p in { { 38, 33 }, { 63, 33 }, { 38, 58 }, { 63, 58 } } do
			shape(root, p[1], p[2], 29, 29, Theme.success, 0, 0.5)
		end
		shape(root, 51, 71, 8, 30, rgb(113, 155, 83), 15, 0.2)
	elseif id == "attackSpeed" then
		shape(root, 55, 32, 21, 47, GOLD, 30, 0.1)
		shape(root, 45, 65, 21, 47, GOLD, 30, 0.1)
		shape(root, 50, 48, 35, 16, GOLD, 0, 0.1, false)
	elseif id == "speed" then
		shape(root, 53, 44, 26, 43, GOLD, 20, 0.15)
		shape(root, 45, 71, 52, 22, GOLD, 0, 0.2)
		shape(root, 20, 38, 24, 6, IVORY, 0, 0.1, false)
		shape(root, 19, 51, 17, 6, IVORY, 0, 0.1, false)
	elseif id == "range" or id == "critChance" then
		shape(root, 50, 50, 57, 57, INK, 0, 0.5)
		shape(root, 50, 50, 42, 42, IVORY, 0, 0.5, false)
		shape(root, 50, 50, 24, 24, INK, 0, 0.5, false)
		shape(root, 50, 50, 9, 75, GOLD, 0, 0.1, false)
		shape(root, 50, 50, 75, 9, GOLD, 0, 0.1, false)
	else
		weapon(
			root,
			if id == "rangedDamage"
				then "WatchmanPistol"
				elseif id == "elementalDamage" then "SparkBolt"
				else "DuskSabre"
		)
	end
end

function Icons.draw(parent: GuiObject, kind: string, id: string): Frame
	local key = kind .. ":" .. id
	local upgradeImage: string? = nil
	if kind == "stat" then
		local screen = parent:FindFirstAncestorWhichIsA("ScreenGui")
		if screen and screen.Name == "LevelUp" then
			upgradeImage = PrimaryStatArt.upgrades[id]
			if upgradeImage then
				key = "upgrade:" .. id
			end
		end
	end
	local old = parent:FindFirstChild("Illustration")
	if old and old:GetAttribute("IconKey") == key then
		return old :: Frame
	end
	if old then
		old:Destroy()
	end
	local root = Widgets.create(
		"Frame",
		{ Name = "Illustration", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = parent }
	)
	root:SetAttribute("IconKey", key)
	if kind == "character" then
		character(root, id)
	elseif kind == "weapon" then
		local fallback = Widgets.create("Frame", {
			Name = "DrawnWeapon",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Parent = root,
		})
		weapon(fallback, id)
		local imageId = WeaponImages[id]
		if imageId then
			local art = Widgets.create("ImageLabel", {
				Name = "WeaponImage",
				BackgroundTransparency = 1,
				Image = imageId,
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(1, 1),
				Parent = root,
			})
			task.spawn(function()
				local loaded = false
				local ok = pcall(function()
					ContentProvider:PreloadAsync({ art }, function(_, status)
						loaded = status == Enum.AssetFetchStatus.Success
					end)
				end)
				if ok and loaded and root.Parent then
					fallback.Visible = false
				end
			end)
		end
	elseif kind == "item" then
		local item = Config.Items.byId[id]
		local selected = "luck"
		for _, info in Config.Stats.order do
			if item and (item.stats[info.id] or 0) > 0 then
				selected = info.id
				break
			end
		end
		local fallback = Widgets.create("Frame", {
			Name = "Fallback",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Parent = root,
		})
		stat(fallback, selected)
		local assetId = ItemImages[id]
		if assetId then
			local art = Widgets.create("ImageLabel", {
				Name = "ItemArt",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ScaleType = Enum.ScaleType.Fit,
				Image = assetId,
				Parent = root,
			})
			local function showWhenLoaded()
				if art.IsLoaded and root.Parent then
					fallback.Visible = false
				end
			end
			art:GetPropertyChangedSignal("IsLoaded"):Connect(showWhenLoaded)
			showWhenLoaded()
		end
	else
		local fallback = Widgets.create("Frame", {
			Name = "Fallback",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Parent = root,
		})
		stat(fallback, id)
		local assetId = StatImages[id]
		if assetId then
			local art = Widgets.create("ImageLabel", {
				Name = "StatArt",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ScaleType = Enum.ScaleType.Fit,
				Image = assetId,
				Parent = root,
			})
			local function showWhenLoaded()
				if art.IsLoaded and root.Parent then
					fallback.Visible = false
				end
			end
			art:GetPropertyChangedSignal("IsLoaded"):Connect(showWhenLoaded)
			showWhenLoaded()
		end
	end
	-- Uploaded stat artwork is the final illustration. Keeping the drawn fallback underneath
	-- makes both visible in Studio even while ImageLabel.IsLoaded still reports false.
	if kind == "stat" and StatImages[id] then
		local fallback = root:FindFirstChild("Fallback")
		if fallback then
			fallback.Visible = false
		end
	end
	if kind == "item" and ItemImages[id] then
		local fallback = root:FindFirstChild("Fallback")
		if fallback then
			fallback.Visible = false
			local art = root:FindFirstChild("ItemArt")
			if art then
				task.spawn(function()
					pcall(function()
						ContentProvider:PreloadAsync({ art }, function(_, status)
							if fallback.Parent then
								fallback.Visible = status ~= Enum.AssetFetchStatus.Success
							end
						end)
					end)
				end)
			end
		end
	end
	-- LevelUpController and StatsController both request "stat" artwork. Select the wiki's
	-- separate card illustration only inside the LevelUp screen, without changing either caller.
	if upgradeImage then
		local art = root:FindFirstChild("StatArt")
		if art and art:IsA("ImageLabel") then
			art.Image = upgradeImage
		end
	end
	-- A valid asset ID can still fail to load in a local or restricted test place.
	if kind == "stat" and StatImages[id] then
		local fallback = root:FindFirstChild("Fallback")
		local art = root:FindFirstChild("StatArt")
		if fallback and art then
			task.spawn(function()
				local ok, fetched = pcall(function()
					local success = false
					ContentProvider:PreloadAsync({ art }, function(_, status)
						success = status == Enum.AssetFetchStatus.Success
					end)
					return success
				end)
				if fallback.Parent then
					fallback.Visible = not (ok and fetched)
				end
			end)
		end
	end
	return root
end

function Icons.holder(parent: Instance, size: number, order: number?): Frame
	return Widgets.create("Frame", {
		Name = "Artwork",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		LayoutOrder = order or 0,
		Parent = parent,
	})
end
return Icons
