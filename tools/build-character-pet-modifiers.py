"""Compile three original supporting items needed by native pet scaling and structure criticals."""
from __future__ import annotations
import argparse, importlib.util, json, subprocess, sys, tempfile
from pathlib import Path
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result
def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    source = module('modifier_source', ROOT/'tools/character-source.py')
    compiler = module('modifier_catalog', ROOT/'tools/build-character-catalog.py')
    pck = source.Pck(source.DEFAULT_PCK)
    stat_ids = {**compiler.STATS, 'burning_cooldown_reduction':'burnSpeed', 'structures_can_crit':'structuresCanCrit'}
    fields = {'elementalDamage':'weaponScalingElemental', 'engineering':'weaponScalingEngineering'}
    items = {}
    for ident, slug, name in [('Nail','nail','Nail'), ('FrozenHeart','frozen_heart','Frozen Heart'), ('PileOfBooks','pile_of_books','Pile of Books')]:
        path = f'res://items/all/00_base_game/{slug}/{slug}_data.tres'
        props = pck.resource(path)['properties']
        stats, modifiers, effects = {}, {}, []
        for ref in props['effects']:
            effect = pck.resource(ref['resource'])['properties']
            effects.append({'source':ref['resource'], 'sourceMd5':pck.entries[ref['resource']]['md5'], 'key':effect['key'], 'customKey':effect['custom_key'], 'amount':effect['value']})
            stat = stat_ids[effect['key']]
            if effect['custom_key'] == 'weapon_scaling_stats':
                modifiers[fields[stat]] = effect['value']
            elif stat == 'structuresCanCrit':
                modifiers[stat] = effect['value']
            else:
                stats[stat] = effect['value']
        description = 'Your structures can crit' if ident == 'PileOfBooks' else f'Weapon and pet damage additionally scales with {next(iter(modifiers.values()))}% '+('Engineering' if ident == 'Nail' else 'Elemental Damage')
        items[ident] = {'id':ident, 'displayName':name, 'nameKey':props['name'], 'description':description, 'tier':props['tier']+1, 'price':props['value'], 'limit':props['max_nb'], 'stats':stats, 'modifiers':modifiers, 'free':props['unlocked_by_default'], 'source':path, 'sourceMd5':pck.entries[path]['md5'], 'nativeId':props['my_id'], 'iconSource':props['icon']['resource'], 'tags':[stat_ids[tag] for tag in props['tags']], 'sourceTags':props['tags'], 'effects':effects}
    facts = {'version':'1.2.0.1','steamBuild':26406319,'scalingFields':fields,'structureCritField':'structuresCanCrit','scalingText':'Weapon and pet damage additionally scales with {amount}% {stat}','structureCritText':items['PileOfBooks']['description'],'items':items}
    outputs = {ROOT/'docs/characters/pet-modifiers.json':json.dumps(facts,indent=2)+'\n', ROOT/'src/shared/Config/WeaponModifiers.luau':'--!strict\n-- Original supporting item facts and hidden modifier fields; Items, NativeWeaponDamage and PetRules consume these values.\nreturn '+compiler.luau(facts)+'\n'}
    groups_path = ROOT/'docs/characters/item-groups.json'
    groups = json.loads(groups_path.read_text(encoding='utf-8'))
    for ident, row in items.items():
        groups['runtimeItems'][ident] = {key:row[key] for key in ['nativeId','nameKey','source','sourceMd5','displayName']}
        groups['runtimeItems'][ident]['tags'] = row['sourceTags']
    outputs[groups_path] = json.dumps(groups,indent=2,ensure_ascii=False)+'\n'
    for path, text in outputs.items():
        if path.suffix == '.luau':
            with tempfile.TemporaryDirectory(dir=ROOT/'build') as temp:
                candidate = Path(temp)/path.name
                candidate.write_text(text,encoding='utf-8')
                subprocess.run(['stylua',str(candidate)],check=True)
                text = candidate.read_text(encoding='utf-8')
        if args.check:
            assert path.read_text(encoding='utf-8') == text, f'Stale modifier facts: {path}'
        else:
            path.write_text(text,encoding='utf-8',newline='\n')
    print('Three original pet-supporting items and their modifier sources checked')
if __name__ == '__main__':
    main()
