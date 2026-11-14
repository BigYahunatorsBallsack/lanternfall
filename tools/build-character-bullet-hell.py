"""Compile the twelve active native bullet-hell patterns, without copying executable scenes or publishing images."""
import argparse, importlib.util, json, re, subprocess, sys, tempfile
from pathlib import Path
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result

def scene(pck, path):
    text = pck.read(path).decode('utf-8')
    resources = {i:path for path,i in re.findall(r'\[ext_resource path="([^"]+)" type="[^"]+" id=(\d+)\]',text)}
    nodes = []
    current = None
    for line in text.splitlines():
        if line.startswith('[node '):
            current = {'name':re.search(r'name="([^"]+)"',line)[1], 'properties':{}}
            nodes.append(current)
        elif line.startswith('['):
            current = None
        elif current is not None and ' = ' in line:
            key,value = line.split(' = ',1)
            current['properties'][key] = value
    return resources,nodes

def scalar(value):
    if value.startswith('Vector2('):
        return [float(x) for x in re.findall(r'-?\d+(?:\.\d+)?',value[len('Vector2('):])]
    if value in ('true','false'):
        return value=='true'
    return float(value) if '.' in value else int(value)

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    source=module('bullet_source',ROOT/'tools/character-source.py');compiler=module('bullet_catalog',ROOT/'tools/build-character-catalog.py');pck=source.Pck(source.DEFAULT_PCK)
    reference = source.verify_reference(pck)
    selector='res://singletons/zone_service.tscn'
    refs,nodes=scene(pck,selector)
    picks=re.findall(r'ExtResource\( (\d+) \)',nodes[0]['properties']['bullets_hell'])
    root_fields=['projectile_damage','projectile_damage_increase_each_wave','projectile_speed','spawn_rate','start_cool_down']
    gen_fields=['anchor_position','offset_anchor_positon','start_cool_down','duplications','duplication_constant_along','duplication_offset_position','duplication_offset_start_cd','speed_factor','spawn_rate_factor','damage_factor','direction','position_spawn_randomness','sinusoidal_motion','sinusoidal_motion_speed','is_active']
    root_defaults=dict(zip(root_fields,[1,0,300,1,0]))
    gen_defaults=dict(zip(gen_fields,[0,[0,0],0,1,0,[0,0],0,1,1,1,[1,0],[0,0],[0,0],[5,5],True]))
    patterns=[]
    for index in picks:
        path=refs[index];_,parts=scene(pck,path)
        props=parts[0]['properties'];root=dict(root_defaults)
        root.update({k:scalar(v) for k,v in props.items() if k in root_fields})
        generators=[]
        for node in parts[1:]:
            values=dict(gen_defaults);values.update({k:scalar(v) for k,v in node['properties'].items() if k in gen_fields})
            generators.append({'name':node['name'],**values})
        patterns.append({'id':Path(path).stem,'source':path,'sourceMd5':pck.entries[path]['md5'],**root,'generators':generators})
    sources=[selector,'res://main.gdc','res://singletons/zone_service.gdc','res://projectiles/bullet_hells/bullet_hell.gdc','res://projectiles/bullet_hells/bullets_generator.gdc','res://projectiles/bullet_hells/bullet_hell_projectile.gdc','res://projectiles/bullet_hells/bullet_hell_projectile.tscn','res://projectiles/projectile.gdc','res://singletons/entity_service.gdc']
    facts={'version':reference['version'],'steamBuild':int(reference['steamBuildId']),'sources':[{'source':x,'sourceMd5':pck.entries[x]['md5']} for x in sources], 'rules':{'parameterWaveCap':20,'intervalWaveDivisor':20,'speedPerWave':2,'challengeWaveDivisor':2,'baseDamage':1,'enemyDamageModifier':-50,'exitMarginPixels':100,'hitRadiusPixels':17.0294,'motionDivisor':2,'physicsRate':60,'minimumEnemyFactor':0.01,'curseEndlessDivisor':25},'patterns':patterns}
    outputs={ROOT/'docs/characters/bullet-hell-source.json':json.dumps(facts,indent=2)+'\n',ROOT/'src/shared/Config/NativeBulletHell.luau':'--!strict\n-- Active original environmental projectile patterns and source hashes; consumed by NativeBulletMotion and BulletHell runtime.\nreturn '+compiler.luau(facts)+'\n'}
    for path,text in outputs.items():
        if path.suffix=='.luau':
            with tempfile.TemporaryDirectory(dir=ROOT/'build') as temp:
                candidate=Path(temp)/path.name;candidate.write_text(text,encoding='utf-8');subprocess.run(['stylua',str(candidate)],check=True);text=candidate.read_text(encoding='utf-8')
        if args.check: assert path.read_text(encoding='utf-8')==text,f'Stale bullet hell facts: {path}'
        else: path.write_text(text,encoding='utf-8',newline='\n')
    print(f'{len(patterns)} active native bullet-hell patterns checked')
if __name__=='__main__':main()
