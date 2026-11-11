--!strict
-- Stable native item identities/ban groups; ShopRules filters shop and crate pools with these facts.
-- Generated from docs/characters/item-groups.json; original scripts and artwork are not included.
local groups: { [string]: { string } } = {
	harvesting = {
		"item_blood_donation",
		"item_crown",
		"item_fertilizer",
		"item_tractor",
		"item_wheelbarrow",
	},
	melee_damage = {
		"item_mastery",
		"item_goat_skull",
		"item_riposte",
	},
	ranged_damage = {
		"item_lens",
	},
	melee_and_ranged_damage = {
		"item_big_arms",
		"item_hedgehog",
	},
	lifesteal = {
		"item_butterfly",
		"item_bat",
		"item_whetstone",
		"item_decomposing_flesh",
		"item_bloody_hand",
		"item_fresh_meat",
	},
	lifesteal_and_hp_regeneration = {
		"item_blood_leech",
	},
	hp_regeneration = {
		"item_mushroom",
		"item_plant",
		"item_sad_tomato",
		"item_medikit",
		"item_fairy",
		"item_potion",
		"item_fried_rice",
		"item_baby_squid",
		"item_coral",
		"item_penguin",
	},
	consumable_heal = {
		"item_jerky",
		"item_weird_food",
		"item_lemonade",
		"item_fruit_basket",
	},
	speed = {
		"item_terrified_onion",
		"item_beanie",
		"item_power_generator",
	},
	engineering = {
		"item_lighthouse",
		"item_cog",
		"item_nail",
		"item_toolbox",
		"item_book",
		"item_pencil",
	},
	elemental_damage = {
		"item_strange_book",
		"item_frozen_heart",
		"item_boiling_water",
		"item_snowball",
		"item_toxic_sludge",
		"item_fuel_tank",
		"item_will_o_the_wisp",
	},
	armor = {
		"item_stone_skin",
		"item_helmet",
		"item_metal_plate",
	},
	dodge = {
		"item_adrenaline",
		"item_chameleon",
		"item_gambling_token",
		"item_ghost_outfit",
	},
}

