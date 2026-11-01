--!strict
-- Authored cartoon enemy meshes and rig placement, read by EnemyRenderer/Models.
-- Source-model studs, scaled to the existing collision radius. Provenance: docs/ENEMY-ART.md.
export type Piece = {
	name: string,
	mesh: string,
	texture: string,
	size: Vector3,
	meshSize: Vector3,
	position: Vector3,
	motion: string,
	pivot: Vector3?,
	detail: boolean?,
	armor: boolean?,
	tint: Color3?,
}
export type Trim = {
	name: string,
	shape: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	motion: string?,
	pivot: Vector3?,
	rotation: Vector3?,
	detail: boolean?,
}
export type Look = {
	radius: number,
	crownHeight: number,
	stride: number?,
	pieces: { Piece },
	tint: Color3?,
	shoulders: boolean?,
	stationary: boolean?,
	trims: { Trim }?,
}
local MeshCatalog: { [string]: Look } = {
	Charger = {
		radius = 1.9,
		crownHeight = 3.4,
		stride = 5.0,
		pieces = {
			{
				name = "Body",
				motion = "Body",
				mesh = "rbxassetid://81905516932105",
				texture = "rbxassetid://104389124021320",
				size = Vector3.new(2.28429, 2.24585, 3.8),
				meshSize = Vector3.new(2.28429, 2.24585, 3.8),
				position = Vector3.new(0.01086, 1.45775, 0.00574),
			},
			{
				name = "LegBackRight",
				motion = "LegLeft",
				mesh = "rbxassetid://89164356879804",
				texture = "rbxassetid://104389124021320",
				size = Vector3.new(0.73763, 1.3321, 0.85818),
				meshSize = Vector3.new(0.73763, 1.3321, 0.85818),
				position = Vector3.new(0.81189, 0.65873, 0.69245),
				pivot = Vector3.new(0.81189, 1.16493, 0.72245),
			},
			{
				name = "LegBackLeft",
				motion = "LegRight",
				mesh = "rbxassetid://107438755821986",
				texture = "rbxassetid://104389124021320",
				size = Vector3.new(0.73242, 1.33456, 0.84666),
				meshSize = Vector3.new(0.73242, 1.33456, 0.84666),
				position = Vector3.new(-0.77844, 0.66005, 0.68736),
				pivot = Vector3.new(-0.77844, 1.16718, 0.71736),
			},
			{
				name = "LegFrontRight",
				motion = "LegRight",
				mesh = "rbxassetid://74144956690742",
				texture = "rbxassetid://104389124021320",
				size = Vector3.new(0.76154, 1.21402, 0.82401),
				meshSize = Vector3.new(0.76154, 1.21402, 0.82401),
				position = Vector3.new(0.81812, 0.59893, -0.97727),
				pivot = Vector3.new(0.81812, 1.06026, -0.94727),
			},
			{
				name = "LegFrontLeft",
				motion = "LegLeft",
				mesh = "rbxassetid://98647506322432",
				texture = "rbxassetid://104389124021320",
				size = Vector3.new(0.77331, 1.21846, 0.82866),
				meshSize = Vector3.new(0.77331, 1.21846, 0.82866),
				position = Vector3.new(-0.79272, 0.60258, -0.96831),
				pivot = Vector3.new(-0.79272, 1.06559, -0.93831),
			},
			{
				name = "Shell",
				motion = "Body",
				mesh = "rbxassetid://129541605685388",
				texture = "rbxassetid://72124045453304",
				size = Vector3.new(2.89359, 1.97671, 3.27057),
				meshSize = Vector3.new(2.89359, 1.97671, 3.27057),
				position = Vector3.new(0.00525, 1.9236, 0.19777),
				armor = true,
			},
			{
				name = "Horns",
				motion = "Body",
				mesh = "rbxassetid://102461500952746",
				texture = "rbxassetid://110404498523006",
				size = Vector3.new(2.18581, 1.11936, 0.70398),
				meshSize = Vector3.new(2.18581, 1.11936, 0.70398),
				position = Vector3.new(0.00134, 1.96173, -1.36751),
			},
		},
	},
	Shadeling = {
		radius = 1.3,
		crownHeight = 3.25,
		stride = 4.8,
		pieces = {
			{
				name = "Body",
				motion = "Body",
				mesh = "rbxassetid://96238821901613",
				texture = "rbxassetid://87648089273624",
				size = Vector3.new(1.69174, 2.81551, 2.15354),
				meshSize = Vector3.new(1.69174, 2.81551, 2.15354),
				position = Vector3.new(0.00525, 1.40317, -0.01868),
				armor = true,
			},
			{
				name = "ArmRight",
				motion = "ArmRight",
				mesh = "rbxassetid://73025848029518",
				texture = "rbxassetid://120553515487945",
				size = Vector3.new(0.64383, 0.79611, 0.40968),
				meshSize = Vector3.new(0.64383, 0.79611, 0.40968),
				position = Vector3.new(0.96497, 0.94298, -0.43419),
				pivot = Vector3.new(0.68, 1.27, -0.39),
			},
			{
				name = "ArmLeft",
				motion = "ArmLeft",
				mesh = "rbxassetid://82323366661789",
				texture = "rbxassetid://120553515487945",
				size = Vector3.new(0.6478, 0.78533, 0.41055),
				meshSize = Vector3.new(0.6478, 0.78533, 0.41055),
				position = Vector3.new(-0.95471, 0.949, -0.4347),
				pivot = Vector3.new(-0.68, 1.27, -0.39),
			},
			{
				name = "Fins",
				motion = "Body",
				mesh = "rbxassetid://131213786100111",
				texture = "rbxassetid://82904727922504",
				size = Vector3.new(1.2916, 1.24625, 0.33946),
				meshSize = Vector3.new(1.2916, 1.24625, 0.33946),
				position = Vector3.new(0.00354, 1.17222, 0.93484),
				detail = true,
			},
		},
	},
	Brute = {
		shoulders = true,
		radius = 1.75,
		crownHeight = 3.5,
		stride = 6.8,
		pieces = {
			{
				name = "Body",
				motion = "Body",
				mesh = "rbxassetid://96238821901613",
				texture = "rbxassetid://87648089273624",
				size = Vector3.new(2.36844, 3.04075, 2.51964),
				meshSize = Vector3.new(1.69174, 2.81551, 2.15354),
				position = Vector3.new(0, 1.515, 0),
				armor = true,
			},
			{
				name = "ArmRight",
				motion = "ArmRight",
				mesh = "rbxassetid://73025848029518",
				texture = "rbxassetid://120553515487945",
				size = Vector3.new(0.96575, 1.51261, 0.69646),
				meshSize = Vector3.new(0.64383, 0.79611, 0.40968),
				position = Vector3.new(1.25, 1.03, -0.36),
				pivot = Vector3.new(0.94, 1.67, -0.23),
			},
			{
				name = "ArmLeft",
				motion = "ArmLeft",
				mesh = "rbxassetid://82323366661789",
				texture = "rbxassetid://120553515487945",
				size = Vector3.new(0.9717, 1.49213, 0.69794),
				meshSize = Vector3.new(0.6478, 0.78533, 0.41055),
				position = Vector3.new(-1.25, 1.03, -0.36),
				pivot = Vector3.new(-0.94, 1.67, -0.23),
			},
			{
				name = "Fins",
				motion = "Body",
				mesh = "rbxassetid://131213786100111",
				texture = "rbxassetid://82904727922504",
				size = Vector3.new(1.93741, 1.47058, 0.40736),
				meshSize = Vector3.new(1.2916, 1.24625, 0.33946),
				position = Vector3.new(0, 1.55, 1.16),
				detail = true,
			},
		},
	},
	Spitter = {
		radius = 1.2,
		crownHeight = 2.95,
		stride = 5.2,
		pieces = {
			{
				name = "Spout",
				motion = "Body",
				mesh = "rbxassetid://77906548837086",
				texture = "rbxassetid://93600291294554",
				size = Vector3.new(0.93, 0.9, 0.8),
				meshSize = Vector3.new(0.84455, 0.82615, 1.06622),
				position = Vector3.new(0.00232, 1.58, -0.73),
				armor = true,
			},
			{
				name = "Arms",
				motion = "Sway",
				mesh = "rbxassetid://137496055683530",
				texture = "rbxassetid://93424102959366",
				size = Vector3.new(2.29523, 0.85012, 0.6074),
				meshSize = Vector3.new(2.29523, 0.85012, 0.6074),
				position = Vector3.new(0.0022, 0.79577, 0.2677),
				pivot = Vector3.new(0, 1.1, 0.25),
			},
			{
				name = "Body",
				motion = "Body",
				mesh = "rbxassetid://102708875008302",
				texture = "rbxassetid://111784171431864",
				size = Vector3.new(1.93391, 2.4598, 1.92036),
				meshSize = Vector3.new(1.93391, 2.4598, 1.92036),
				position = Vector3.new(0.00745, 1.22491, 0.44604),
			},
		},
	},
}
-- Second series: authored anatomy for the remaining ordinary enemy roles.
MeshCatalog.Splitter = {
	radius = 1.55,
	crownHeight = 4.25000,
	stride = 5.2,
	pieces = {
		{
			name = "Body",
			motion = "Body",
			mesh = "rbxassetid://93370880462163",
			texture = "rbxassetid://106659980726181",
			size = Vector3.new(2.92127, 2.07716, 1.57731),
			meshSize = Vector3.new(2.92127, 2.07716, 1.57731),
			position = Vector3.new(0, 1.1806, 0.02149),
			armor = true,
		},
		{
			name = "Helmet",
			motion = "Body",
			mesh = "rbxassetid://98843033767823",
			texture = "rbxassetid://116726190878408",
			size = Vector3.new(2.08767, 1.82469, 1.75755),
			meshSize = Vector3.new(2.08767, 1.82469, 1.75755),
			position = Vector3.new(-0.00146, 3.08765, 0),
			armor = true,
		},
		{
			name = "Limbs",
			motion = "Body",
			mesh = "rbxassetid://115137348714874",
			texture = "rbxassetid://100630571440478",
			size = Vector3.new(2.89734, 1.29487, 0.56266),
			meshSize = Vector3.new(2.89734, 1.29487, 0.56266),
			position = Vector3.new(-0.00293, 0.64743, 0.05505),
		},
	},
}
MeshCatalog.Herald = {
	radius = 1.4,
	crownHeight = 4.44999,
	stride = 5.2,
	pieces = {
		{
			name = "Body",
			motion = "Body",
			mesh = "rbxassetid://113234034424624",
			texture = "rbxassetid://98675572681841",
			size = Vector3.new(1.85684, 2.80046, 1.88346),
			meshSize = Vector3.new(1.85684, 2.80046, 1.88346),
			position = Vector3.new(0.0022, 1.40023, 0),
			armor = true,
		},
		{
			name = "Arms",
			motion = "Sway",
			mesh = "rbxassetid://84314322609805",
			texture = "rbxassetid://71970428485882",
			size = Vector3.new(2.70485, 0.80818, 0.43473),
			meshSize = Vector3.new(2.70485, 0.80818, 0.43473),
			position = Vector3.new(0, 1.20876, -0.0299),
			pivot = Vector3.new(0, 1.49162, -0.0299),
		},
		{
			name = "Antennae",
			motion = "Body",
			mesh = "rbxassetid://99724194504867",
			texture = "rbxassetid://74641487671366",
			size = Vector3.new(1.66428, 1.61535, 0.91198),
			meshSize = Vector3.new(1.66428, 1.61535, 0.91198),
			position = Vector3.new(-0.0022, 3.39232, 0.00128),
		},
	},
}
MeshCatalog.BroodEgg = {
	radius = 1.45,
	crownHeight = 3.68889,
	stride = 5.2,
	stationary = true,
	pieces = {
		{
			name = "Shell",
			motion = "Body",
			mesh = "rbxassetid://84069412359326",
			texture = "rbxassetid://128736771908671",
			size = Vector3.new(2.80431, 3.15136, 2.8),
			meshSize = Vector3.new(2.80431, 3.15136, 2.8),
			position = Vector3.new(0, 1.79632, 0),
			armor = true,
		},
		{
			name = "Base",
			motion = "Body",
			mesh = "rbxassetid://111990198912100",
			texture = "rbxassetid://91694360502053",
			size = Vector3.new(2.35104, 0.49684, 2.38399),
			meshSize = Vector3.new(2.35104, 0.49684, 2.38399),
			position = Vector3.new(-0.0022, 0.24842, -0.00905),
		},
		{
			name = "Fins",
			motion = "Body",
			mesh = "rbxassetid://100023637497892",
			texture = "rbxassetid://95561058394485",
			size = Vector3.new(0.46101, 0.49954, 0.34656),
			meshSize = Vector3.new(0.46101, 0.49954, 0.34656),
			position = Vector3.new(-0.62012, 3.18912, -0.21832),
			detail = true,
		},
	},
}
MeshCatalog.Mender = {
	radius = 1.5,
	crownHeight = 3.94999,
	stride = 5.2,
	pieces = {
		{
			name = "Body",
			motion = "Body",
			mesh = "rbxassetid://90615654422499",
			texture = "rbxassetid://133302158122572",
			size = Vector3.new(2.59697, 3.65089, 2.91129),
			meshSize = Vector3.new(2.59697, 3.65089, 2.91129),
			position = Vector3.new(0, 1.87455, 0),
			armor = true,
		},
		{
			name = "Arms",
			motion = "Sway",
			mesh = "rbxassetid://85273057967216",
			texture = "rbxassetid://108456044979406",
			size = Vector3.new(2.52601, 1.08174, 0.20479),
			meshSize = Vector3.new(2.52601, 1.08174, 0.20479),
			position = Vector3.new(0.00122, 1.26435, -0.73619),
			pivot = Vector3.new(0, 1.64296, -0.73619),
		},
		{
			name = "Feet",
			motion = "Body",
			mesh = "rbxassetid://97067565875573",
			texture = "rbxassetid://134086864001993",
			size = Vector3.new(1.78491, 0.37583, 1.01667),
			meshSize = Vector3.new(1.78491, 0.37583, 1.01667),
			position = Vector3.new(0.00537, 0.18791, -0.21663),
		},
	},
}
MeshCatalog.Reaper = {
	radius = 2.05,
	crownHeight = 3.95000,
	stride = 5.2,
	pieces = {
		{
			name = "Body",
			motion = "Body",
			mesh = "rbxassetid://101619455736912",
			texture = "rbxassetid://91427790099267",
			size = Vector3.new(3.15605, 3.12576, 2.54792),
			meshSize = Vector3.new(3.15605, 3.12576, 2.54792),
			position = Vector3.new(-0.00928, 1.83742, 0.02028),
			armor = true,
		},
		{
			name = "Head",
			motion = "Body",
			mesh = "rbxassetid://100152242518340",
			texture = "rbxassetid://117730305291085",
			size = Vector3.new(0.85541, 0.83222, 0.43621),
			meshSize = Vector3.new(0.85541, 0.83222, 0.67109),
			position = Vector3.new(0.00195, 2.41111, -1.12),
			armor = true,
		},
		{
			name = "ArmRight",
			motion = "ArmRight",
			mesh = "rbxassetid://115853436465676",
			texture = "rbxassetid://91648227300970",
			size = Vector3.new(1.18901, 1.79723, 1.08878),
			meshSize = Vector3.new(1.18901, 1.79723, 1.08878),
			position = Vector3.new(1.31885, 1.09608, -0.09884),
			pivot = Vector3.new(1.03, 2.1, 0.05),
		},
		{
			name = "ArmLeft",
			motion = "ArmLeft",
			mesh = "rbxassetid://88381313806085",
			texture = "rbxassetid://91648227300970",
			size = Vector3.new(1.19506, 1.79918, 1.08654),
			meshSize = Vector3.new(1.19506, 1.79918, 1.08654),
			position = Vector3.new(-1.32031, 1.09764, -0.1),
			pivot = Vector3.new(-1.03, 2.1, 0.05),
		},
		{
			name = "SickleLeft",
			motion = "ArmLeft",
			mesh = "rbxassetid://138916146158722",
			texture = "rbxassetid://91427790099267",
			size = Vector3.new(1.17415, 2.03337, 0.90241),
			meshSize = Vector3.new(1.17415, 2.03337, 0.90241),
			position = Vector3.new(-1.52588, 2.68331, 0.04409),
			pivot = Vector3.new(-1.03, 2.1, 0.05),
		},
		{
			name = "SickleRight",
			motion = "ArmRight",
			mesh = "rbxassetid://94984088992924",
			texture = "rbxassetid://91427790099267",
			size = Vector3.new(1.18372, 2.0393, 0.89049),
			meshSize = Vector3.new(1.18372, 2.0393, 0.89049),
			position = Vector3.new(1.52124, 2.67673, 0.04051),
			pivot = Vector3.new(1.03, 2.1, 0.05),
		},
		{
			name = "LegLeft",
			motion = "LegLeft",
			mesh = "rbxassetid://112223344530991",
			texture = "rbxassetid://91427790099267",
			size = Vector3.new(0.78084, 0.75636, 0.93078),
			meshSize = Vector3.new(0.78084, 0.75636, 0.93078),
			position = Vector3.new(-0.66919, 0.37818, 0.11227),
			pivot = Vector3.new(-0.66919, 0.6656, 0.11227),
		},
		{
			name = "LegRight",
			motion = "LegRight",
			mesh = "rbxassetid://128257071790408",
			texture = "rbxassetid://91427790099267",
			size = Vector3.new(0.78209, 0.7687, 0.93881),
			meshSize = Vector3.new(0.78209, 0.7687, 0.93881),
			position = Vector3.new(0.66821, 0.38565, 0.1111),
			pivot = Vector3.new(0.66821, 0.67776, 0.1111),
		},
	},
}
MeshCatalog.Looter = {
	radius = 1.65,
	crownHeight = 3.84,
	stride = 3.8,
	pieces = {
		{
			name = "Body",
			motion = "Body",
			mesh = "rbxassetid://113029586318374",
			texture = "rbxassetid://138562608121288",
			size = Vector3.new(3.18395, 3.06561, 2.80055),
			meshSize = Vector3.new(3.18395, 3.06561, 2.80055),
			position = Vector3.new(0, 1.53281, 0),
			armor = true,
		},
		{
			name = "Antenna",
			motion = "Body",
			mesh = "rbxassetid://131791927505413",
			texture = "rbxassetid://130433106431551",
			size = Vector3.new(1.01528, 0.56612, 0.20926),
			meshSize = Vector3.new(1.01528, 0.56612, 0.20926),
			position = Vector3.new(-0.00098, 3.30424, -0.1198),
			detail = true,
		},
	},
}

