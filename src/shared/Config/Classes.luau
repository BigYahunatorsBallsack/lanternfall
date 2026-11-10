--!strict
-- B10 character packages read by CharacterRules, services and lobby. References: docs/B10-CHARAKTERE.md.
-- HP uses the original Brotato scale. Legacy ids remain valid; unlock progression belongs to package 13.
local Catalog = require(script.Parent.CharacterCatalog)
local Artwork = require(script.Parent.Parent.Util.CharacterArtwork)
type CharacterArtwork = { image: string?, height: number?, ground: number?, center: number?, nativeVersion: string? }
local SpriteImages: { characters: { [string]: CharacterArtwork } } = require(script.Parent.SpriteImages)
export type Class = {
	id: string,
	displayName: string,
	startWeapon: string,
	startWeapons: { string },
	stats: { [string]: number },
	gainMultipliers: { [string]: number }?,
	free: boolean,
	available: boolean,
	emberPrice: number?,
	description: string,
	ruleRows: { { { text: string?, stat: string?, coefficient: number? } } }?,
	maxWeapons: number?,
	weaponKind: string?,
	kindLimits: { [string]: number }?,
	extraWeapons: { string }?,
	startWeaponTiers: { [string]: number }?,
	extraWeaponTiers: { [string]: number }?,
	startItems: { string }?,
	wantedTags: { string }?,
	perWeapon: { [string]: number }?,
	perDistinctWeapon: { [string]: number }?,
	conversions: { { source: string, target: string, per: number, amount: number, permanentOnly: boolean? } }?,
	perLevel: { [string]: number }?,
	noHeal: boolean?,
	oneHit: boolean?,
	noWaveHeal: boolean?,
	canAttackWhileMoving: boolean?,
	minWeaponTier: number?,
	maxWeaponTier: number?,
	noDuplicateWeapons: boolean?,
	baseWeaponSlots: number?,
	slotUpgradeAmount: number?,
	maxWeaponSlots: number?,
	weaponClassStats: { [string]: { [string]: number } }?,
	weaponKindStats: { [string]: { [string]: number } }?,
	perTierWeapon: { [number]: { [string]: number } }?,
	setCountBonus: number?,
	allWeaponsForSets: boolean?,
	native: Catalog.CatalogCharacter?,
	nativeStartSelection: boolean?,
	nativeCodeReady: boolean?,
	pendingNative: Class?,
}
local Classes: { [string]: Class } = {
	SparkMage = {
		id = "SparkMage",
		displayName = "Spark Mage",
		startWeapon = "GalvanicFork",
		startWeapons = { "GalvanicFork", "WinterNeedle", "RattleRepeater", "ScatterBell" },
		free = true,
		available = true,
		description = "Elemental gains x1.25; melee/ranged gains x0; Engineering gains x0.5. Starts with Ash Serpent and Smoldering Wick.",
		stats = {},
		gainMultipliers = { elementalDamage = 1.25, meleeDamage = 0, rangedDamage = 0, engineering = 0.5 },
		startItems = { "AshSerpent", "SmolderingWick" },
		wantedTags = { "elementalDamage" },
	},
	NightWatch = {
		id = "NightWatch",
		displayName = "Night Watch",
		startWeapon = "WatchmanPistol",
		startWeapons = { "WatchmanPistol", "RattleRepeater", "ScatterBell", "ShrapnelOrgan" },
		free = true,
		available = true,
		description = "+50 Range and an extra Pistol. Ranged weapons only. Ranged gains x1.5; Max HP gains x0.75.",
		stats = { range = 50 },
		extraWeapons = { "WatchmanPistol" },
		weaponKind = "Ranged",
		gainMultipliers = { rangedDamage = 1.5, maxHp = 0.75 },
		wantedTags = { "rangedDamage", "range" },
	},
	ManyHands = {
		id = "ManyHands",
		displayName = "Many Hands",
		startWeapon = "BrassKnuckles",
		startWeapons = { "BrassKnuckles", "RattleRepeater", "RitualDirk", "Gravestone" },
		free = true,
		available = true,
		description = "12 weapon slots. +20% Damage; -5% Damage for each held weapon.",
		stats = { damage = 20 },
		maxWeapons = 12,
		perWeapon = { damage = -5 },
	},
	SoleConductor = {
		id = "SoleConductor",
		displayName = "Sole Conductor",
		startWeapon = "RattleRepeater",
		startWeapons = { "RattleRepeater", "ScatterBell", "ShrapnelOrgan", "WraithHatchet", "GalvanicFork" },
		free = true,
		available = true,
		description = "One weapon slot. +200% Attack Speed. Damage gains x2.",
		stats = { attackSpeed = 200 },
		maxWeapons = 1,
		gainMultipliers = { damage = 2 },
		wantedTags = { "damage" },
	},
	DuelMaestro = {
		id = "DuelMaestro",
		displayName = "Duel Maestro",
		startWeapon = "RitualDirk",
		startWeapons = { "RitualDirk", "BrassKnuckles", "LamplighterPike", "SpiritFlint" },
		free = true,
		available = true,
		description = "Melee only. +5 Melee Damage, -40% Attack Speed, -30 Luck. +20% Attack Speed per different weapon.",
		stats = { meleeDamage = 5, attackSpeed = -40, luck = -30 },
		weaponKind = "Melee",
		perDistinctWeapon = { attackSpeed = 20 },
		wantedTags = { "meleeDamage" },
	},
	FarSeer = {
		id = "FarSeer",
		displayName = "Far Seer",
		startWeapon = "ScatterBell",
		startWeapons = { "ScatterBell", "LamplighterPike", "WinterNeedle" },
		free = true,
		available = true,
		description = "+100 Range; +1% Damage per 10 Range. Crit gains x1.25; Max HP gains x0.67; Harvesting gains x0.",
		stats = { range = 100 },
		gainMultipliers = { critChance = 1.25, harvesting = 0, maxHp = 0.67 },
		conversions = { { source = "range", target = "damage", per = 10, amount = 1 } },
		wantedTags = { "range", "critChance" },
	},
	MarbleHost = {
		id = "MarbleHost",
		displayName = "Marble Host",
		startWeapon = "Gravestone",
		startWeapons = { "Gravestone", "BrassKnuckles", "ScatterBell", "GalvanicFork", "ShrapnelOrgan" },
		free = true,
		available = true,
		description = "Max HP gains x1.25; +1% Damage per 3 permanent Max HP. +3 Fruit Healing, -100% Life Steal. Regen/Dodge gains x0.5; Speed gains x0.",
		stats = { fruitHeal = 3, lifeSteal = -100 },
		gainMultipliers = { maxHp = 1.25, hpRegen = 0.5, dodge = 0.5, speed = 0 },
		conversions = { { source = "maxHp", target = "damage", per = 3, amount = 1, permanentOnly = true } },
		wantedTags = { "maxHp", "luck", "consumable" },
	},
	TwinLedger = {
		id = "TwinLedger",
		displayName = "Twin Ledger",
		startWeapon = "RitualDirk",
		startWeapons = { "RitualDirk", "BrassKnuckles", "ScatterBell", "RattleRepeater" },
		free = true,
		available = true,
		description = "Three melee and three ranged slots. +2 Melee per Ranged Damage; +1 Ranged per 2 Melee Damage (no feedback loop).",
		stats = {},
		kindLimits = { Melee = 3, Ranged = 3 },
		wantedTags = { "meleeDamage", "rangedDamage" },
		conversions = {
			{ source = "rangedDamage", target = "meleeDamage", per = 1, amount = 2 },
			{ source = "meleeDamage", target = "rangedDamage", per = 2, amount = 1 },
		},
	},
	CandleScholar = {
		id = "CandleScholar",
		displayName = "Candle Scholar",
		startWeapon = "RitualDirk",
		startWeapons = { "RitualDirk", "RattleRepeater", "GalvanicFork", "LeechCarbine", "SpiritFlint" },
		free = true,
		available = true,
		description = "Each team level: +2 Melee, +1 Ranged, +1 Elemental, +1 Engineering, -2 Max HP (plus normal level HP).",
		stats = {},
		perLevel = { meleeDamage = 2, rangedDamage = 1, elementalDamage = 1, engineering = 1, maxHp = -2 },
		wantedTags = { "xpGain" },
	},
}
-- Retired profile ids remain resolvable but cannot be selected or unlocked in B10.
Classes.LanternKeeper = {
	id = "LanternKeeper",
	displayName = "Lantern Keeper",
	startWeapon = "WatchmanPistol",
	startWeapons = { "WatchmanPistol" },
	stats = {},
	free = false,
	available = false,
	description = "Retired prototype",
}
Classes.Trapper = {
	id = "Trapper",
	displayName = "Trapper",
	startWeapon = "ThornTrail",
	startWeapons = { "ThornTrail" },
	stats = {},
	free = false,
	available = false,
	description = "Retired prototype",
}

