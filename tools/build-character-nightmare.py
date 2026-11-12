"""Read stable Nightmare 1 difficulty effects and source-hashed event-planning constants without exposing a playable difficulty."""
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
    source = module('nightmare_source', ROOT/'tools/character-source.py')
    compiler = module('nightmare_catalog', ROOT/'tools/build-character-catalog.py')
    pck = source.Pck(source.DEFAULT_PCK)
    path = 'res://items/difficulties/6-Nightmare/difficulty_6.tres'
    difficulty = pck.resource(path)['properties']
    effects = []
    for ref in difficulty['effects']:
        data = pck.resource(ref['resource'])['properties']
        effects.append({'source':ref['resource'],'sourceMd5':pck.entries[ref['resource']]['md5'],'key':data['key'],'value':data['value'],'storageMethod':data['storage_method'],'textKey':data['text_key']})
    facts = {'version':'1.2.0.1','steamBuild':26406319,'source':path,'sourceMd5':pck.entries[path]['md5'],'level':difficulty['value'],'nameKey':difficulty['name'],'effects':effects,
        'ruleSources':[{'source':path,'sourceMd5':pck.entries[path]['md5']} for path in ['res://singletons/run_data.gdc','res://singletons/progress_data.gdc']],
        'unlock':{'danger':5,'characterZoneWins':10},'events':{'firstBlock':10,'lastOffset':9,'fogPerBlock':2,'bulletsPerBlock':3,'defaultConstantProjectiles':True,'earlyFog':[5,6,7],'earlyBullets':[[1,2],[3,4],[5,6,7],[8,9,10]]}}
    outputs = {ROOT/'docs/characters/nightmare-source.json':json.dumps(facts,indent=2)+'\n',ROOT/'src/shared/Config/Nightmare.luau':'--!strict\n-- Stable Nightmare 1 source facts for NightmareRules; difficulty selection stays gated until its full runtime exists.\nreturn '+compiler.luau(facts)+'\n'}
    for path, text in outputs.items():
        if path.suffix == '.luau':
            with tempfile.TemporaryDirectory(dir=ROOT/'build') as temp:
                candidate = Path(temp)/path.name
                candidate.write_text(text,encoding='utf-8')
                subprocess.run(['stylua',str(candidate)],check=True)
                text = candidate.read_text(encoding='utf-8')
        if args.check:
            assert path.read_text(encoding='utf-8') == text, f'Stale Nightmare facts: {path}'
        else:
            path.write_text(text,encoding='utf-8',newline='\n')
    print('Nightmare 1: ten original difficulty effects and event-planning facts checked; no difficulty availability changed')
if __name__ == '__main__': main()