local nativeIds: { [string]: string } = {
	AcidVial = "item_acid",
	AmberResin = "item_honey",
	Armor = "item_metal_plate",
	AshBlindfold = "item_blindfold",
	AshSerpent = "item_snake",
	AstralPhilter = "item_alien_magic",
	BeckoningBell = "item_gentle_alien",
	Bellows = "item_eyes_surgery",
	BitterTonic = "item_celery_tea",
	BlackPowder = "item_dynamite",
	BloodChalice = "item_sunglasses",
	BloodLure = "item_bait",
	BloodOffering = "item_blood_donation",
	BoneCharm = "item_jelly",
	BoneKnuckles = "item_plant",
	BrassCarapace = "item_exoskeleton",
	BrassHarness = "item_jetpack",
	BrassSentry = "item_turret",
	Brazier = "item_campfire",
	BurstingSigil = "item_rip_and_tear",
	CalibratedTools = "item_improved_tools",
	CatClaw = "item_claw_tree",
	Changeling = "item_alien_baby",
	ChitteringFamiliar = "item_cute_monkey",
	CinderSentry = "item_turret_flame",
	ClockworkArm = "item_robot_arm",
	ClockworkGears = "item_poisonous_tonic",
	ColossusHeart = "item_octopus",
	CrackedLens = "item_glasses",
	CrackedSkull = "item_head_injury",
	CrimsonHand = "item_bloody_hand",
	DowsingRod = "item_metal_detector",
	EelFin = "item_fin",
	EightEyedIdol = "item_spider",
	EmberAnvil = "item_anvil",
	EternalFlame = "item_potato",
	EvergreenSprig = "item_grinds_magical_leaf",
	FieldCenser = "item_medikit",
	FlintShard = "item_lens",
	Focus = "item_coffee",
	FortuneCoin = "item_lucky_coin",
	FourLeafCharm = "item_clover",
	FulminateJar = "item_plastic_explosive",
	GalvanicCoil = "item_power_generator",
	GildedPlume = "item_peacock",
	GlassLantern = "item_glass_cannon",
	GourdLantern = "item_pumpkin",
	GraveSpade = "item_fertilizer",
	GrubTincture = "item_alien_worm",
	Haste = "item_beanie",
	HearthSprite = "item_fairy",
	HeavyRounds = "item_heavy_bullets",
	HollowNail = "item_sharp_bullet",
	HookedTongue = "item_alien_tongue",
	HuntersTally = "item_hunting_trophy",
	HushCandle = "item_candle",
	InkPolyp = "item_bat",
	IronGauntlet = "item_boxing_glove",
	IronShackle = "item_ball_and_chain",
	IronVigil = "item_barricade",
	JesterBell = "item_dangerous_bunny",
	Knucklebones = "item_tentacle",
	LanternCodex = "item_diploma",
	LanternOil = "item_shady_potion",
	LeechJar = "item_blood_leech",
	LoadedDice = "item_gambling_token",
	LoneFlame = "item_focus",
	Magnet = "item_boiling_water",
	MercySentry = "item_turret_healing",
	Might = "item_injection",
	MirrorShard = "item_ricochet",
	MoonGarden = "item_garden",
	MossWard = "item_tardigrade",
	MothWing = "item_butterfly",
	MourningVeil = "item_sad_tomato",
	NarrowScope = "item_cyclops_worm",
	NeedleCharm = "item_bandana",
	OathRing = "item_vigilante_ring",
	OilFlask = "item_fuel_tank",
	OrbitWisp = "item_wandering_bot",
	OrderSash = "item_black_belt",
	PawnTicket = "item_coupon",
	PlagueRat = "item_mouse",
	PowderPouch = "item_small_magazine",
	PrismSentry = "item_turret_laser",
	PulseDraught = "item_adrenaline",
	PyreAshes = "item_warrior_helmet",
	QuiltedCoat = "item_padding",
	RabbleBanner = "item_community_support",
	RecoilSpring = "item_coil",
	RollingEye = "item_cyberball",
	RottingHeart = "item_decomposing_flesh",
	RuneMine = "item_landmines",
	RustedCoin = "item_lost_duck",
	SaltCoral = "item_mushroom",
	Satchel = "item_bag",
	ScrapAltar = "item_recycling_machine",
	SecondStomach = "item_extra_stomach",
	ShadowCloak = "item_cape",
	SiegeSentry = "item_turret_rocket",
	SignalBanner = "item_banner",
	SilverRounds = "item_silver_bullet",
	SmokeMantle = "item_ghost_outfit",
	SmolderingWick = "item_scared_sausage",
	StaticBracelet = "item_energy_bracelet",
	StillVeil = "item_chameleon",
	StoneIdol = "item_statue",
	StormFamiliar = "item_tyler",
	SweetReliquary = "item_candy_bag",
	TaintedElixir = "item_defective_steroids",
	TallowCandle = "item_charcoal",
	ThornCrown = "item_wheat",
	ThunderShells = "item_explosive_shells",
	TitanArms = "item_big_arms",
	TitanGirdle = "item_giant_belt",
	TitheBox = "item_piggy_bank",
	TomeOfEchoes = "item_bean_teacher",
	VelvetDivan = "item_estys_couch",
	Vitality = "item_cake",
	WardRune = "item_peaceful_bee",
	WaxHeart = "item_broken_mouth",
	Whetstone = "item_mastery",
	WispJar = "item_baby_elephant",
	WitchKettle = "item_lemonade",
	WitchMortar = "item_gnome",
	LumberjackShirt = "item_lumberjack_shirt",
	DigSite = "item_dig_site",
	BonkDog = "item_bonk_dog",
	Ratzilla = "item_ratzilla",
	BotOMine = "item_bot_o_mine",
	Blazemander = "item_blazemander",
}

