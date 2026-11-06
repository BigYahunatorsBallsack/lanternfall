--!strict
-- Visual layout and original mesh assets for the hub lobby; LobbyArtService reads this data.

local lobbyArt = {
	colors = {
		stone = { 91, 83, 77 },
		stoneLight = { 145, 132, 115 },
		stoneDark = { 55, 52, 54 },
		brass = { 186, 143, 76 },
		brassDark = { 111, 78, 45 },
		amber = { 255, 194, 99 },
	},
	meshes = {
		arch = {
			mesh = "rbxassetid://116085205083415",
			texture = "rbxassetid://77687836357460",
			sourceSize = Vector3.new(7.6563, 7.7934, 3.5),
			size = Vector3.new(13.4, 14, 3.5),
		},
		beacon = {
			{
				name = "Lantern",
				mesh = "rbxassetid://71409837852268",
				texture = "rbxassetid://127873625713955",
				sourceSize = Vector3.new(4.5555, 9.7092, 4.1455),
				size = Vector3.new(4.5555, 9.7092, 4.1455),
				offset = Vector3.new(0, 6.17, 0),
			},
			{
				name = "Pedestal",
				mesh = "rbxassetid://126662315018038",
				texture = "rbxassetid://87225033949185",
				sourceSize = Vector3.new(5.15, 1.3821, 5.1225),
				size = Vector3.new(5.15, 1.3821, 5.1225),
				offset = Vector3.new(0, 0.69, 0),
			},
		},
		lamp = {
			{
				name = "Foot",
				mesh = "rbxassetid://107288581818143",
				texture = "rbxassetid://138767202260381",
				sourceSize = Vector3.new(2.189, 0.7794, 2.2082),
				size = Vector3.new(2.189, 0.7794, 2.2082),
				offset = Vector3.new(0, 0.39, 0),
			},
			{
				name = "Post",
				mesh = "rbxassetid://71661305773600",
				texture = "rbxassetid://104482715065355",
				sourceSize = Vector3.new(1.6636, 2.711, 1.6505),
				size = Vector3.new(1.6636, 2.711, 1.6505),
				offset = Vector3.new(0, 2.08, 0),
			},
			{
				name = "Cage",
				mesh = "rbxassetid://76232616460057",
				texture = "rbxassetid://72220127240473",
				sourceSize = Vector3.new(3, 4.2607, 2.8136),
				size = Vector3.new(3, 4.2607, 2.8136),
				offset = Vector3.new(0, 5.48, 0),
			},
		},
	},
	spawn = {
		outerRingDiameter = 29,
		innerRingDiameter = 21,
		sigilRingDiameter = 11,
		sigilCoreDiameter = 10.2,
		sigilRayCount = 12,
		sigilRayRadius = 6.8,
		sigilRaySize = Vector3.new(2.9, 0.08, 0.42),
		runeRadius = 12.4,
		runeCount = 12,
		runeSize = Vector3.new(1.5, 0.09, 0.45),
		beaconOffset = Vector3.new(0, 0, 24),
	},
	portals = {
		landingSize = Vector3.new(15, 0.12, 7),
		landingDepth = 1.7,
		gateTransparency = 0.66,
		gateSize = Vector3.new(7.2, 10.8, 0.25),
		gateInset = Vector3.new(0, -0.4, 0.45),
		emblemSize = Vector3.new(1.2, 1.2, 1.2),
	},
	paths = {
		startZ = -12,
		endDistance = 8,
		slabsPerPath = 7,
		slabSize = Vector3.new(3.1, 0.08, 2.15),
	},
	lamps = {
		positions = {
			Vector3.new(-31, 0, -16),
			Vector3.new(31, 0, -16),
			Vector3.new(-31, 0, 10),
			Vector3.new(31, 0, 10),
			Vector3.new(-24, 0, 27),
			Vector3.new(24, 0, 27),
		},
	},
	perimeter = {
		margin = 1.5,
		parapetHeight = 2.4,
		parapetThickness = 2,
		cornerTowerSize = Vector3.new(8, 7, 8),
	},
}

return table.freeze(lobbyArt)
