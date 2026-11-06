"""Compile factual base-game weapon data from the owner's Brotato wiki source.

Inputs are local snapshots of Weapons and Template:Weapon_Data. No network writes.
"""
import html
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/weapons/brotato-base"
OUT.mkdir(parents=True, exist_ok=True)
RAW = (ROOT / "weapon-data-wiki.txt").read_text(encoding="utf-8")
PAGE = (ROOT / "weapons-wiki.html").read_text(encoding="utf-8")

LEGACY = {
    "Circular Saw": "OrbitBlades", "Wand": "SparkBolt", "Hammer": "Shockwave",
    "Lightning Shiv": "ChainLightning", "Pruner": "ThornTrail", "Crossbow": "BoomerangAxe",
    "Fist": "BrassKnuckles", "Knife": "RitualDirk", "Spear": "LamplighterPike",
    "Sword": "DuskSabre", "Rock": "Gravestone", "Hand": "TithePalm",
    "Ghost Axe": "WraithHatchet", "Ghost Flint": "SpiritFlint", "Pistol": "WatchmanPistol",
    "SMG": "RattleRepeater", "Double Barrel Shotgun": "ScatterBell", "Shredder": "ShrapnelOrgan",
    "Flamethrower": "CinderBreath", "Taser": "GalvanicFork", "Medical Gun": "LeechCarbine",
    "Gatling Laser": "CathedralEngine", "Rocket Launcher": "MortarLantern", "Icicle": "WinterNeedle",
    "Wrench": "FoundryKey", "Screwdriver": "RuneAwl",
}
CLASSES = dict(zip(
    "Legendary Blade Blunt Elemental Ethereal Explosive Gun Heavy Medical Medieval Musical Precise Primitive Support Unarmed Tool".split(),
    "Dread Edge Bludgeon Arcane Spectral Volatile Longshot Colossal Remedy Knightly Choir Keen Primal Steward Brawl Artisan".split(),
))
STATS = {"MeleeDamage": "meleeDamage", "RangedDamage": "rangedDamage", "ElementalDamage": "elementalDamage",
         "Melee Damage": "meleeDamage", "Ranged Damage": "rangedDamage", "Elemental Damage": "elementalDamage",
         "Engineering": "engineering", "Armor": "armor", "Range": "range", "AttackSpeed": "attackSpeed",
         "Attack Speed": "attackSpeed", "Level": "level", "Max HP": "maxHp", "Speed": "speed",
         "LifeSteal": "lifeSteal", "Lifesteal": "lifeSteal", "Luck": "luck", "Dodge": "dodge", "Harvesting": "harvesting"}

def field(block, name):
    m = re.search(r"\n\t\|" + name + r"=(.*?)(?=\n\t\||\n}})", block, re.S)
    return m[1].strip() if m else ""

def tiers(text):
    rows = re.findall(r"\|([1-4])\|(?:common|rare|epic|legendary)=(.*?)(?=\n\s*\||\n|$)", text)
    if not rows:
        return [text] * 4
    result = [None] * 4
    for tier, value in rows:
        result[int(tier) - 1] = value.strip()
    return result

def number(s):
    if s is None or s.strip() == "-":
        return None
    return float(re.search(r"-?\d+(?:\.\d+)?", s)[0])

def lua(value, indent=0):
    if value is None: return "nil"
    if isinstance(value, bool): return str(value).lower()
    if isinstance(value, str): return json.dumps(value, ensure_ascii=False)
    if isinstance(value, (float, int)): return str(round(value, 9)).removesuffix(".0")
    if isinstance(value, list): return "{ " + ", ".join(lua(v, indent+1) for v in value) + " }"
    if not value: return "{}"
    pad = "\t" * (indent + 1)
    return "{\n" + "\n".join(pad + (k if re.fullmatch(r"[A-Za-z_]\w*", k) else "["+lua(k)+"]") + " = " + lua(v, indent+1) + "," for k,v in value.items()) + "\n" + "\t"*indent + "}"