local tags: { [string]: { string } } = {
	AcidVial = {
		"stat_max_hp",
	},
	AmberResin = {
		"stat_ranged_damage",
		"explosive",
	},
	Armor = {
		"stat_armor",
	},
	AshBlindfold = {
		"stat_crit_chance",
		"stat_dodge",
	},
	AshSerpent = {
		"stat_elemental_damage",
	},
	AstralPhilter = {
		"stat_max_hp",
		"stat_hp_regeneration",
	},
	BeckoningBell = {
		"stat_max_hp",
		"stat_percent_damage",
		"more_enemies",
	},
	Bellows = {
		"stat_elemental_damage",
	},
	BitterTonic = {
		"xp_gain",
	},
	BlackPowder = {
		"explosive",
	},
	BloodChalice = {
		"stat_crit_chance",
	},
	BloodLure = {
		"stat_percent_damage",
		"number_of_enemies",
	},
	BloodOffering = {
		"stat_harvesting",
	},
	BoneCharm = {
		"stat_max_hp",
	},
	BoneKnuckles = {
		"stat_hp_regeneration",
	},
	BrassCarapace = {
		"stat_armor",
		"stat_crit_chance",
		"stat_engineering",
		"stat_speed",
	},
	BrassHarness = {
		"stat_speed",
		"stat_dodge",
	},
	BrassSentry = {
		"stat_engineering",
		"structure",
	},
	Brazier = {
		"stat_elemental_damage",
		"stat_hp_regeneration",
	},
	BurstingSigil = {
		"stat_melee_damage",
		"explosive",
	},
	CalibratedTools = {
		"structure",
		"stat_attack_speed",
	},
	CatClaw = {
		"stat_melee_damage",
		"stat_crit_chance",
	},
	Changeling = {
		"stat_max_hp",
	},
	ChitteringFamiliar = {
		"pickup",
	},
	CinderSentry = {
		"stat_engineering",
		"structure",
	},
	ClockworkArm = {
		"stat_melee_damage",
		"stat_engineering",
	},
	ClockworkGears = {
		"stat_attack_speed",
		"stat_crit_chance",
		"stat_range",
	},
	ColossusHeart = {
		"stat_max_hp",
		"stat_lifesteal",
		"stat_hp_regeneration",
	},
	CrackedLens = {
		"stat_range",
	},
	CrackedSkull = {
		"stat_percent_damage",
	},
	CrimsonHand = {
		"stat_lifesteal",
	},
	DowsingRod = {
		"stat_luck",
		"stat_engineering",
		"pickup",
		"economy",
	},
	EelFin = {
		"stat_speed",
		"stat_lifesteal",
	},
	EightEyedIdol = {
		"stat_percent_damage",
		"stat_attack_speed",
	},
	EmberAnvil = {},
	EternalFlame = {
		"stat_max_hp",
		"stat_hp_regeneration",
		"stat_percent_damage",
		"stat_speed",
		"stat_luck",
	},
	EvergreenSprig = {
		"stat_max_hp",
		"stat_hp_regeneration",
		"stat_lifesteal",
	},
	FieldCenser = {
		"stat_hp_regeneration",
	},
	FlintShard = {
		"stat_ranged_damage",
	},
	Focus = {
		"stat_attack_speed",
	},
	FortuneCoin = {
		"stat_crit_chance",
		"stat_luck",
	},
	FourLeafCharm = {
		"stat_luck",
		"stat_dodge",
	},
	FulminateJar = {
		"explosive",
	},
	GalvanicCoil = {
		"stat_speed",
		"stat_percent_damage",
	},
	GildedPlume = {
		"xp_gain",
	},
	GlassLantern = {
		"stat_percent_damage",
	},
	GourdLantern = {
		"stat_ranged_damage",
	},
	GraveSpade = {
		"stat_harvesting",
	},
	GrubTincture = {
		"stat_max_hp",
		"stat_hp_regeneration",
	},
	Haste = {
		"stat_speed",
	},
	HearthSprite = {
		"stat_hp_regeneration",
	},
	HeavyRounds = {
		"stat_ranged_damage",
		"stat_percent_damage",
		"stat_range",
	},
	HollowNail = {
		"stat_ranged_damage",
	},
	HookedTongue = {
		"pickup",
		"knockback",
	},
	HuntersTally = {
		"stat_crit_chance",
	},
	HushCandle = {
		"stat_elemental_damage",
		"stat_hp_regeneration",
		"less_enemies",
	},
	InkPolyp = {
		"stat_lifesteal",
	},
	IronGauntlet = {
		"stat_melee_damage",
		"knockback",
	},
	IronShackle = {
		"stat_percent_damage",
		"stat_armor",
		"knockback",
	},
	IronVigil = {
		"stat_armor",
		"stand_still",
		"knockback",
	},
	JesterBell = {
		"economy",
	},
	Knucklebones = {
		"stat_crit_chance",
	},
	LanternCodex = {
		"stat_engineering",
		"xp_gain",
	},
	LanternOil = {
		"stat_luck",
	},
	LeechJar = {
		"stat_lifesteal",
		"stat_hp_regeneration",
	},
	LoadedDice = {
		"stat_dodge",
	},
	LoneFlame = {
		"stat_percent_damage",
	},
	Magnet = {
		"stat_elemental_damage",
	},
	MercySentry = {
		"stat_engineering",
		"structure",
	},
	Might = {
		"stat_percent_damage",
	},
	MirrorShard = {
		"stat_ranged_damage",
	},
	MoonGarden = {
		"consumable",
		"structure",
	},
	MossWard = {},
	MothWing = {
		"stat_lifesteal",
	},
	MourningVeil = {
		"stat_hp_regeneration",
	},
	NarrowScope = {
		"stat_percent_damage",
	},
	NeedleCharm = {
		"stat_ranged_damage",
	},
	OathRing = {
		"stat_percent_damage",
	},
	OilFlask = {
		"stat_elemental_damage",
	},
	OrbitWisp = {
		"less_enemy_speed",
		"structure",
		"pet",
	},
	OrderSash = {
		"stat_melee_damage",
		"xp_gain",
		"knockback",
	},
	PawnTicket = {
		"economy",
	},
	PlagueRat = {
		"stat_lifesteal",
		"more_enemies",
	},
	PowderPouch = {
		"stat_ranged_damage",
		"stat_attack_speed",
	},
	PrismSentry = {
		"stat_engineering",
		"structure",
	},
	PulseDraught = {
		"stat_dodge",
	},
	PyreAshes = {
		"stat_armor",
		"stat_max_hp",
	},
	QuiltedCoat = {
		"stat_max_hp",
	},
	RabbleBanner = {
		"stat_attack_speed",
	},
	RecoilSpring = {
		"stat_percent_damage",
		"knockback",
	},
	RollingEye = {
		"stat_luck",
	},
	RottingHeart = {
		"stat_lifesteal",
	},
	RuneMine = {
		"stat_engineering",
		"explosive",
		"structure",
	},
	RustedCoin = {
		"stat_luck",
	},
	SaltCoral = {
		"stat_hp_regeneration",
	},
	Satchel = {
		"stat_luck",
		"exploration",
		"economy",
	},
	ScrapAltar = {
		"economy",
	},
	SecondStomach = {
		"stat_max_hp",
		"stat_luck",
	},
	ShadowCloak = {
		"stat_lifesteal",
		"stat_dodge",
	},
	SiegeSentry = {
		"stat_engineering",
		"structure",
	},
	SignalBanner = {
		"stat_range",
		"stat_attack_speed",
	},
	SilverRounds = {
		"stat_percent_damage",
	},
	SmokeMantle = {
		"stat_dodge",
	},
	SmolderingWick = {
		"stat_elemental_damage",
	},
	StaticBracelet = {
		"stat_crit_chance",
		"stat_elemental_damage",
	},
	StillVeil = {
		"stat_dodge",
		"stand_still",
	},
	StoneIdol = {
		"stat_attack_speed",
		"stand_still",
	},
	StormFamiliar = {
		"stat_engineering",
		"stat_elemental_damage",
		"structure",
	},
	SweetReliquary = {},
	TaintedElixir = {
		"stat_max_hp",
		"stat_melee_damage",
	},
	TallowCandle = {
		"stat_elemental_damage",
		"stat_melee_damage",
	},
	ThornCrown = {
		"stat_melee_damage",
		"stat_ranged_damage",
		"stat_harvesting",
	},
	ThunderShells = {
		"explosive",
	},
	TitanArms = {
		"stat_melee_damage",
		"stat_ranged_damage",
		"knockback",
	},
	TitanGirdle = {
		"stat_crit_chance",
	},
	TitheBox = {},
	TomeOfEchoes = {
		"xp_gain",
	},
	VelvetDivan = {
		"stat_hp_regeneration",
		"stat_max_hp",
	},
	Vitality = {
		"stat_max_hp",
	},
	WardRune = {
		"stat_dodge",
		"stat_harvesting",
	},
	WaxHeart = {
		"stat_max_hp",
	},
	Whetstone = {
		"stat_melee_damage",
	},
	WispJar = {
		"stat_luck",
		"pickup",
	},
	WitchKettle = {
		"consumable",
	},
	WitchMortar = {
		"stat_melee_damage",
		"stat_elemental_damage",
	},
	LumberjackShirt = {
		"exploration",
	},
	DigSite = {
		"stat_luck",
	},
	BonkDog = {
		"stat_melee_damage",
		"explosive",
		"pet",
	},
	Ratzilla = {
		"stat_max_hp",
		"pet",
	},
	BotOMine = {
		"stat_engineering",
		"pet",
		"structure",
	},
	Blazemander = {
		"stat_elemental_damage",
		"pet",
	},
}

return table.freeze({
	groups = groups,
	nativeIds = nativeIds,
	tags = tags,
	endlessBannedItems = {
		"item_piggy_bank",
		"item_crown",
	},
})