-- Source-complete records remain unavailable until their runtime dependencies and selection paths are verified.
-- Existing profile ids retain the delivered behavior while the complete native packages are integrated.
local preparedLegacy = { SparkMage = true, NightWatch = true, TwinLedger = true }
for id, source in Catalog do
	if Classes[id] and not preparedLegacy[id] then
		Classes[id].native = source
		continue
	end
	local startTiers: { [string]: number } = {}
	for _, choice in source.startChoices do
		startTiers[choice.id] = choice.tier
	end
	local conversions = {}
	for _, conversion in source.conversions do
		if conversion.sourceKind == "Stat" then
			table.insert(conversions, conversion)
		end
	end
	local package: Class = {
		id = id,
		displayName = source.displayName,
		startWeapon = source.startWeapon,
		startWeapons = source.startWeapons,
		startWeaponTiers = startTiers,
		extraWeapons = source.extraWeapons,
		extraWeaponTiers = source.extraWeaponTiers,
		startItems = source.startItems,
		stats = source.stats,
		gainMultipliers = source.gainMultipliers,
		perLevel = source.perLevel,
		perWeapon = source.perWeapon,
		perDistinctWeapon = source.perDistinctWeapon,
		perTierWeapon = source.perTierWeapon,
		weaponClassStats = source.weaponClassStats,
		weaponKindStats = source.weaponKindStats,
		conversions = conversions,
		maxWeapons = source.maxWeapons,
		weaponKind = source.weaponKind,
		kindLimits = source.kindLimits,
		minWeaponTier = source.minWeaponTier,
		maxWeaponTier = source.maxWeaponTier,
		baseWeaponSlots = source.baseWeaponSlots,
		slotUpgradeAmount = source.slotUpgradeAmount,
		maxWeaponSlots = source.maxWeaponSlots,
		noDuplicateWeapons = source.noDuplicateWeapons,
		noHeal = source.noHeal,
		oneHit = source.oneHit,
		noWaveHeal = source.noWaveHeal,
		canAttackWhileMoving = source.canAttackWhileMoving,
		setCountBonus = source.setCountBonus,
		allWeaponsForSets = source.allWeaponsForSets,
		wantedTags = source.wantedTags,
		free = source.free,
		available = false,
		description = source.displayName,
		native = source,
		nativeStartSelection = true,
	}
	if Classes[id] then
		-- Saved ids and existing public art keep their old package until original art can promote atomically.
		Classes[id].native = source
		Classes[id].pendingNative = package
		Artwork.promote(Classes[id], package, SpriteImages.characters[id])
	else
		Classes[id] = package
	end
