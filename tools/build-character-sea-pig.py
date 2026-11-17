"""Compile the actual global DLC Sea Pig actor, patrol and credited-player death reward."""
from __future__ import annotations
import argparse, importlib.util, json, subprocess, sys, tempfile
from pathlib import Path
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]

def module(name, path):
 spec = importlib.util.spec_from_file_location(name, ROOT/path)
 result = importlib.util.module_from_spec(spec); spec.loader.exec_module(result); return result

def generate():
 source = module('pig_source', 'tools/character-source.py')
 scene = module('pig_scene', 'tools/build-character-pets.py')
 art = module('pig_art', 'tools/prepare-character-jungle-art.py')
 pck = source.Pck(); reference = source.verify_reference(pck)
 path = 'res://entities/units/enemies/abyss/basic/sea_pig/sea_pig.tscn'
 cache = {}; chain = []
 def resolve(path):
  data = scene.read_scene(pck, path); cache[path] = data; chain.append(path)
  nodes = resolve(data['baseScene']) if data.get('baseScene') else {}
  nodes = {k: {'properties': dict(v['properties']), 'scriptSource': v.get('scriptSource')} for k,v in nodes.items()}
  for n in data['nodes']:
   key = (n['parent'] or '@', n['name'] if n['parent'] else '@'); before = nodes.get(key,{})
   nodes[key] = {'scriptSource': n.get('scriptSource') or before.get('scriptSource'), 'properties': {**before.get('properties',{}), **n['properties']}}
  return nodes
 nodes = resolve(path); root = nodes[('@','@')]; move = nodes[('.','MovementBehavior')]
 assert root['scriptSource'] == 'res://entities/units/enemies/abyss/basic/sea_pig/sea_pig.gd'
 assert move['scriptSource'] == 'res://entities/units/movement_behaviors/patrol_edges_of_map_movement_behavior.gd'
 for key in ['can_be_boosted','can_be_cursed','can_be_charmed']: assert root['properties'][key] is False
 def circle(parent):
  props = nodes[(parent,'Collision')]['properties']; file, ident = props['shape']['resource'].split('::')
  shape = cache[file]['shapes'][ident]; assert shape['resourceType'] == 'CircleShape2D'
  offset = props.get('position',{}).get('values',[0,0])
  if parent != '.':
   pp = nodes[('.',parent)]['properties']
   assert pp.get('scale',{}).get('values',[1,1]) == [1,1] and pp.get('rotation',0) == 0
   offset = [a+b for a,b in zip(offset, pp.get('position',{}).get('values',[0,0]))]
  return {'radiusPoints': shape['properties']['radius'], 'offsetPoints': offset}
 statsPath = root['properties']['stats']['resource']
 stats = {k:v for k,v in pck.resource(statsPath)['properties'].items() if isinstance(v,(int,float,bool))}
 scripts = [root['scriptSource'],move['scriptSource'],'res://singletons/utils.gd']
 return {'version':reference['version'],'steamBuild':int(reference['steamBuildId']),
  'source':path,'sourceMd5':pck.entries[path]['md5'],
  'sceneChain':[{'source':p,'sourceMd5':pck.entries[p]['md5']} for p in chain],
  'statsSource':statsPath,'statsMd5':pck.entries[statsPath]['md5'],'stats':stats,
  'movement':move['properties'],'body':circle('.'),'hurt':circle('Hurtbox'),'hit':circle('Hitbox'),
  'mass':root['properties'].get('mass',1),
  'bodyLayer':root['properties']['collision_layer'],'bodyMask':root['properties']['collision_mask'],
  'bodyBorders':root['properties'].get('should_collide_with_borders',True),
  'sprite':art.texture_metadata(pck,art.body_texture(pck,path)),
  'ruleSources':[{'source':p.removesuffix('.gd')+'.gdc','sourceMd5':pck.entries[p.removesuffix('.gd')+'.gdc']['md5']} for p in scripts],
  'sourceConstants':{'edgeMapDistancePoints':64,'cornerThreshold':0.5,'noneDirectionOrder':['Bottom','Right','Left','Top'],'curseOnCreditedPlayerKill':1,'goalPrecisionPoints':10},
  'actorRegistered':True,'nativeFullParityAccepted':False,
  'specialSpawnNote':'Explicit native global-DLC group only; exclude this actor from the legacy ambient chooser.',
  'bindingAudit':{'canBeBoosted':False,'canBeCursed':False,'canBeCharmed':False,'goldEatingImplementedByBoundScript':False,'patrolMaxTargetDistanceOverwritten':True,'rewardAfterSuperDie':True}}

