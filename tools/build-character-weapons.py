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
FAMILIES = ['anchor', 'mace', 'meat_tenderizer', 'machinegun', 'pan_flute', 'combat_shotgun', 'grenade_launcher', 'whip']
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
            stats_path = data['stats']['resource']
            stats = pck.resource(stats_path)['properties']
            effects = []
            for ref in data['effects']:
                ep = ref['resource']
                effect = pck.resource(ep)['properties']
                effects.append({'source': ep, 'sourceMd5': pck.entries[ep]['md5'], 'key': effect['key'], 'value': effect['value'], 'scale': effect.get('scale'), 'duration': effect.get('duration')})
            tiers.append({'source': path, 'sourceMd5': pck.entries[path]['md5'], 'statsSource': stats_path, 'statsMd5': pck.entries[stats_path]['md5'], 'tier': data['tier'] + 1, 'price': data['value'], 'sets': [pck.resource(ref['resource'])['properties']['my_id'] for ref in data['sets']], 'kind': 'Melee' if data['type'] == 0 else 'Ranged', 'stats': {k: v for (k, v) in stats.items() if isinstance(v, (int, float, bool)) or k == 'scaling_stats'}, 'effects': effects})
        rows.append({'id': catalog.pascal(family), 'name': 'Machine Gun' if family == 'machinegun' else family.replace('_', ' ').title(), 'tiers': sorted(tiers, key=lambda row: row['tier'])})
    whip = next(row for row in rows if row['id'] == 'Whip')
    scene = 'res://weapons/melee/whip/whip.tscn'
    whip['geometry'] = {'source': scene, 'sourceMd5': pck.entries[scene]['md5'], 'hitOpenSeconds': 0.24, 'hitCloseSeconds': 0.32, 'attackLockSeconds': 0.48, 'hitStartOffset': 3.4, 'halfWidth': 1.6, 'spritePositionPoints': [13.885, 46, 46, 3.985], 'spriteRotationDegrees': [-16.4, 0, 0, 15], 'hitboxOffsetPoints': -12, 'note': 'Lash animation method keys open/close at 0.24/0.32, length 0.48; Sprite x46 plus Hitbox x-12, Rectangle extents.y16, world scale0.1. Whip.init_stats replaces Hitbox y scale with1.'}
    FACTS.write_text(json.dumps({'version': '1.2.0.1', 'steamBuild': 26406319, 'weapons': rows}, indent=2) + '\n', encoding='utf-8')

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
        for tier in resolved:
            st = tier['stats']
            scaling.append({catalog.STATS[key]: value for (key, value) in st['scaling_stats']})
            value = {'damage': st['damage'], 'cooldown': st['cooldown'] / 60, 'nativeCooldownFrames': st['cooldown'], 'nativeTiming': 1, 'range': st['max_range'] * 0.1, 'critChance': st['crit_chance'], 'critDamage': st['crit_damage'], 'knockback': st['knockback'], 'knockbackPiercing': st['knockback_piercing'], 'lifeSteal': st['lifesteal']}
            if tier['kind'] == 'Melee':
                value.update(width=1.2, sweepDegrees=120, attackSeconds=st.get('attack_duration', 0.18), meleeMode=st['attack_type'])
            else:
                value.update(count=st['nb_projectiles'], nativeSpread=st['projectile_spread'], nativeAccuracy=st['accuracy'], projectileSpeed=st['projectile_speed'] * 0.1, projectileRadius=0.6, pierce=st['piercing'], pierceFalloff=st['piercing_dmg_reduction'], bounce=st['bounce'], bounceFalloff=st['bounce_dmg_reduction'], shootWithoutTarget=int(st['can_shoot_without_target']))
                if st['additional_cooldown_every_x_shots'] > 0:
                    frames = math.floor(st['cooldown'] * st['additional_cooldown_multiplier'] + 0.5)
                    value.update(magazine=st['additional_cooldown_every_x_shots'], reloadSeconds=frames / 60, nativeReloadFrames=frames)
            bonuses = {}
            for effect in tier['effects']:
                if effect['key'] in catalog.STATS:
                    bonuses[catalog.STATS[effect['key']]] = effect['value']
                elif effect['key'] == 'effect_explode':
                    value.update(explosionChance=1, explosionRadius=147.34 * 0.1 * effect['scale'])
                elif effect['key'] == 'timed_slow_on_hit':
                    value.update(slow=effect['value'] / 100, slowSeconds=effect['duration'])
                else:
                    raise ValueError(f'Unhandled effect {ident}: {effect}')
            if ident == 'Whip':
                geometry = row['geometry']
                value.update(hitOpenSeconds=geometry['hitOpenSeconds'], hitCloseSeconds=geometry['hitCloseSeconds'], attackLockSeconds=geometry['attackLockSeconds'], hitStartOffset=geometry['hitStartOffset'], width=geometry['halfWidth'])
                for prefix, values in [('whipPosition', geometry['spritePositionPoints']), ('whipRotation', geometry['spriteRotationDegrees'])]:
                    for suffix, number in zip(['Before', 'Open', 'Close', 'After'], values):
                        value[prefix + suffix] = number * 0.1 if prefix == 'whipPosition' else number
                value['whipHitboxOffset'] = geometry['hitboxOffsetPoints'] * 0.1

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
        weapons[ident] = {'id': ident, 'displayName': row['name'], 'description': '', 'brotato': True, 'available': False, 'kind': first['kind'], 'classes': [catalog.SETS[key] for key in first['sets']], 'minTier': first['tier'], 'originalScaling': scaling, 'scaling': scaling[0], 'tierScaling': scaling, 'heldStats': held, 'rangeKeys': ['range'], 'behavior': ident, 'targeting': 'Nearest', 'base': base, 'tiers': deltas}
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