end
-- Native free character with complete existing equipment and no outstanding behavior dependencies.
-- Text follows the stable English translation keys recorded in docs/characters/README.md.
Classes.Crazy.nativeCodeReady = true
Classes.Crazy.description =
	"+100 Range with Precise weapons\n+25 % Attack Speed\nYou start with 1 Knife\n-30 % Dodge\n-10 Engineering\n-10 Ranged Damage"
Classes.Brawler.nativeCodeReady = true
Classes.Brawler.description =
	"+50 % Attack Speed with Unarmed weapons\nYou start with 1 Fist\n+15 % Dodge\n-50 Range\n-50 Ranged Damage"
Classes.Ghost.nativeCodeReady = true
Classes.Ghost.description = "+10 Damage with Ethereal weapons\n+30 % Dodge\nDodge is capped at 90%\n-100 Armor"
Classes.Bull.nativeCodeReady = true
Classes.Bull.description =
	"+20 Max HP\n+15 HP Regeneration\n+10 Armor\nHP Regeneration modifications are increased by 50%\nYou explode for 30 (300% Melee Damage 300% Ranged Damage 300% Elemental Damage) damage when you take damage\nYou can’t equip weapons"
Classes.Bull.ruleRows = {
	{ { text = "+20 Max HP" } },
	{ { text = "+15 HP Regeneration" } },
	{ { text = "+10 Armor" } },
	{ { text = "HP Regeneration modifications are increased by 50%" } },
	{
		{ text = "You explode for 30 (" },
		{ stat = "meleeDamage", coefficient = 300 },
		{ text = " " },
		{ stat = "rangedDamage", coefficient = 300 },
		{ text = " " },
		{ stat = "elementalDamage", coefficient = 300 },
		{ text = ") damage when you take damage" },
	},
	{ { text = "You can’t equip weapons" } },
}
Classes.Doctor.nativeCodeReady = true
Classes.Doctor.description =
	"+200 % Attack Speed with Medical weapons\n+5 HP Regeneration\n+5 Harvesting\nHP Regeneration modifications are increased by 100%\n-100 % Attack Speed\nArmor modifications are reduced by 50%"