parts = re.split(r"\n\|([^\n=]+)\s*=\s*\{\{#switch:", RAW)[1:]
records = []
for key, block in zip(parts[::2], parts[1::2]):
    if field(block, "isdlc") == "1": continue
    row = next(r for r in re.findall(r"<tr>.*?</tr>", PAGE, re.S)
               if re.search(r'title="' + re.escape(key.strip()) + '"', r, re.I))
    name = html.unescape(re.search(r'<strong>(.*?)</strong>', row)[1])
    img = re.search(r'<img[^>]+src="([^"]+)"', row)[1]
    img = re.sub(r"/images/thumb/(.*?)/[^/]+$", r"/images/\1", img)
    ident = LEGACY.get(name, re.sub(r"[^A-Za-z0-9]", "", name))
    damages = tiers(field(block, "damage"))
    min_tier = next(i+1 for i,d in enumerate(damages) if number(d) is not None)
    stats = []
    scales = []
    fields = {f: tiers(field(block, f)) for f in ["attackspeed", "crit", "range", "knockback", "lifesteal", "price"]}
    for t in range(4):
        d = damages[t]
        if number(d) is None:
            stats.append(None); scales.append({}); continue
        scaling = {}
        for share, stat in re.findall(r"([\d.]+)%\s*\{\{StatIcon\|([^}]+)}}", d):
            assert stat in STATS, (name, stat)
            scaling[STATS[stat]] = float(share) / 100
        crit = fields["crit"][t]
        crits = re.findall(r"[\d.]+", crit)
        stats.append({"damage": number(d), "cooldown": number(fields["attackspeed"][t]),
                      "range": number(fields["range"][t]), "knockback": number(fields["knockback"][t]),
                      "critDamage": float(crits[0]), "critChance": float(crits[1]) / 100,
                      "lifeSteal": (number(fields["lifesteal"][t]) or 0) / 100,
                      "price": number(fields["price"][t])})
        scales.append(scaling)
    kind = "Melee" if PAGE.index(row) < PAGE.index('id="Ranged_Weapons"') else "Ranged"
    records.append({"id": ident, "name": name, "kind": kind, "minTier": min_tier,
                    "classes": re.findall(r"\[\[([^]|]+)", field(block,"types")),
                    "attackType": field(block,"attacktype"), "tiers": stats, "scaling": scales,
                    "imageUrl": "https://brotato.wiki.spellsandguns.com"+img,
                    "sourceUrl": "https://brotato.wiki.spellsandguns.com/"+name.replace(" ","_"),
                    "specialSource": field(block,"special")})

(OUT / "catalog.json").write_text(json.dumps({"source": "https://brotato.wiki.spellsandguns.com/Weapons",
    "sourcePatch": "1.1.6.3", "retrieved": "2026-11-06", "weapons": records}, indent=2, ensure_ascii=False)+"\n", encoding="utf-8")
print(f"Imported {len(records)} base-game weapons; no DLC. " + ", ".join(r["name"] for r in records))