MeshCatalog.Gobbler = {
	radius = 1.9,
	crownHeight = 3.95000,
	stride = 5.2,
	pieces = {
		{
			name = "Body",
			motion = "Body",
			mesh = "rbxassetid://74846521195799",
			texture = "rbxassetid://118086602147537",
			size = Vector3.new(2.74779, 2.13466, 2.83528),
			meshSize = Vector3.new(2.74779, 2.13466, 2.83528),
			position = Vector3.new(0.00269, 1.19851, 0.05531),
			armor = true,
		},
		{
			name = "Head",
			motion = "Body",
			mesh = "rbxassetid://140474554500365",
			texture = "rbxassetid://71668360665897",
			size = Vector3.new(2.3461, 1.63895, 2.66167),
			meshSize = Vector3.new(2.3461, 1.63895, 2.66167),
			position = Vector3.new(0.00244, 2.88053, -0.02992),
			armor = true,
		},
		{
			name = "Mouth",
			motion = "Body",
			mesh = "rbxassetid://87688087714337",
			texture = "rbxassetid://99610637731904",
			size = Vector3.new(1.91157, 1.39502, 1.50353),
			meshSize = Vector3.new(1.91157, 1.39502, 1.50353),
			position = Vector3.new(0.00732, 1.51181, -0.72119),
		},
		{
			name = "ArmLeft",
			motion = "ArmLeft",
			mesh = "rbxassetid://74664795581724",
			texture = "rbxassetid://118086602147537",
			size = Vector3.new(0.79113, 1.8171, 1.36835),
			meshSize = Vector3.new(0.79113, 1.8171, 1.36835),
			position = Vector3.new(-1.49097, 1.45077, 0.27181),
			pivot = Vector3.new(-1.0735, 2.08675, 0.27181),
		},
		{
			name = "ArmRight",
			motion = "ArmRight",
			mesh = "rbxassetid://95260442697756",
			texture = "rbxassetid://118086602147537",
			size = Vector3.new(1.45435, 2.7996, 1.76367),
			meshSize = Vector3.new(1.45435, 2.7996, 1.76367),
			position = Vector3.new(1.15942, 1.9443, 0.05426),
			pivot = Vector3.new(0.83478, 2.92416, 0.05426),
		},
		{
			name = "LegRight",
			motion = "LegRight",
			mesh = "rbxassetid://112199749422522",
			texture = "rbxassetid://118086602147537",
			size = Vector3.new(0.87915, 0.56192, 1.23186),
			meshSize = Vector3.new(0.87915, 0.56192, 1.23186),
			position = Vector3.new(0.59888, 0.28116, 0.31156),
			pivot = Vector3.new(0.59888, 0.49469, 0.31156),
		},
		{
			name = "LegLeft",
			motion = "LegLeft",
			mesh = "rbxassetid://88622048907073",
			texture = "rbxassetid://118086602147537",
			size = Vector3.new(0.88422, 0.5668, 1.22682),
			meshSize = Vector3.new(0.88422, 0.5668, 1.22682),
			position = Vector3.new(-0.60718, 0.2834, 0.30732),
			pivot = Vector3.new(-0.60718, 0.49878, 0.30732),
		},
	},
}

