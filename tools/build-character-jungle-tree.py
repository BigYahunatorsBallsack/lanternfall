"""Compile the source Jungle neutral tree; preserve canonical Tree family and local-only art."""
from __future__ import annotations
import argparse, importlib.util, json, subprocess, sys, tempfile
from pathlib import Path
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]

def module(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT/path)
    result = importlib.util.module_from_spec(spec); spec.loader.exec_module(result); return result

def generate():
    source = module('tree_source', 'tools/character-source.py')
    scene = module('tree_scene', 'tools/build-character-pets.py')
    art = module('tree_art', 'tools/prepare-character-jungle-art.py')
    pck = source.Pck(); reference = source.verify_reference(pck)
    path = 'res://entities/units/neutral/tree_jungle.tscn'
    cache, chain = {}, []
    def resolve(path):
        data = scene.read_scene(pck, path); cache[path] = data; chain.append(path)
        nodes = resolve(data['baseScene']) if data.get('baseScene') else {}
        nodes = {k: {'properties': dict(v['properties']), 'scriptSource': v.get('scriptSource')} for k,v in nodes.items()}
        for n in data['nodes']:
            key = (n['parent'] or '@', n['name'] if n['parent'] else '@'); before = nodes.get(key,{})
            nodes[key] = {'scriptSource': n.get('scriptSource') or before.get('scriptSource'), 'properties': {**before.get('properties',{}), **n['properties']}}
        return nodes
    nodes = resolve(path); root = nodes[('@','@')]
    assert root['scriptSource'] == 'res://entities/units/neutral/neutral.gd'
    script = 'res://entities/units/neutral/neutral.gdc'
    assert pck.entries[script]['md5'] == '1e38d4f03af56046f66c85dbb304692f', 'Re-audit Neutral hit rules'
    def circle(parent):
        props = nodes[(parent,'Collision')]['properties']; file, ident = props['shape']['resource'].split('::')
        shape = cache[file]['shapes'][ident]; assert shape['resourceType'] == 'CircleShape2D'
        offset = props.get('position',{}).get('values',[0,0])
        if parent != '.':
            pp = nodes[('.',parent)]['properties']
            assert pp.get('scale',{}).get('values',[1,1]) == [1,1] and pp.get('rotation',0) == 0
            offset = [a+b for a,b in zip(offset,pp.get('position',{}).get('values',[0,0]))]
        return {'radiusPoints':shape['properties']['radius'],'offsetPoints':offset}
    statsPath = root['properties']['stats']['resource']; stats = pck.resource(statsPath)['properties']
    stats = {k:v for k,v in stats.items() if isinstance(v,(int,float,bool))}
    return {'version':reference['version'],'steamBuild':int(reference['steamBuildId']),
        'source':path,'sourceMd5':pck.entries[path]['md5'],
        'sceneChain':[{'source':p,'sourceMd5':pck.entries[p]['md5']} for p in chain],
        'statsSource':statsPath,'statsMd5':pck.entries[statsPath]['md5'],'stats':stats,
        'body':circle('.'),'hurt':circle('Hurtbox'),
        'bodyLayer':root['properties']['collision_layer'],'bodyMask':root['properties']['collision_mask'],
        'hitLimit':root['properties']['number_of_hits_before_dying'],
        'mass':root['properties'].get('mass',1),
        'ruleSource':{'source':script,'sourceMd5':pck.entries[script]['md5']},
        'sprite':art.texture_metadata(pck,art.body_texture(pck,path)),
        'zoneId':2,'typeId':71,'actorRegistered':True,'zonePlayable':False,'nativeFullParityAccepted':False,
        'audit':{'neutralClassNotEnemy':True,'countAllTakeDamageCalls':True,
                 'executionRejectsNonPlayerHitboxOwner':True,'noHitboxCanExecute':True,
                 'oneShotTreesIndependentOfHitLimit':True,'incrementsTreesKilledAfterSuperDie':True}}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    data=generate();compiler=module('tree_catalog','tools/build-character-catalog.py')
    text='--!strict\n-- Source neutral Jungle tree; EnemyKinds retains canonical Tree identity for existing loot and character listeners.\nlocal POINT=require(script.Parent.Stats).range.studsPerPoint\nlocal data='+compiler.luau(data)+'''
local s=data.stats
data.kind={
 id='Tree', typeId=data.typeId, displayName='Tree', look='Tree', nativeArtPending=true,
 nativeZoneId=data.zoneId, nativeScene=data.source, specialSpawn=true, anchored=true,
 hp=s.health,hpPerWave=s.health_increase_each_wave,contactDamage=s.damage,damagePerWave=s.damage_increase_each_wave,
 speed=s.speed*POINT,nativeSpeedPoints={base=s.speed,randomization=s.speed_randomization},xp=s.value,
 radius=data.body.radiusPoints*POINT,hurtRadius=data.hurt.radiusPoints*POINT,hitRadius=0,
 nativeBodyOffsetX=data.body.offsetPoints[1]*POINT,nativeBodyOffsetZ=data.body.offsetPoints[2]*POINT,
 nativeHurtOffsetX=data.hurt.offsetPoints[1]*POINT,nativeHurtOffsetZ=data.hurt.offsetPoints[2]*POINT,
 nativeBodyLayer=data.bodyLayer,nativeBodyMask=data.bodyMask,nativeObstacleCollision=bit32.band(data.bodyMask,128)~=0,
 nativeHealthRounding=true,nativeDamageRounding=true,nativeNeutralHitLimit=data.hitLimit,
 nativeCanBeBoosted=false,nativeCanBeCharmed=false,nativeCanBeCursed=false,
 mass=data.mass,knockbackResistance=s.knockback_resistance,
 loot={consumableChance=s.base_drop_chance,crateShare=s.item_drop_chance,alwaysOrbs=true},
}
return data
'''
    with tempfile.TemporaryDirectory(dir=ROOT/'build') as folder:
        temp=Path(folder)/'NativeJungleTree.luau';temp.write_text(text,encoding='utf-8')
        subprocess.run(['stylua',str(temp)],check=True);text=temp.read_text(encoding='utf-8')
    for path,value in {ROOT/'docs/characters/jungle-tree-source.json':json.dumps(data,indent=2)+'\n',ROOT/'src/shared/Config/NativeJungleTree.luau':text}.items():
        if args.check: assert path.read_text(encoding='utf-8')==value,'Stale Jungle tree source: '+str(path)
        else:path.write_text(value,encoding='utf-8',newline='\n')
    print('Jungle neutral tree compiled; area and full parity remain open')

if __name__=='__main__':main()