# Runtime geometry uses the project's existing 10 wiki units = 1 stud conversion.
# Damage and cooldowns remain source values. Only Max HP inputs/bonuses use hpScale.
FEATURES = {
    "Cacti Club": dict(secondaryCount=[3,4,5,6], secondaryBase=[1,2,3,4], secondaryScaling=[.6,.7,.8,1]),
    "Chopper": dict(held=[dict(fruitHeal=x*10) for x in [1,1,1,2]]),
    "Drill": dict(critMaterialChance=1, timedAttackSpeed=10, timedSeconds=5),
    "Excalibur": dict(armorPerWeapon=-2, meleeMode=2),
    "Quarterstaff": dict(meleeMode=2, held=[dict(xpGain=x) for x in [2,5,9,15]]),
    "Flaming Brass Knuckles": dict(burnDamage=[0,10,15,18], burnTicks=[0,5,6,7]),
    "Ghost Axe": dict(killGainStat="damage", killsPerGain=[20,18,16,12]),
    "Ghost Flint": dict(killGainStat="attackSpeed", killsPerGain=[20,18,16,12]),
    "Hammer": dict(held=[dict(knockback=x) for x in [0,2,4,6]], knockbackPiercing=[0,.1,.15,.2]),
    "Hand": dict(held=[dict(harvesting=x) for x in [3,6,12,25]]),
    "Jousting Lance": dict(held=[dict(speed=x) for x in [2,3,4,5]], stationaryDamage=[-10,-15,-20,-25]),
    "Lightning Shiv": dict(secondaryCount=1, secondaryBase=[5,6,8,11], secondaryScaling=.8, secondaryElemental=1, secondaryBounce=[0,1,2,3]),
    "Plank": dict(explosionChance=[.25,.3,.4,.5], explosionRadius=4.5),
    "Plasma Sledge": dict(explosionChance=[0,0,.25,.5], explosionRadius=[6,6,6,7.5]),
    "Power Fist": dict(explosionChance=[0,0,.25,.5], explosionRadius=[4.5,4.5,4.5,6]),
    "Pruner": dict(structureKinds=["MoonGarden"]*4, gardenIntervals=[15,14,12,10]),
    "Rock": dict(held=[{},dict(armor=1),dict(armor=1,maxHp=20),dict(armor=2,maxHp=20)]),
    "Screwdriver": dict(structureKinds=["RuneMine"]*4, structureIntervals=[12,9,6,3]),
    "Scythe": dict(selfDamage=30, selfDamageSeconds=1, damageOnHurt=3),
    "Stick": dict(damagePerCopy=[4,6,8,10]),
    "Sword": dict(meleeMode=2),
    "Thief Dagger": dict(critMaterialChance=[.5,.56,.62,.8]),
    "Thunder Sword": dict(secondaryCount=[0,0,2,4], secondaryBase=0, secondaryScaling=1, secondaryElemental=1, secondarySlow=.8, secondaryBounce=0),
    "Torch": dict(burnDamage=[3,5,8,12], burnTicks=[3,5,6,9], burnSpread=[0,0,1,1]),
    "Wrench": dict(structureKinds=["BrassSentry","CinderSentry","PrismSentry","SiegeSentry"]),
    "Chain Gun": dict(magazine=100, reloadSeconds=2.04, pierce=1),
    "Crossbow": dict(critPierce=[1,2,3,4], pierceFalloff=0),
    "Double Barrel Shotgun": dict(count=[4,4,4,6], fan=1, spreadDegrees=10, pierce=[2,2,2,3], pierceFalloff=.3),
    "Flamethrower": dict(burnDamage=[0,1,3,5], burnTicks=[0,3,5,8], pierce=99, projectileSpeed=35),
    "Gatling Laser": dict(pierce=3, pierceFalloff=.25),
    "Ghost Scepter": dict(killGainStat="maxHp", killsPerGain=[20,18,16,12]),
    "Laser Gun": dict(pierce=1, pierceFalloff=.25),
    "Minigun": dict(pierce=[0,0,1,2], pierceFalloff=.25),
    "Nuclear Launcher": dict(explosionRadius=[12,12,12,13.5]),
    "Obliterator": dict(pierce=-1, pierceFalloff=0),
    "Pistol": dict(pierce=1),
    "Railgun": dict(timedBaseDamage=[3,4,5,6], timedSeconds=5, pierce=[1,1,2,3], pierceFalloff=[.5,.35,.35,.25]),
    "Revolver": dict(magazine=6, reloadSeconds=[2.07,1.93,1.8,1.67]),
    "Rocket Launcher": dict(explosionRadius=7.2),
    "Shredder": dict(explosionChance=[.5,.65,.8,1], explosionRadius=[4.5,4.8,5.1,5.4], pierce=3, pierceFalloff=0),
    "Shuriken": dict(critBounce=[1,2,3,4], bounceFalloff=0),
    "Slingshot": dict(bounce=[1,2,3,4], bounceFalloff=0),
    "Sniper Gun": dict(secondaryCount=[0,0,5,8], secondaryBase=5, secondaryScaling=[0,0,.1,.15], secondaryRange=1),
    "Taser": dict(count=[1,2,3,4], fan=1, slow=.8, slowSeconds=1, slowRadius=4),
    "Wand": dict(burnDamage=[3,5,8,12], burnTicks=[3,5,6,9], pierce=1),
    "DEX-troyer": dict(explosionChance=.5, explosionRadius=7.5, secondaryCount=1, secondaryBase=30, secondaryScaling=1, secondaryElemental=1, secondaryBounce=5),
    "Fireball": dict(explosionRadius=6, burnDamage=[0,5,6,8], burnTicks=[0,3,4,5]),
    "Icicle": dict(pierce=1),
    "Particle Accelerator": dict(pierce=-1, pierceFalloff=0, noBounce=1, burnDamage=[0,0,8,10], burnTicks=[0,0,8,10], engineeringSlow=[0,0,.01,.02], slowSeconds=1),
    "Sharp Tooth": dict(missingHpLifeSteal=[.25,.2,.15,.1]),
    "Vorpal Sword": dict(meleeMode=2, executeChance=[0,.01,.02,.03]),
}