-- Related species share topology but have deliberate proportions, colors and silhouette details.
local function scaled(v: Vector3, scale: Vector3): Vector3
	return Vector3.new(v.X * scale.X, v.Y * scale.Y, v.Z * scale.Z)
end
local function variant(base: Look, scale: Vector3, tint: Color3): Look
	local look = table.clone(base)
	look.pieces = {}
	look.tint = tint
	look.crownHeight = base.crownHeight * scale.Y
	for _, original in base.pieces do
		local part = table.clone(original)
		part.size = scaled(original.size, scale)
		part.position = scaled(original.position, scale)
		part.pivot = if original.pivot then scaled(original.pivot, scale) else nil
		table.insert(look.pieces, part)
	end
	return look
end
local v, rgb = Vector3.new, Color3.fromRGB
local INK = rgb(28, 23, 40)
local BONE = rgb(228, 224, 202)
local function thorn(name: string, position: Vector3, size: Vector3, side: number): { Trim }
	local turn = v(0, if side < 0 then math.pi else 0, -side * 0.42)
	return {
		{ name = name .. "Rim", shape = "spike", size = size, position = position, color = INK, rotation = turn },
		{
			name = name,
			shape = "spike",
			size = size * 0.78,
			position = position + v(0, 0.025, -0.035),
			color = BONE,
			rotation = turn,
			detail = true,
		},
	}
