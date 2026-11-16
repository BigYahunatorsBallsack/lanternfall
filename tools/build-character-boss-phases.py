"""Compile actual Jungle boss child-phase thresholds and audited custom timer exclusions."""
from __future__ import annotations
import argparse, importlib.util, json, re, subprocess, sys, tempfile
from pathlib import Path
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]

def module(name, path):
    spec=importlib.util.spec_from_file_location(name,ROOT/path)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result

def phase_nodes(raw, path, source):
    heads=list(re.finditer(r'^\[node .*\]\s*$',raw,re.M));assert heads,path
    prefix=raw[:heads[0].start()].replace('[gd_scene','[gd_resource type="PackedScene"',1)
    resources=source.parse_tres(prefix+'\n[resource]\n',path)['externalResources']
    external={str(v['id']):v['path'] for v in resources}
    phases=[]
    for i,head in enumerate(heads):
        attrs=dict(re.findall(r'(name|parent|index)="?([^"\s\]]+)"?',head.group()))
        if attrs.get('parent')!='States':continue
        instance=re.search(r'instance=ExtResource\(\s*(\d+)\s*\)',head.group())
        assert instance and external[instance[1]]=='res://entities/units/enemies/bosses/boss_state.tscn','Unexpected phase scene binding: '+path
        if 'index' in attrs:assert int(attrs['index'])==len(phases),'Re-audit phase child order: '+path
        body=raw[head.end():heads[i+1].start() if i+1<len(heads) else len(raw)]
        body=re.split(r'^\[(?:connection|editable) ',body,flags=re.M)[0]
        props=source.parse_tres(prefix+'\n[resource]\n'+body,path)['properties']
        assert {'hp_start','timer_start'}<=set(props),'Missing explicit phase threshold; resolve inheritance before adding defaults: '+path
        phases.append({'node':attrs['name'],'hpStart':props['hp_start'],'timerStart':props['timer_start']})
    assert phases,'No bound child phases: '+path
    return phases

def generate():
    source=module('boss_phase_source','tools/character-source.py');pck=source.Pck();reference=source.verify_reference(pck)
    hashes={
        'res://entities/units/enemies/bosses/boss.gdc':'a3cc583e1e8521d2899b6b7c56734685',
        'res://entities/units/enemies/bosses/boss_state.gdc':'7f6f65ae801262a06b954dbe7daaeddc',
        'res://entities/units/enemies/jungle/bosses/brachiosaurus/brachiosaurus.gdc':'c6e796b45d913450339d57f1997d3cdf',
        'res://entities/units/enemies/jungle/bosses/tyrannosaurus/tyranosaurus.gdc':'f44f413a22a26308968fd4575860cabf',
        'res://entities/units/enemies/jungle/elites/carnotaurus/carnotaurus.gdc':'372e3bb1b2aa3bd24d0bea3c65ee6fbc',
        'res://entities/units/enemies/jungle/elites/silesaurus/silesaurus.gdc':'3dc7ae8b914cefbc9cc1c0174cbda70c',
        'res://entities/units/enemies/jungle/elites/therizinosaurus/therizinosaurus.gdc':'53e588213796a45ee4727f7a9205ea07',
        'res://entities/units/enemies/jungle/elites/diplodocus/diplodocus.gdc':'af84fabc22f46610936179144ddf33bf',
    }
    for path,digest in hashes.items():assert pck.entries[path]['md5']==digest,'Re-audit changed boss phase script: '+path
    wave=json.loads((ROOT/'docs/characters/jungle-wave-bindings-source.json').read_text(encoding='utf-8'))
    assert wave['version']==reference['version'] and wave['steamBuild']==int(reference['steamBuildId'])
    names={'brachiosaurus':'Brachiosaurus','tyranosaurus':'Tyranosaurus','baryonyx_neutral':'Baryonyx','carnotaurus_neutral':'Carnotaurus','diplodocus':'Diplodocus','silesaurus':'Silesaurus','therizinosaurus':'Therizinosaurus'}
    actors={}
    for path,binding in wave['scenes'].items():
        slug=path.rsplit('/',1)[-1].removesuffix('.tscn')
        if slug not in names:continue
        assert pck.entries[path]['md5']==binding['sourceMd5'],'Rebuild source wave bindings first: '+path
        name=names[slug]
        actors[name]={'source':path,'sourceMd5':binding['sourceMd5'],'usesBasePhaseTimer':name not in ['Brachiosaurus','Carnotaurus'],'states':phase_nodes(pck.read(path).decode('utf-8'),path,source)}
    assert set(actors)==set(names.values()),'Missing Jungle boss phase source'
    timerScene='res://entities/units/enemies/bosses/boss.tscn'
    return {'version':reference['version'],'steamBuild':int(reference['steamBuildId']),
        'elapsedPerTimeout':1,'initialState':-1,'timerScene':timerScene,'timerSceneMd5':pck.entries[timerScene]['md5'],
        'ruleSources':[{'source':p,'sourceMd5':h} for p,h in hashes.items()],
        'actors':actors,'productionAdapterImplemented':False,'nativeFullParityAccepted':False,
        'audit':{'elapsedBeforeSelection':True,'hpInclusive':True,'timeInclusive':True,'everyEligibleLaterChildInOrder':True,
                 'synchronousCallbackBeforeNextChild':True,'sourceIndicesStartAtZero':True,
                 'Carnotaurus':'Timer requests a deferred phase switch after the current jump has landed; not the base HP/time loop.',
                 'Brachiosaurus':'Timer directly calls on_state_changed(current_state) and increments that custom index; not the base HP/time loop.'}}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    data=generate();catalog=module('boss_phase_catalog','tools/build-character-catalog.py')
    text='--!strict\n-- Source Jungle boss phase thresholds; NativeBossPhases handles base Timer callbacks only, custom timers and production controllers remain pending.\nreturn '+catalog.luau(data)+'\n'
    with tempfile.TemporaryDirectory(dir=ROOT/'build') as folder:
        path=Path(folder)/'NativeBossPhases.luau';path.write_text(text,encoding='utf-8')
        subprocess.run(['stylua',str(path)],check=True);text=path.read_text(encoding='utf-8')
    for path,value in {ROOT/'docs/characters/boss-phases-source.json':json.dumps(data,indent=2)+'\n',ROOT/'src/shared/Config/NativeBossPhases.luau':text}.items():
        if args.check:assert path.read_text(encoding='utf-8')==value,'Stale boss phase binding: '+str(path)
        else:path.write_text(value,encoding='utf-8',newline='\n')
    print('Seven Jungle boss phase bindings compiled; two custom timers excluded from base callback controller')

if __name__=='__main__':main()