def at(value, t): return value[t] if isinstance(value, list) else value

compiled = {}
for r in records:
    name, ident = r["name"], r["id"]
    feat = FEATURES.get(name, {})
    effective = []
    for t in range(4):
        source = r["tiers"][t] or r["tiers"][r["minTier"]-1]
        s = {k:v for k,v in source.items() if k != "price"}
        s["range"] *= .1
        if r["kind"] == "Melee":
            s.update(width=1.2, sweepDegrees=120, attackSeconds=.18,
                     meleeMode=1 if r["attackType"] == "Sweep" or name == "Scythe" else 0)
        else:
            s.update(count=1, pierce=0, bounce=0, projectileSpeed=60, projectileRadius=.5, spreadDegrees=8)
        for k,v in feat.items():
            if k not in ["held","structureKinds","structureIntervals","gardenIntervals","killGainStat","armorPerWeapon"]:
                s[k] = at(v,max(t,r["minTier"]-1))
		
        s["levelScaling"] = r["scaling"][max(t,r["minTier"]-1)].get("level",0)
        if "secondaryCount" in s:
            s.update(secondaryRangeStuds=40, secondarySpeed=60, secondaryRadius=.5, secondarySlowSeconds=1)
        effective.append(s)
    base = effective[0]
    deltas = [{}]
    for t in range(1,4):
        delta = {}
        for k,v in effective[t].items():
            if k == "damage": v = (v - effective[t-1][k]) / base["damage"]
            else: v -= effective[t-1].get(k,0)
            if abs(v) > 1e-9: delta[k] = v
        deltas.append(delta)
    scaling = []
    original = []
    for t in range(4):
        sc = r["scaling"][t] or r["scaling"][r["minTier"]-1]
        original.append(sc)
        scaling.append({k: v/10 if k == "maxHp" else v for k,v in sc.items() if k != "level"})
    # Keep prose short; the complete per-tier mechanics remain data in this record.
    descriptions = {
        "Cacti Club":"Hits release ranged spines.", "Lightning Shiv":"Hits release bouncing elemental lightning.",
        "Drill":"Critical kills grant a material. Gains attack speed every 5 seconds this wave.",
        "Excalibur":"Alternates thrusts and sweeps. -2 Armor for each held weapon.",
        "Quarterstaff":"Alternates thrusts and sweeps. Grants XP Gain.",
        "Jousting Lance":"Grants Speed. Deals less damage while standing still.",
        "Pruner":"Plants a garden that produces fruit.", "Scythe":"Drains 3 HP per second; gains 3% Damage when hurt this wave.",
        "Stick":"Each additional Stick adds base damage.", "Thief Dagger":"Critical kills can grant a material.",
        "Thunder Sword":"Hits release slowing elemental projectiles.", "Wrench":"Deploys a turret that improves with weapon tier.",
        "Screwdriver":"Places engineering landmines at tier-dependent intervals.", "Crossbow":"Critical projectiles pierce enemies.",
        "Shuriken":"Critical projectiles bounce between enemies.", "Sniper Gun":"Hits release projectiles scaling with Range.",
        "Railgun":"Gains base damage every 5 seconds this wave; resets when hurt.",
        "Particle Accelerator":"Pierces enemies, burns, and slows with Engineering. Cannot bounce.",
        "Sharp Tooth":"Gains Life Steal as health is lost.", "Vorpal Sword":"Alternates thrusts and sweeps; can execute ordinary enemies.",
    }
    description = descriptions.get(name, "")
    if not description:
        if "burnDamage" in feat: description = "Hits apply elemental burning."
        elif "killsPerGain" in feat: description = "Weapon kills grant permanent " + feat["killGainStat"] + " each wave."
        elif "magazine" in feat: description = "Fires a magazine, then reloads."
        elif "explosionRadius" in feat: description = "Hits create explosions."
        elif "bounce" in feat: description = "Projectiles bounce between enemies."
        elif "pierce" in feat: description = "Projectiles pierce enemies."
        else: description = "Sweeps nearby enemies." if base.get("meleeMode") == 1 else "Thrusts at nearby enemies." if r["kind"] == "Melee" else "Fires at nearby enemies."
    w = dict(id=ident, displayName=name, description=description, kind=r["kind"],
             classes=[CLASSES[c] for c in r["classes"]], minTier=r["minTier"],
             brotato=True, originalScaling=original, scaling=scaling[0], tierScaling=scaling,
             rangeKeys=["range"], behavior=ident, targeting="Nearest", base=base, tiers=deltas)
    if "held" in feat: w["heldStats"] = feat["held"]
    for k in ["structureKinds","structureIntervals","gardenIntervals","killGainStat","armorPerWeapon"]:
        if k in feat: w[k] = feat[k]
    compiled[ident] = w