def main():
 parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--check',action='store_true'); args=parser.parse_args()
 data=generate(); compiler=module('pig_catalog','tools/build-character-catalog.py')
 text='--!strict\n-- Source global DLC Sea Pig actor; Config.Enemies registers its data and native rewards follow normal death listeners.\nlocal POINT=require(script.Parent.Stats).range.studsPerPoint\nlocal data='+compiler.luau(data)+'''
data.patrolRule = {
 edgeDistancePoints=data.movement.edge_distance, edgeRandomizationPoints=data.movement.edge_randomization,
 minimumInsetPoints=data.sourceConstants.edgeMapDistancePoints/2, cornerThreshold=data.sourceConstants.cornerThreshold,
 noneDirectionOrder=data.sourceConstants.noneDirectionOrder, pixel=POINT,
}
local s=data.stats
data.kind = {
 id='SeaPig', typeId=70, displayName='Sea Pig', look='Shadeling', nativeArtPending=true, specialSpawn=true, nativeScene=data.source,
 hp=s.health, hpPerWave=s.health_increase_each_wave, contactDamage=s.damage, damagePerWave=s.damage_increase_each_wave,
 speed=s.speed*POINT, speedMax=s.speed*POINT, nativeSpeedPoints={base=s.speed,randomization=s.speed_randomization}, xp=s.value,
 radius=data.body.radiusPoints*POINT, hurtRadius=data.hurt.radiusPoints*POINT, hitRadius=data.hit.radiusPoints*POINT,
 nativeBodyOffsetX=data.body.offsetPoints[1]*POINT, nativeBodyOffsetZ=data.body.offsetPoints[2]*POINT,
 nativeHurtOffsetX=data.hurt.offsetPoints[1]*POINT, nativeHurtOffsetZ=data.hurt.offsetPoints[2]*POINT,
 nativeHitOffsetX=data.hit.offsetPoints[1]*POINT, nativeHitOffsetZ=data.hit.offsetPoints[2]*POINT,
 nativeBodyLayer=data.bodyLayer, nativeBodyMask=data.bodyMask, nativeObstacleCollision=bit32.band(data.bodyMask,128)~=0,
 nativeMovement={goalInsetX=data.sprite.widthPoints*POINT/2,goalInsetZ=data.sprite.heightPoints*POINT/2,borderClamp=data.bodyBorders,collidePlayers=bit32.band(data.bodyMask,2)~=0,precision=data.sourceConstants.goalPrecisionPoints*POINT},
 nativeEdgePatrol=data.patrolRule, nativeDamageRounding=true, nativeHealthRounding=true,
 nativeCanBeBoosted=false, nativeCanBeCharmed=false, nativeCanBeCursed=false,
 nativePlayerKillStats={curse=data.sourceConstants.curseOnCreditedPlayerKill}, mass=data.mass, knockbackResistance=s.knockback_resistance,
 loot={consumableChance=s.base_drop_chance,crateShare=s.item_drop_chance},
}
return data
'''
 with tempfile.TemporaryDirectory(dir=ROOT/'build') as folder:
  temp=Path(folder)/'NativeSeaPig.luau'; temp.write_text(text,encoding='utf-8')
  subprocess.run(['stylua',str(temp)],check=True); text=temp.read_text(encoding='utf-8')
 outputs={ROOT/'docs/characters/sea-pig-source.json':json.dumps(data,indent=2)+'\n',ROOT/'src/shared/Config/NativeSeaPig.luau':text}
 for path,value in outputs.items():
  if args.check: assert path.read_text(encoding='utf-8') == value, 'Stale Sea Pig source binding: '+str(path)
  else: path.write_text(value,encoding='utf-8',newline='\n')
 print('Sea Pig source actor compiled; no playable area or full parity claimed')
if __name__ == '__main__': main()
