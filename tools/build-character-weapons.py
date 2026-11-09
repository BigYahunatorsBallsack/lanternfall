"""Compile the first supported stable character starting-weapon families.

--refresh reads only neutral facts from the installed PCK; ordinary generation and
--check use the committed snapshot. Original scripts/art never enter this file.
"""
from __future__ import annotations
import argparse, importlib.util, json, math, subprocess, sys
from pathlib import Path
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]

def module(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT / file)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result
source = module('character_source', 'tools/character-source.py')
catalog = module('character_catalog', 'tools/build-character-catalog.py')
FAMILIES = ['anchor', 'mace', 'meat_tenderizer', 'machinegun', 'pan_flute', 'combat_shotgun', 'grenade_launcher', 'whip', 'spoon', 'cestus', 'sickle', 'trident', 'lute', 'blowgun', 'blunderbuss', 'javelin', 'tranq_rifle', 'harpoon_gun', 'sticky_grenade', 'flail']
FACTS = ROOT / 'docs/characters/weapon-source.json'
OUTPUT = ROOT / 'src/shared/Config/CharacterWeaponData.luau'

def refresh():
    pck = source.Pck()
    rows = []
    for family in FAMILIES:
        tiers = []
        for path in pck.entries:
            if f'/{family}/' not in path or not path.endswith('_data.tres'):
                continue
            data = pck.resource(path)['properties']
            if 'weapon_id' not in data:
                continue
            stats_path = data['stats']['resource']
            stats = pck.resource(stats_path)['properties']
            effects = []
            for ref in data['effects']:
                ep = ref['resource']
                effect = pck.resource(ep)['properties']
                effects.append({'source': ep, 'sourceMd5': pck.entries[ep]['md5'], 'key': effect['key'], 'value': effect['value'], 'scale': effect.get('scale'), 'duration': effect.get('duration')})
                for key in ['value2', 'stat_name', 'damage_multiplier', 'source_id', 'duration_secs', 'max_stacks', 'custom_key', 'chance', 'radius', 'fuse_duration']:
                    if key in effect:
                        effects[-1][key] = effect[key]
                if 'sub_effects' in effect:
                    effects[-1]['subEffects'] = [{'source': ref['resource'], 'sourceMd5': pck.entries[ref['resource']]['md5'], **{k:v for k,v in pck.resource(ref['resource'])['properties'].items() if k in ['key','value']}} for ref in effect['sub_effects']]
            tiers.append({'source': path, 'sourceMd5': pck.entries[path]['md5'], 'statsSource': stats_path, 'statsMd5': pck.entries[stats_path]['md5'], 'tier': data['tier'] + 1, 'price': data['value'], 'sets': [pck.resource(ref['resource'])['properties']['my_id'] for ref in data['sets']], 'kind': 'Melee' if data['type'] == 0 else 'Ranged', 'stats': {k: v for (k, v) in stats.items() if isinstance(v, (int, float, bool)) or k == 'scaling_stats'}, 'effects': effects})
        rows.append({'id': catalog.pascal(family), 'name': 'Machine Gun' if family == 'machinegun' else family.replace('_', ' ').title(), 'tiers': sorted(tiers, key=lambda row: row['tier'])})
    whip = next(row for row in rows if row['id'] == 'Whip')
    scene = 'res://weapons/melee/whip/whip.tscn'
    whip['geometry'] = {'source': scene, 'sourceMd5': pck.entries[scene]['md5'], 'hitOpenSeconds': 0.24, 'hitCloseSeconds': 0.32, 'attackLockSeconds': 0.48, 'hitStartOffset': 3.4, 'halfWidth': 1.6, 'spritePositionPoints': [13.885, 46, 46, 3.985], 'spriteRotationDegrees': [-16.4, 0, 0, 15], 'hitboxOffsetPoints': -12, 'note': 'Lash animation method keys open/close at 0.24/0.32, length 0.48; Sprite x46 plus Hitbox x-12, Rectangle extents.y16, world scale0.1. Whip.init_stats replaces Hitbox y scale with1.'}
    flail = next(row for row in rows if row['id'] == 'Flail')
    scene = 'res://weapons/melee/flail/flail.tscn'
    flail['geometry'] = {**whip['geometry'], 'source': scene, 'sourceMd5': pck.entries[scene]['md5'], 'hitLengthPoints': 273.128, 'note': 'Same lash animation keys as Whip. Collision center136.564/extents.x136.564; init_stats sets x scale to range/273.128 and y scale1. Tip crit uses native closest aim-shape position within40 points.'}
    harpoon = next(row for row in rows if row['id'] == 'HarpoonGun')
    harpoon_scene = 'res://projectiles/bullet_harpoon/bullet_harpoon.tscn'
    harpoon['geometry'] = {'source': harpoon_scene, 'sourceMd5': pck.entries[harpoon_scene]['md5'], 'slowRadiusPoints': 63.0714, 'slowOffsetPoints': [1,4], 'slowAmountPoints': -400, 'note': 'SlowHitbox x-24/y4 plus Circle collision x25, fixed native additive -400 speed, each target once per projectile.'}
    sticky = next(row for row in rows if row['id'] == 'StickyGrenade')
    sticky_source = 'res://projectiles/grenade_mine/grenade_mine_projectile.gdc'
    sticky['geometry'] = {'source': sticky_source, 'sourceMd5': pck.entries[sticky_source]['md5'], 'stickDistancePoints': 40, 'note': 'Native hitbox is disabled; attach to the nearest enemy/neutral center within40, follow its offset, retain last position on death; range end starts fuse.'}
    FACTS.write_text(json.dumps({'version': '1.2.0.1', 'steamBuild': 26406319, 'explosionGeometry': {'source':'res://projectiles/explosion.tscn','sourceMd5':pck.entries['res://projectiles/explosion.tscn']['md5'],'radiusPoints':147.34,'offsetZPoints':3}, 'weapons': rows}, indent=2) + '\n', encoding='utf-8')