old = (ROOT/"src/shared/Config/Weapons.luau").read_text(encoding="utf-8")
types = old[old.index("export type TierDelta"):old.index("local Weapons:")]
for extra in ["brotato: boolean?", "originalScaling: { { [string]: number } }?", "gardenIntervals: { number }?", "armorPerWeapon: number?"]:
    types = types.replace("\t"+extra+",\n", "")
types = types.replace("\tid: string,", "\tid: string,\n\tbrotato: boolean?,\n\toriginalScaling: { { [string]: number } }?,\n\tgardenIntervals: { number }?,\n\tarmorPerWeapon: number?,")
(ROOT/"src/shared/Config/Weapons.luau").write_text(
    '--!strict\n-- Original base-game Brotato weapon records read by WeaponService, shop and WeaponRenderer.\n'
    '-- Generated from the factual catalog in assets/weapons/brotato-base; no DLC or custom weapons.\n'
    '-- Range uses 0.1 studs per wiki unit; HP scaling inputs/bonuses account for this project\'s HP x10.\n\n'
    +types+'local Weapons: { [string]: Weapon } = '+lua(compiled)+'\n\nreturn table.freeze(Weapons)\n', encoding="utf-8")

shop_path = ROOT/"src/shared/Config/Shop.luau"
shop = shop_path.read_text(encoding="utf-8")
prices = {r["id"]:r["tiers"][r["minTier"]-1]["price"] for r in records}
tier_prices = {r["id"]:[(t or r["tiers"][r["minTier"]-1])["price"] for t in r["tiers"]] for r in records}
shop = re.sub(r"weaponPrices = table.freeze\(\{.*?\}\),", "weaponPrices = table.freeze("+lua(prices,1)+"),", shop, count=1, flags=re.S)
shop = re.sub(r"weaponTierPrices = \{.*?\n\t\},", "weaponTierPrices = "+lua(tier_prices,1)+",", shop, count=1, flags=re.S)
shop_path.write_text(shop,encoding="utf-8")

# Each weapon retains its own module and visual registration, as required by the framework.
for r in records:
    ident = r["id"]
    family = "Melee" if r["kind"] == "Melee" else "Projectile"
    path = ROOT/f"src/server/Services/WeaponService/Behaviors/{ident}.luau"
    path.write_text(f'--!strict\n-- {r["name"]} behavior for Arsenal; exact tier data in Config.Weapons.\nreturn require(script.Parent.Parent.Brotato{family})\n',encoding="utf-8")
    path = ROOT/f"src/client/Controllers/WeaponRenderer/Visuals/{ident}.luau"
    path.write_text(f'--!strict\n-- {r["name"]} attack visual for WeaponRenderer; held art comes from UI.WeaponImages.\nreturn require(script.Parent.Parent.B7{family}Visual)(Color3.fromRGB(225, 190, 110))\n',encoding="utf-8")