end
local function appendTrims(look: Look, additions: { Trim })
	local trims = look.trims or {}
	look.trims = trims
	for _, trim in additions do
		table.insert(trims, trim)
	end
end

MeshCatalog.Splitling = variant(MeshCatalog.Shadeling, v(1.12, 0.72, 0.9), rgb(235, 220, 255))
table.remove(MeshCatalog.Splitling.pieces, 4) -- only the parent carries the large dorsal fins
for _, side in { -1, 1 } do
	appendTrims(
		MeshCatalog.Splitling,
		thorn("ShellChip" .. tostring(side), v(side * 0.73, 1.18, 0.25), v(0.3, 0.4, 0.35), side)
	)
end

MeshCatalog.AbyssShadeling = variant(MeshCatalog.Shadeling, v(1.05, 1.04, 1.04), rgb(155, 157, 220))
MeshCatalog.AbyssBrute = variant(MeshCatalog.Brute, v(1, 1, 1), rgb(155, 150, 211))
for _, id in { "AbyssShadeling", "AbyssBrute" } do
	local look = MeshCatalog[id]
	for _, side in { -1, 1 } do
		appendTrims(look, thorn("AbyssCrest" .. tostring(side), v(side * 0.52, 2.52, 0.58), v(0.26, 0.63, 0.34), side))
	end
	look.crownHeight += 0.15