def generate():
    facts = json.loads(FACTS.read_text(encoding='utf-8'))
    weapons = {}
    prices = {}
    for row in facts['weapons']:
        tiers = row['tiers']
        first = tiers[0]
        ident = row['id']
        available = {t['tier']: t for t in tiers}
        resolved = [available[max(first['tier'], n)] for n in range(1, 5)]
        compiled = []
        held = []
        scaling = []
        descriptions = []
        for tier in resolved:
            st = tier['stats']
            scaling.append({catalog.STATS[key]: value for (key, value) in st['scaling_stats']})
            value = {'damage': st['damage'], 'cooldown': st['cooldown'] / 60, 'nativeCooldownFrames': st['cooldown'], 'nativeTiming': 1, 'range': st['max_range'] * 0.1, 'critChance': st['crit_chance'], 'critDamage': st['crit_damage'], 'knockback': st['knockback'], 'knockbackPiercing': st['knockback_piercing'], 'lifeSteal': st['lifesteal']}
            if tier['kind'] == 'Melee':
                value.update(width=1.2, sweepDegrees=120, attackSeconds=st.get('attack_duration', 0.18), meleeMode=st['attack_type'])
            else:
                if not st.get('can_bounce', True):
                    value['noBounce'] = 1
                if st['min_range'] > 0:
                    value['minimumRange'] = st['min_range'] * 0.1
                if st['can_have_negative_knockback'] and not st['can_have_positive_knockback']:
                    value['negativeKnockbackOnly'] = 1
                value.update(count=st['nb_projectiles'], nativeSpread=st['projectile_spread'], nativeAccuracy=st['accuracy'], projectileSpeed=st['projectile_speed'] * 0.1, projectileRadius=0.6, pierce=st['piercing'], pierceFalloff=st['piercing_dmg_reduction'], bounce=st['bounce'], bounceFalloff=st['bounce_dmg_reduction'], shootWithoutTarget=int(st['can_shoot_without_target']))
                if st['additional_cooldown_every_x_shots'] > 0:
                    frames = math.floor(st['cooldown'] * st['additional_cooldown_multiplier'] + 0.5)
                    value.update(magazine=st['additional_cooldown_every_x_shots'], reloadSeconds=frames / 60, nativeReloadFrames=frames)
            bonuses = {}
            lines = []
            for effect in tier['effects']:
                if effect.get('custom_key') == 'enemy_percent_damage_taken':
                    assert effect.get('chance', 100) == 100
                    value.update(vulnerabilityPercent=effect['value'], vulnerabilitySeconds=effect['duration_secs'], vulnerabilityStacks=effect['max_stacks'])
                    lines.append(f"Enemies hit take {effect['value']}% more damage for {effect['duration_secs']} seconds (max: {effect['value'] * effect['max_stacks']}%)")
                elif effect['key'] in catalog.STATS:
                    bonuses[catalog.STATS[effect['key']]] = effect['value']
                elif effect['key'] == 'reload_when_pickup_gold':
                    value.update(reloadOnMaterial=1,shotAnimationSeconds=st['recoil_duration']*2)
                    lines.append('Cooldown is reset when you pick up a material')
                elif effect['key'] == 'modify_every_x_projectile':
                    sub=effect['subEffects']
                    assert len(sub)==1 and sub[0]['key']=='stat_crit_chance'
                    value.update(cycleEvery=effect['value'],cycleCritBonus=sub[0]['value'])
                    lines.append(f"Every {effect['value']}th attack gains +{sub[0]['value']}% Crit Chance")
                elif effect['key'] == 'slow_area_on_hit':
                    value.update(impactSlowRadius=effect['radius']*0.1,impactSlowPercent=effect['value'],impactSlowHold=effect['duration'])
                    lines.append(f"Hits slow enemies within {effect['radius']:g} range by {effect['value']}% for {effect['duration']:g} seconds")
                elif effect['key'] == 'effect_slow_in_zone':
                    geometry=row['geometry']
                    value.update(slowZoneRadius=geometry['slowRadiusPoints']*0.1,slowZoneOffsetX=geometry['slowOffsetPoints'][0]*0.1,slowZoneOffsetZ=geometry['slowOffsetPoints'][1]*0.1,slowZonePoints=geometry['slowAmountPoints'])
                    lines.append('Slows nearby enemies')
                elif effect['key'] == 'effect_explode':
                    geometry = facts['explosionGeometry']
                    value.update(explosionChance=1, explosionRadius=geometry['radiusPoints'] * 0.1 * effect['scale'], explosionOffsetZ=geometry['offsetZPoints']*0.1*effect['scale'])
                    if 'fuse_duration' in effect:
                        value.update(stickyFuse=effect['fuse_duration'], stickyDistance=row['geometry']['stickDistancePoints']*0.1)
                        lines.append(f"Sticks to the targeted enemy and explodes after {effect['fuse_duration']} seconds")
                elif effect['key'] == 'crit_on_hitting_burning_target':
                    value['critBurning'] = 1
                    lines.append('Always crits when hitting burning targets')
                elif effect['key'] == 'crit_on_whip_tip':
                    value['tipCritRadius'] = effect['value'] * 0.1
                    lines.append('Enemies hit by the tip of the flail are always critically hit')
                elif effect.get('damage_multiplier') is not None:
                    assert effect['stat_name'] == 'knockback'
                    value.update(baseDamageKnockbackThreshold=effect['value'], baseDamageKnockbackMultiplier=effect['damage_multiplier'])
                    lines.append(f"If your Knockback is +{effect['value']} or higher, this weapon's base damage is doubled")
                elif effect['key'] in ['bonus_damage_against_targets_below_hp', 'bonus_damage_against_targets_above_hp']:
                    prefix = 'below' if 'below' in effect['key'] else 'above'
                    value[prefix + 'HealthDamagePercent'] = effect['value']
                    value[prefix + 'HealthThreshold'] = effect['value2'] / 100
                    lines.append(f"+{effect['value']}% damage against targets {prefix} {effect['value2']}% health")
                elif effect['key'] == 'timed_slow_on_hit':
                    value.update(slow=effect['value'] / 100, slowSeconds=effect['duration'])
                else:
                    raise ValueError(f'Unhandled effect {ident}: {effect}')
            if ident in ['Whip', 'Flail']:
                geometry = row['geometry']
                value.update(hitOpenSeconds=geometry['hitOpenSeconds'], hitCloseSeconds=geometry['hitCloseSeconds'], attackLockSeconds=geometry['attackLockSeconds'], hitStartOffset=geometry['hitStartOffset'], width=geometry['halfWidth'])
                for prefix, values in [('whipPosition', geometry['spritePositionPoints']), ('whipRotation', geometry['spriteRotationDegrees'])]:
                    for suffix, number in zip(['Before', 'Open', 'Close', 'After'], values):
                        value[prefix + suffix] = number * 0.1 if prefix == 'whipPosition' else number
                value['whipHitboxOffset'] = geometry['hitboxOffsetPoints'] * 0.1

            descriptions.append("\n".join(lines))
            compiled.append(value)
            held.append(bonuses)
        base = compiled[0]
        deltas = []
        previous = base
        for (index, stats) in enumerate(compiled):
            delta = {} if index == 0 else {key: stats[key] - previous[key] for key in stats if stats[key] != previous.get(key)}
            if index > 0 and 'damage' in delta:
                delta['damage'] = stats['damage'] / base['damage'] - previous['damage'] / base['damage']
            deltas.append(delta)
            previous = stats
        weapons[ident] = {'id': ident, 'displayName': row['name'], 'description': '', 'tierDescriptions': descriptions, 'brotato': True, 'available': False, 'kind': first['kind'], 'classes': [catalog.SETS[key] for key in first['sets']], 'minTier': first['tier'], 'originalScaling': scaling, 'scaling': scaling[0], 'tierScaling': scaling, 'heldStats': held, 'rangeKeys': ['range'], 'behavior': ident, 'targeting': 'Nearest', 'base': base, 'tiers': deltas}
        prices[ident] = [t['price'] for t in resolved]
    text = '--!strict\n-- Stable character starting-weapon facts; Weapons and Shop read this generated extension.\n-- Generated by tools/build-character-weapons.py from docs/characters/weapon-source.json.\nreturn ' + catalog.luau({'weapons': weapons, 'prices': prices}) + '\n'
    return text
if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--refresh', action='store_true')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.refresh:
        refresh()
    result = generate()
    if args.check:
        existing = OUTPUT.read_bytes()
        tmp = ROOT / 'build/character-weapons-check.luau'
        tmp.parent.mkdir(exist_ok=True)
        tmp.write_text(result, encoding='utf-8')
        subprocess.run(['stylua', str(tmp)], check=True)
        if existing.replace(b'\r\n', b'\n') != tmp.read_bytes().replace(b'\r\n', b'\n'):
            raise SystemExit('Character weapon data is stale')
    else:
        OUTPUT.write_text(result, encoding='utf-8')
        subprocess.run(['stylua', str(OUTPUT)], check=True)
    print(f'{len(FAMILIES)} stable weapon families compiled')
