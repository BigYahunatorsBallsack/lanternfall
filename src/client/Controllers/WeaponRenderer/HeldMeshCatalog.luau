--!strict
-- Authored textured weapon mesh IDs and local placement. Generated in Roblox Studio for this project.
-- HeldMeshLoader streams these parts only for equipped weapons; the primitive models remain as fallback.

export type Spec = { name: string, mesh: string, texture: string, size: Vector3, offset: CFrame }
export type Look = { pose: CFrame, pieces: { Spec } }

local SIDE = CFrame.Angles(0, 0, math.rad(90))
local TIP_UP = CFrame.Angles(0, math.rad(-90), 0) * SIDE
local TIP_DOWN = CFrame.Angles(0, math.rad(90), 0) * SIDE

local catalog: { [string]: Look } = {
	BoomerangAxe = {
		pose = TIP_UP,
		pieces = {
			{
				name = "head_geom",
				mesh = "rbxassetid://119812963115696",
				texture = "rbxassetid://119628661198142",
				size = Vector3.new(1.175098, 0.606601, 0.31351),
				offset = CFrame.new(0.002808, 0.594168, 0.003296, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "handle_geom",
				mesh = "rbxassetid://122785263922677",
				texture = "rbxassetid://87254451384065",
				size = Vector3.new(0.312696, 1.739773, 0.278364),
				offset = CFrame.new(-0.001801, -0.032646, 0.00708, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
		},
	},
	BrassKnuckles = {
		pose = TIP_UP,
		pieces = {
			{
				name = "body_geom",
				mesh = "rbxassetid://77771033005747",
				texture = "rbxassetid://109763751076481",
				size = Vector3.new(0.46751, 1.306817, 1.800022),
				offset = CFrame.new(0.000366, -0.000101, 0.000977, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
		},
	},
	CathedralEngine = {
		pose = SIDE,
		pieces = {
			{
				name = "grip_geom",
				mesh = "rbxassetid://119438615202014",
				texture = "rbxassetid://84925548479729",
				size = Vector3.new(0.337053, 0.6604, 0.806726),
				offset = CFrame.new(0.001709, -0.275347, 0.213623, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "barrel_geom",
				mesh = "rbxassetid://78291626333864",
				texture = "rbxassetid://99401735928830",
				size = Vector3.new(0.539543, 0.705005, 0.541837),
				offset = CFrame.new(0.003174, 0.192858, -0.626587, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "frame_geom",
				mesh = "rbxassetid://75306722565463",
				texture = "rbxassetid://101251044305494",
				size = Vector3.new(0.434327, 0.913458, 1.344444),
				offset = CFrame.new(0.001587, 0.144901, 0.230347, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
		},
	},
	ChainLightning = {
		pose = TIP_UP,
		pieces = {
			{
				name = "handle_geom",
				mesh = "rbxassetid://126275940335379",
				texture = "rbxassetid://73663795819624",
				size = Vector3.new(0.341, 1.042746, 0.344238),
				offset = CFrame.new(0.00243, -0.38129, 0.002441, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "weapon_geom",
				mesh = "rbxassetid://81346589254535",
				texture = "rbxassetid://98088456474809",
				size = Vector3.new(0.084942, 0.772619, 0.085895),
				offset = CFrame.new(0.002472, 0.511026, 0.002441, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
		},
	},
	CinderBreath = {
		pose = SIDE,
		pieces = {
			{
				name = "gun body_geom",
				mesh = "rbxassetid://94144938020929",
				texture = "rbxassetid://134596601783677",
				size = Vector3.new(0.345416, 0.556521, 0.748426),
				offset = CFrame.new(-0.00415, 0.144814, 0.139282, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "trigger_geom",
				mesh = "rbxassetid://93460606582434",
				texture = "rbxassetid://139510550768027",
				size = Vector3.new(0.060691, 0.1702, 0.135872),
				offset = CFrame.new(-0.00354, -0.02463, 0.288025, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "grip_geom",
				mesh = "rbxassetid://79488524969970",
				texture = "rbxassetid://112717618007725",
				size = Vector3.new(0.318084, 0.642559, 0.425871),
				offset = CFrame.new(-0.00354, -0.302092, -0.179382, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "hose_geom",
				mesh = "rbxassetid://91381651864622",
				texture = "rbxassetid://131432082356426",
				size = Vector3.new(0.668699, 0.875805, 0.76607),
				offset = CFrame.new(0.046631, -0.314423, 0.519897, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "nozzle_geom",
				mesh = "rbxassetid://92836605886161",
				texture = "rbxassetid://109763517433965",
				size = Vector3.new(0.741778, 0.715054, 0.801287),
				offset = CFrame.new(-0.003784, 0.474377, -0.49646, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "fuel tank_geom",
				mesh = "rbxassetid://91928498873002",
				texture = "rbxassetid://138156337176015",
				size = Vector3.new(0.346774, 0.783233, 0.590938),
				offset = CFrame.new(-0.002563, -0.442654, 0.196533, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
		},
	},
	DuskSabre = {
		pose = TIP_UP,
		pieces = {
			{
				name = "body_geom",
				mesh = "rbxassetid://134790754428587",
				texture = "rbxassetid://72081224722139",
				size = Vector3.new(0.46155, 1.799804, 1.800011),
				offset = CFrame.new(0.001221, -0.000835, 0.000488, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
		},
	},
	FoundryKey = {
		pose = TIP_UP,
		pieces = {
			{
				name = "handle_geom",
				mesh = "rbxassetid://136474265692603",
				texture = "rbxassetid://73055386523791",
				size = Vector3.new(1.8, 0.243567, 0.706205),
				offset = CFrame.new(0.002319, -0.004725, 0.00293, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "jaw_geom",
				mesh = "rbxassetid://128930364064117",
				texture = "rbxassetid://121431816426396",
				size = Vector3.new(0.167647, 0.335382, 0.163065),
				offset = CFrame.new(0.325623, -0.002285, 0.003052, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "adjustment wheel_geom",
				mesh = "rbxassetid://96825958676461",
				texture = "rbxassetid://111653916165167",
				size = Vector3.new(0.17205, 0.128786, 0.182912),
				offset = CFrame.new(0.240356, -0.007597, -0.22583, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
		},
	},
	GalvanicFork = {
		pose = SIDE,
		pieces = {
			{
				name = "grip_geom",
				mesh = "rbxassetid://137207119255629",
				texture = "rbxassetid://97605732153813",
				size = Vector3.new(0.347967, 1.006108, 0.589858),
				offset = CFrame.new(0.001892, -0.167082, 0.594604, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "barrel_geom",
				mesh = "rbxassetid://87143589744387",
				texture = "rbxassetid://130729801140545",
				size = Vector3.new(0.131992, 0.289192, 0.525622),
				offset = CFrame.new(0.00293, 0.32567, -0.635132, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "frame_geom",
				mesh = "rbxassetid://133837392285604",
				texture = "rbxassetid://85281648474994",
				size = Vector3.new(0.524557, 0.884935, 1.353423),
				offset = CFrame.new(0.002258, 0.223196, 0.225342, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
		},
	},
	Gravestone = {
		pose = TIP_DOWN,
		pieces = {
			{
				name = "blade_geom",
				mesh = "rbxassetid://116221950983045",
				texture = "rbxassetid://119655978061850",
				size = Vector3.new(0.254935, 1.185752, 0.066775),
				offset = CFrame.new(0.002319, -0.309395, 0.002197, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "hand guard_geom",
				mesh = "rbxassetid://134594638059080",
				texture = "rbxassetid://129300421535705",
				size = Vector3.new(0.558235, 0.191189, 0.130345),
				offset = CFrame.new(0.002563, 0.290993, 0.002441, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "pommel_geom",
				mesh = "rbxassetid://71049596718796",
				texture = "rbxassetid://72020171390283",
				size = Vector3.new(0.174575, 0.141502, 0.189407),
				offset = CFrame.new(0.002869, 0.826979, 0.002686, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "handle_geom",
				mesh = "rbxassetid://72107213233151",
				texture = "rbxassetid://81880596252426",
				size = Vector3.new(0.125364, 0.424163, 0.117813),
				offset = CFrame.new(0.003418, 0.564857, 0.002808, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
		},
	},
	LamplighterPike = {
		pose = TIP_UP,
		pieces = {
			{
				name = "body_geom",
				mesh = "rbxassetid://108436509429404",
				texture = "rbxassetid://86041925990965",
				size = Vector3.new(0.162801, 1.800027, 0.082237),
				offset = CFrame.new(0.001526, -0.002253, 0.001953, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
		},
	},
	LeechCarbine = {
		pose = SIDE,
		pieces = {
			{
				name = "barrel_geom",
				mesh = "rbxassetid://72774002615938",
				texture = "rbxassetid://124437896121505",
				size = Vector3.new(0.099116, 0.220968, 0.450936),
				offset = CFrame.new(0.005188, 0.256224, -0.671997, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "grip_geom",
				mesh = "rbxassetid://139572857836221",
				texture = "rbxassetid://80391207161801",
				size = Vector3.new(0.167677, 0.434812, 0.32848),
				offset = CFrame.new(-0.008423, -0.021439, 0.289673, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "frame_geom",
				mesh = "rbxassetid://99165074317548",
				texture = "rbxassetid://79678731091420",
				size = Vector3.new(0.20013, 0.711589, 1.421977),
				offset = CFrame.new(0.002258, -0.01479, 0.191528, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
		},
	},
	MortarLantern = {
		pose = SIDE,
		pieces = {
			{
				name = "grip_geom",
				mesh = "rbxassetid://110836424585959",
				texture = "rbxassetid://115639340495015",
				size = Vector3.new(0.154583, 0.470486, 0.491973),
				offset = CFrame.new(0.002563, -0.209114, 0.272583, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "support bracket_geom",
				mesh = "rbxassetid://86265437087420",
				texture = "rbxassetid://135241886949920",
				size = Vector3.new(0.335826, 0.514288, 0.669813),
				offset = CFrame.new(0.002563, -0.161564, 0.087036, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "launch tube_geom",
				mesh = "rbxassetid://132259949646804",
				texture = "rbxassetid://85935643696146",
				size = Vector3.new(0.564297, 0.543334, 1.8),
				offset = CFrame.new(0.001465, 0.166708, 0.002319, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
		},
	},
	OrbitBlades = {
		pose = TIP_UP,
		pieces = {
			{
				name = "handle_geom",
				mesh = "rbxassetid://86810609043595",
				texture = "rbxassetid://88258593672857",
				size = Vector3.new(1.403796, 1.696788, 0.548713),
				offset = CFrame.new(0.003323, -0.053978, 0.002808, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "blade_geom",
				mesh = "rbxassetid://111805797249407",
				texture = "rbxassetid://76585928085872",
				size = Vector3.new(0.597359, 0.360279, 0.262221),
				offset = CFrame.new(0.097012, 0.717529, 0.01709, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
		},
	},
	RattleRepeater = {
		pose = SIDE,
		pieces = {
			{
				name = "frame_geom",
				mesh = "rbxassetid://126374969669104",
				texture = "rbxassetid://124698136003779",
				size = Vector3.new(0.243315, 0.822093, 1.472568),
				offset = CFrame.new(0.000977, -0.019081, 0.16626, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "barrel_geom",
				mesh = "rbxassetid://109602097025526",
				texture = "rbxassetid://105021686329344",
				size = Vector3.new(0.110031, 0.259563, 0.756108),
				offset = CFrame.new(-0.008545, 0.294096, -0.519287, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "grip_geom",
				mesh = "rbxassetid://105502925178148",
				texture = "rbxassetid://85073537900742",
				size = Vector3.new(0.185862, 0.517064, 0.3046),
				offset = CFrame.new(-0.008179, -0.02607, 0.459106, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
		},
	},
	RitualDirk = {
		pose = TIP_UP,
		pieces = {
			{
				name = "handle_geom",
				mesh = "rbxassetid://106239108919729",
				texture = "rbxassetid://127627179055554",
				size = Vector3.new(0.712683, 0.747922, 0.284837),
				offset = CFrame.new(-0.427063, -0.528065, -0.041504, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "blade_geom",
				mesh = "rbxassetid://77639630244172",
				texture = "rbxassetid://128388177575472",
				size = Vector3.new(0.999575, 1.251128, 0.352819),
				offset = CFrame.new(0.289825, 0.272411, 0.085205, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "guard_geom",
				mesh = "rbxassetid://137289847784302",
				texture = "rbxassetid://138965403161590",
				size = Vector3.new(0.471309, 0.386858, 0.356481),
				offset = CFrame.new(-0.112793, -0.220308, -0.079102, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
		},
	},
	RuneAwl = {
		pose = TIP_UP,
		pieces = {
			{
				name = "body_geom",
				mesh = "rbxassetid://83976910151217",
				texture = "rbxassetid://117457225465209",
				size = Vector3.new(0.369398, 1.800011, 0.346932),
				offset = CFrame.new(0.001831, -0.001007, 0.002075, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
		},
	},
	ScatterBell = {
		pose = SIDE,
		pieces = {
			{
				name = "barrel_geom",
				mesh = "rbxassetid://101714287747435",
				texture = "rbxassetid://74838331138826",
				size = Vector3.new(0.18628, 0.343434, 1.119439),
				offset = CFrame.new(0.002686, 0.289324, -0.338074, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "frame_geom",
				mesh = "rbxassetid://78920889897695",
				texture = "rbxassetid://126717004258777",
				size = Vector3.new(0.227862, 0.527642, 0.688769),
				offset = CFrame.new(0.002686, 0.163555, 0.282715, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "grip_geom",
				mesh = "rbxassetid://110411671802079",
				texture = "rbxassetid://126641800508614",
				size = Vector3.new(0.23935, 0.714972, 0.495312),
				offset = CFrame.new(0.002563, -0.107691, 0.654541, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
		},
	},
	Shockwave = {
		pose = TIP_UP,
		pieces = {
			{
				name = "head_geom",
				mesh = "rbxassetid://74661663544822",
				texture = "rbxassetid://97675580873445",
				size = Vector3.new(1.132757, 0.624574, 0.552808),
				offset = CFrame.new(0.00248, 0.585379, -0.154297, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "handle_geom",
				mesh = "rbxassetid://102954427487259",
				texture = "rbxassetid://123735002370747",
				size = Vector3.new(0.334188, 1.304175, 0.669693),
				offset = CFrame.new(0.003323, -0.250248, 0.101929, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
		},
	},
	ShrapnelOrgan = {
		pose = SIDE,
		pieces = {
			{
				name = "body_geom",
				mesh = "rbxassetid://77858026128455",
				texture = "rbxassetid://107780222876988",
				size = Vector3.new(0.353317, 0.955952, 1.800011),
				offset = CFrame.new(0.002319, 0.001785, 0.000732, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
		},
	},
	SparkBolt = {
		pose = SIDE,
		pieces = {
			{
				name = "grip_geom",
				mesh = "rbxassetid://118477116035119",
				texture = "rbxassetid://79701853473719",
				size = Vector3.new(0.233438, 0.502643, 0.6539),
				offset = CFrame.new(0.003326, -0.264458, 0.375488, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "barrel_geom",
				mesh = "rbxassetid://79609995032522",
				texture = "rbxassetid://95659238941327",
				size = Vector3.new(0.426688, 0.479044, 1.013524),
				offset = CFrame.new(0.002964, 0.191238, -0.390625, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "frame_geom",
				mesh = "rbxassetid://117018206159398",
				texture = "rbxassetid://128288433899308",
				size = Vector3.new(0.426482, 0.547761, 1.308923),
				offset = CFrame.new(0.003052, 0.204372, 0.248169, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
		},
	},
	SpiritFlint = {
		pose = SIDE,
		pieces = {
			{
				name = "body_geom",
				mesh = "rbxassetid://121910231936840",
				texture = "rbxassetid://78796895419511",
				size = Vector3.new(0.2847, 0.717022, 1.194644),
				offset = CFrame.new(0.002075, 0.237017, 0.100464, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "trigger_geom",
				mesh = "rbxassetid://82380743033626",
				texture = "rbxassetid://93417993432948",
				size = Vector3.new(0.068013, 0.247578, 0.13095),
				offset = CFrame.new(0.002319, -0.092722, 0.251099, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "barrel_geom",
				mesh = "rbxassetid://82360533631978",
				texture = "rbxassetid://86776131898780",
				size = Vector3.new(0.16281, 0.221775, 0.815802),
				offset = CFrame.new(0.002686, 0.48208, -0.489868, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "cylinder_geom",
				mesh = "rbxassetid://76947428286976",
				texture = "rbxassetid://135294637222297",
				size = Vector3.new(0.3004, 0.359031, 0.350359),
				offset = CFrame.new(0.002563, 0.294628, 0.12561, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "trigger guard_geom",
				mesh = "rbxassetid://135445450894713",
				texture = "rbxassetid://112654941745937",
				size = Vector3.new(0.068379, 0.320216, 0.543495),
				offset = CFrame.new(0.001831, -0.121088, 0.232788, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "grip_geom",
				mesh = "rbxassetid://117975022360896",
				texture = "rbxassetid://105575615674533",
				size = Vector3.new(0.287455, 0.879078, 0.523619),
				offset = CFrame.new(0.001587, -0.161535, 0.640503, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
		},
	},
	ThornTrail = {
		pose = TIP_UP,
		pieces = {
			{
				name = "head_geom",
				mesh = "rbxassetid://128839126400676",
				texture = "rbxassetid://130778764767249",
				size = Vector3.new(1.076248, 0.893476, 0.870639),
				offset = CFrame.new(0.001923, 0.451134, -0.266357, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "handle_geom",
				mesh = "rbxassetid://121325011580427",
				texture = "rbxassetid://139614592012854",
				size = Vector3.new(0.229068, 1.354535, 0.944512),
				offset = CFrame.new(0.002869, -0.224865, 0.234375, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
		},
	},
	TithePalm = {
		pose = TIP_UP,
		pieces = {
			{
				name = "cuff_geom",
				mesh = "rbxassetid://93849014277504",
				texture = "rbxassetid://88173023485673",
				size = Vector3.new(0.896311, 0.327642, 0.822319),
				offset = CFrame.new(0.039062, -0.738764, 0.00293, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "glove_geom",
				mesh = "rbxassetid://119382956091648",
				texture = "rbxassetid://81280454761397",
				size = Vector3.new(1.112525, 1.215207, 0.694065),
				offset = CFrame.new(0.025879, -0.11599, 0.002563, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "fingers_geom",
				mesh = "rbxassetid://101735565705156",
				texture = "rbxassetid://134793404581223",
				size = Vector3.new(1.661199, 1.590455, 0.651688),
				offset = CFrame.new(0.002686, 0.102224, 0.007202, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
		},
	},
	WatchmanPistol = {
		pose = SIDE,
		pieces = {
			{
				name = "grip_geom",
				mesh = "rbxassetid://122145620006333",
				texture = "rbxassetid://138414495769067",
				size = Vector3.new(0.284689, 0.757829, 0.507566),
				offset = CFrame.new(0.002441, -0.189171, 0.355904, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "barrel_geom",
				mesh = "rbxassetid://128774699405316",
				texture = "rbxassetid://123631303431649",
				size = Vector3.new(0.226789, 0.284289, 1.398375),
				offset = CFrame.new(0.001221, 0.422298, 0.001083, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "frame_geom",
				mesh = "rbxassetid://119619560246495",
				texture = "rbxassetid://80042836098574",
				size = Vector3.new(0.32024, 0.526286, 1.370111),
				offset = CFrame.new(0.001953, 0.055974, 0.016838, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
		},
	},
	WinterNeedle = {
		pose = SIDE,
		pieces = {
			{
				name = "frame_geom",
				mesh = "rbxassetid://135183809951799",
				texture = "rbxassetid://101216010001623",
				size = Vector3.new(0.20412, 0.47217, 1.376542),
				offset = CFrame.new(0.008118, -0.117023, 0.213989, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "barrel_geom",
				mesh = "rbxassetid://120159727449779",
				texture = "rbxassetid://117321403844288",
				size = Vector3.new(0.101729, 0.124416, 0.920001),
				offset = CFrame.new(0.014526, 0.089891, -0.437866, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "scope_geom",
				mesh = "rbxassetid://127994893613471",
				texture = "rbxassetid://106327868912327",
				size = Vector3.new(0.211617, 0.249802, 0.603332),
				offset = CFrame.new(0.002258, 0.222618, 0.14502, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "grip_geom",
				mesh = "rbxassetid://96634733659240",
				texture = "rbxassetid://120206984808209",
				size = Vector3.new(0.105037, 0.316352, 0.293896),
				offset = CFrame.new(0.01355, -0.162617, 0.367798, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
		},
	},
	WraithHatchet = {
		pose = TIP_UP,
		pieces = {
			{
				name = "axe head_geom",
				mesh = "rbxassetid://112022665927962",
				texture = "rbxassetid://84069686215196",
				size = Vector3.new(1.282395, 0.655631, 0.318466),
				offset = CFrame.new(0.002319, 0.569164, -0.043091, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
			{
				name = "handle_geom",
				mesh = "rbxassetid://109842458967027",
				texture = "rbxassetid://112267322262186",
				size = Vector3.new(0.313548, 1.171971, 0.393102),
				offset = CFrame.new(0.001343, -0.317106, 0.009644, 1, 0, 0, 0, 1, 0, 0, 0, 1),
			},
		},
	},
}

return catalog