end

MeshCatalog.Stalker = variant(MeshCatalog.Shadeling, v(0.8, 1.18, 0.94), rgb(173, 243, 214))
MeshCatalog.Stalker.stride = 3.8
for _, part in MeshCatalog.Stalker.pieces do
	if part.name == "Fins" then
		part.size = scaled(part.size, v(1.65, 1.12, 1))
		part.position += v(0, 0.1, 0.08)
	end
end
for _, side in { -1, 1 } do
	appendTrims(
		MeshCatalog.Stalker,
		thorn("SweptFin" .. tostring(side), v(side * 0.63, 1.72, 0.66), v(0.19, 0.75, 0.33), side)
	)
end

MeshCatalog.Skulker = variant(MeshCatalog.Spitter, v(0.82, 1.08, 1), rgb(169, 224, 255))
for _, part in MeshCatalog.Skulker.pieces do
	if part.name == "Spout" then
		part.size = v(0.77, 0.72, 1.48)
		part.position = v(0, 1.7, -1.02)
	end
end
for _, side in { -1, 1 } do
	appendTrims(
		MeshCatalog.Skulker,
		thorn("SideFin" .. tostring(side), v(side * 0.83, 1.61, 0.73), v(0.2, 0.65, 0.34), side)
	)
end

MeshCatalog.Thornback = variant(MeshCatalog.Charger, v(1.05, 1.13, 0.95), rgb(255, 183, 166))
table.remove(MeshCatalog.Thornback.pieces, 7) -- retaliation spines replace the charger's forward horns
MeshCatalog.Thornback.crownHeight = 3.85
for row = 1, 3 do
	for _, side in { -1, 1 } do
		appendTrims(
			MeshCatalog.Thornback,
			thorn(
				"BackSpine" .. tostring(row) .. tostring(side),
				v(side * 1.22, 2.73, -0.85 + row * 0.65),
				v(0.29, 0.98, 0.42),
				side
			)
		)
	end
end

-- A simple recessed faceplate covers facial markings from generation; the healer reads as a hostile support unit.
MeshCatalog.Gobbler.trims = {
	{
		name = "MawInterior",
		shape = "egg",
		size = v(1.37, 1.0, 0.08),
		position = v(0, 1.51, -1.42),
		color = rgb(16, 11, 25),
	},
}
MeshCatalog.Mender.trims = {
	{ name = "FaceRim", shape = "egg", size = v(2.02, 1.57, 0.34), position = v(0, 1.79, -1.23), color = INK },
	{
		name = "Faceplate",
		shape = "egg",
		size = v(1.85, 1.4, 0.32),
		position = v(0, 1.8, -1.36),
		color = rgb(19, 35, 39),
	},
	{
		name = "SightSlit",
		shape = "egg",
		size = v(0.74, 0.11, 0.12),
		position = v(0, 1.97, -1.53),
		color = rgb(150, 222, 190),
	},
}
return MeshCatalog