Classes.Pacifist.nativeCodeReady = true
Classes.Pacifist.description =
	"Gain 0.65 material and XP for every living enemy at the end of a wave\nYou start with 1 Lumberjack Shirt\n-100 % Damage\n-100 Engineering"
Classes.Artificer.nativeCodeReady = true
Classes.Artificer.description =
	"+175 % Explosion Damage\n+4 % Explosion Size for every 1 Elemental Damage you have\n+100 % Damage with Tools\n-100 % Damage\nArmor modifications are reduced by 50%"
Classes.ArmsDealer.nativeCodeReady = true
Classes.ArmsDealer.description =
	"-95 % Weapons Price\n+30 Harvesting\nDamage modifications are increased by 33%\nYou start with 1 Dangerous Bunny\nShops always sell at least one weapon\nAll of your weapons are destroyed when entering a shop"
-- Original art is delivered independently; ready code never bypasses the approved-sprite requirement.
Classes.Wildling.description =
	"+30 % Life Steal with Primitive weapons\nYou start with 1 Stick\nYou can’t equip weapons above tier II"
Classes.Cryptid.description =
	"+6 Trees\nGain 12 material and XP for every living tree at the end of a wave\n+3 HP Regeneration for every current living tree [0]\nDodge is capped at 70%\n+3 % Attack Speed until the end of the wave when you dodge an attack\n-100 % Life Steal\n-100 Range\n-50 % materials dropped from enemies"
Classes.Cryptid.nativeCodeReady = true
Classes.Technomage.nativeCodeReady = true
Classes.Technomage.description =
	"+5 % Structure attack speed for every 1 Elemental Damage you have [0]\nYou start with 2 Turrets\n+2 Elemental Damage for every structure you have [0]\n+75% XP required to level up\nMelee Damage modifications are reduced by 100%\nRanged Damage modifications are reduced by 100%"
