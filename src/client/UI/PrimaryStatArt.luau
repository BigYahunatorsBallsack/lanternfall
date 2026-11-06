--!strict
-- Original wiki artwork for Icons and StatImages; source files and upload IDs live in assets/ui/stats/brotato.
local stats: { [string]: string } = {
	maxHp = "rbxassetid://84827197015332",
	hpRegen = "rbxassetid://89515405517156",
	lifeSteal = "rbxassetid://122896907975213",
	damage = "rbxassetid://72661378304647",
	meleeDamage = "rbxassetid://71580107038050",
	rangedDamage = "rbxassetid://77408872064411",
	elementalDamage = "rbxassetid://131593297959422",
	attackSpeed = "rbxassetid://93523575652422",
	critChance = "rbxassetid://113071052484562",
	engineering = "rbxassetid://127093973797687",
	range = "rbxassetid://132161100587128",
	armor = "rbxassetid://94107945232558",
	dodge = "rbxassetid://90001396930266",
	speed = "rbxassetid://92361365746773",
	luck = "rbxassetid://111193307612951",
	harvesting = "rbxassetid://112833336882610",
}
local upgrades: { [string]: string } = {
	maxHp = "rbxassetid://87800264434768",
	hpRegen = "rbxassetid://79508940433777",
	lifeSteal = "rbxassetid://92995587127722",
	damage = "rbxassetid://95161157003841",
	meleeDamage = "rbxassetid://105396859037041",
	rangedDamage = "rbxassetid://87735256510505",
	elementalDamage = "rbxassetid://96308068299734",
	attackSpeed = "rbxassetid://109653557359587",
	critChance = "rbxassetid://90118934453139",
	engineering = "rbxassetid://102704583216699",
	range = "rbxassetid://118660467219436",
	armor = "rbxassetid://108237415938408",
	dodge = "rbxassetid://123067806206951",
	speed = "rbxassetid://126022547783892",
	luck = "rbxassetid://119230104481038",
	harvesting = "rbxassetid://98204305452902",
}

return table.freeze({ stats = table.freeze(stats), upgrades = table.freeze(upgrades) })
