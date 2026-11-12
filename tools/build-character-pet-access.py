"""Compile the stable Paws & Claws pet challenges and Beast Master prerequisite chain from the installed PCK."""
import argparse
import importlib.util
import json
import sys
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
    source = module('pet_access_source', ROOT/'tools/character-source.py')
    compiler = module('pet_access_catalog', ROOT/'tools/build-character-catalog.py')
    pck = source.Pck(source.DEFAULT_PCK)
    items = {}
    for slug, stat in [('bonk_dog','meleeDamage'),('catling_gun','rangedDamage'),('bot_o_mine','engineering'),('blazemander','elementalDamage'),('lootworm',None)]:
        path = f'res://challenges/chal_{slug}.tres'
        data = pck.resource(path)['properties']
        items[''.join(word.title() for word in slug.split('_'))] = {'free':False,'challengeId':data['my_id'],'source':path,'sourceMd5':pck.entries[path]['md5'],'kind':'Inventory' if stat else 'WaveMaterials','count':f'weaponsScaling:{stat}' if stat else 'materialsOnFloor','stat':stat,'threshold':data['value']}
    rat_path = 'res://items/all/03_paws_n_claws/ratzilla/ratzilla.tres'
    rat = pck.resource(rat_path)['properties']
    items['Ratzilla'] = {'free':rat['unlocked_by_default'],'source':rat_path,'sourceMd5':pck.entries[rat_path]['md5']}
    items = {key:{field:value for field,value in row.items() if value is not None} for key,row in items.items()}
    path = 'res://challenges/chal_paws_n_claws.tres'
    data = pck.resource(path)['properties']
    character = {'kind':'PetChallenges','challengeId':data['my_id'],'source':path,'sourceMd5':pck.entries[path]['md5'],'requirement':'Unlock the Catling Gun, Bonk Dog, Bot-O-Mine, Blazemander and Lootworm items'}
    facts = {'version':'1.2.0.1','items':items,'character':character,'sourceValueNotUsedAsPetCount':data['value'],'aggregateSource':'res://singletons/run_data.gdc','aggregateSourceMd5':pck.entries['res://singletons/run_data.gdc']['md5']}
    output = ('--!strict\n-- Native Paws & Claws unlock chain; CharacterAccess and PlayerDataService consume these source-hashed rules.\n'
        'export type Rule = { free: boolean, challengeId: string?, source: string?, sourceMd5: string?, kind: string?, count: string?, stat: string?, threshold: number? }\n'
        'local items: { [string]: Rule } = '+compiler.luau(items)+'\n'
        'local character: { kind: "PetChallenges", challengeId: string, source: string, sourceMd5: string, requirement: string } = '+compiler.luau(character)+'\n'
        'return { items = items, character = character }\n')
    for path, text in [(ROOT/'docs/characters/pet-access.json',json.dumps(facts,indent=2)+'\n'),(ROOT/'src/shared/Config/PetAccess.luau',output)]:
        if path.suffix == '.luau':
            import subprocess
            import tempfile
            with tempfile.TemporaryDirectory(dir=ROOT/'build') as temp:
                candidate = Path(temp)/path.name
                candidate.write_text(text,encoding='utf-8')
                subprocess.run(['stylua',str(candidate)],check=True)
                text = candidate.read_text(encoding='utf-8')
        if args.check:
            assert path.read_text(encoding='utf-8') == text, f'Stale pet access facts: {path}'
        else:
            path.write_text(text,encoding='utf-8',newline='\n')
    print('Five pet challenges and the original Beast Master prerequisite chain checked')
if __name__ == '__main__':
    main()