local mage = Classes.SparkMage.pendingNative or Classes.SparkMage
mage.nativeCodeReady = true
mage.description =
	"Elemental Damage modifications are increased by 25%\nYou start with 1 Snake\nYou start with 1 Scared Sausage\nMelee Damage modifications are reduced by 100%\nRanged Damage modifications are reduced by 100%\nEngineering modifications are reduced by 50%"
local ranger = Classes.NightWatch.pendingNative or Classes.NightWatch
ranger.nativeCodeReady = true
ranger.description =
	"+50 Range\nYou start with 1 Pistol\nRanged Damage modifications are increased by 50%\nYou can’t equip melee weapons\nMax HP modifications are reduced by 25%"
Classes.Renegade.nativeCodeReady = true
Classes.Renegade.description =
	"+2 Projectiles\nProjectiles pierce through 1 additional target\n+10 % Damage for every different tier I item you have [0]\n-400 % Damage\n-50 % Accuracy\nDamage modifications are reduced by 80%"
Classes.WellRounded.nativeCodeReady = true
Classes.WellRounded.description = "+5 Max HP\n+5 % Speed\n+8 Harvesting"
local generalist = Classes.TwinLedger.pendingNative or Classes.TwinLedger
generalist.nativeCodeReady = true
generalist.description =
	"+2 Melee Damage for every 1 Ranged Damage you have [0]\n+1 Ranged Damage for every 2 Melee Damage you have [0]\nYou can only equip 3 melee weapons and 3 ranged weapons at a time"
Classes.Farmer.nativeCodeReady = true
Classes.Farmer.description =
	"+20 Harvesting\nHarvesting increases by an additional 3% at the end of a wave\n+1 Harvesting when picking up a consumable while at maximum health\nYou start with 1 Garden\n-50 % materials dropped from enemies"
Classes.Saver.nativeCodeReady = true
Classes.Saver.description =
	"+15 Harvesting\nYou start with 1 Piggy Bank\n+1 % Damage for every 25 materials you have [0]\n+50 % Item Prices"
Classes.Glutton.nativeCodeReady = true
Classes.Glutton.description =
	"+50 Luck\n+1 % Explosion Damage when picking up a consumable while at maximum health\nConsumables have a 100% chance to explode for 10 (500% Melee Damage) damage when picked up\n+25 % Item Prices\n-25 % XP Gain"
Classes.Lucky.nativeCodeReady = true
Classes.Lucky.description =
	"+100 Luck\nLuck modifications are increased by 25%\n75% chance to deal 1 (15% Luck) damage to a random enemy when you pick up a material\n-60 % Attack Speed\n-50 % XP Gain"
Classes.Sick.nativeCodeReady = true
Classes.Sick.description =
	"+12 Max HP\n+25 % Life Steal\nYou take 1 damage per second (does not give invulnerability time)\n-100 HP Regeneration"
Classes.Engineer.nativeCodeReady = true
Classes.Engineer.description =
	"+10 Engineering\nEngineering modifications are increased by 25%\nYou start with 1 Wrench\nStructures spawn close to each other\nDamage modifications are reduced by 50%"
Classes.Streamer.nativeCodeReady = true
Classes.Streamer.description =
	"+3% of your materials (25 max) per second while standing still\n+40 % Damage while moving\n+40 % Attack Speed while moving\n+2 Armor for every 1 structure you have [0]\n-50 % materials dropped\n-1 % Damage for every 15 materials you have [0]\n-1 % Speed for every 30 materials you have [0]"
Classes.Lich.nativeCodeReady = true
Classes.Lich.description =
	"+10 HP Regeneration\n+10 % Life Steal\n100% chance to deal 1 (100% Max HP) damage to a random enemy when you heal\nDamage modifications are reduced by 50%"

for id, class in Classes do
	if not class.nativeCodeReady then
		continue
	end
	class.available = Artwork.valid(SpriteImages.characters[id], preparedLegacy[id])
end
return table.freeze(Classes)
