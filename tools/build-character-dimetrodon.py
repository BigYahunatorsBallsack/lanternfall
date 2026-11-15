"""Compile stable Dimetrodon bindings for tested movement components; no actor registration or playable area."""
from __future__ import annotations
import argparse, importlib.util, json, re, subprocess, sys, tempfile
from pathlib import Path
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]

def module(name, path):
 spec=importlib.util.spec_from_file_location(name,ROOT/path);result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result

def generate():
 source=module('dimetrodon_source','tools/character-source.py');scenes=module('dimetrodon_scenes','tools/build-character-pets.py')
 pck=source.Pck();reference=source.verify_reference(pck)
 path='res://entities/units/enemies/jungle/basic/dimetrodon/dimetrodon.tscn'
 scene=scenes.read_scene(pck,path)
 def node(name,parent):return next(n for n in scene['nodes'] if n['name']==name and n['parent']==parent)
 root=next(n for n in scene['nodes'] if n['parent'] is None)
 move=node('MovementBehavior','.');jump=node('AttackBehavior','.')
 assert root['scriptSource']=='res://entities/units/enemies/jungle/basic/dimetrodon/dimetrodon.gd'
 assert move['scriptSource']=='res://entities/units/movement_behaviors/patrol_edges_of_map_movement_behavior.gd'
 assert jump['scriptSource']=='res://entities/units/enemies/attack_behaviors/jump_attack_behavior.gd'
 assert node('Land_shoot_behavior','.')['scriptSource']=='res://entities/units/enemies/attack_behaviors/shooting_attack_behavior.gd'
 stats=root['properties']['stats']['resource']
 bulletPath='res://projectiles/bullet_enemy/enemy_projectile.tscn'
 bullet=pck.read(bulletPath).decode('utf-8')
 bulletRadius=float(re.search(r'radius = ([0-9.]+)',bullet)[1])
 raw=pck.read(path).decode('utf-8');prefix=raw.split('\n[node ')[0].replace('[gd_scene','[gd_resource type="PackedScene"',1)+'\n[resource]\n'
 attacks={}
 for name,parent in [('Land_shoot_behavior','.'),('AttackBehaviorNormal','DeathShootProjectilesBehavior'),('AttackBehaviorMeca','DeathShootProjectilesBehavior'),('AttackBehaviorMutant','DeathShootProjectilesBehavior')]:
  block=raw.split('[node name="'+name+'"',1)[1].split('\n[node ',1)[0].split(']\n',1)[1]
  props=source.parse_tres(prefix+block,path)['properties']
  attacks[name]={'properties':{k:v for k,v in props.items() if isinstance(v,(int,float,bool))},'projectile':props.get('projectile_scene',{'resource':'res://projectiles/bullet_enemy/enemy_projectile.tscn'})['resource']}
 assert attacks['AttackBehaviorNormal']['projectile']=='res://projectiles/bullet_enemy/enemy_projectile.tscn'
 for key in ['number_projectiles','projectile_spawn_spread','projectile_spawn_only_on_borders','constant_spread','shoot_away_from_unit']:
  assert attacks['Land_shoot_behavior']['properties'][key]==attacks['AttackBehaviorNormal']['properties'][key], 'Separate land/death geometry required: '+key
 scripts=[root['scriptSource'],move['scriptSource'],jump['scriptSource'],node('Land_shoot_behavior','.')['scriptSource'],'res://global/entity_spawner.gd','res://singletons/utils.gd']
 return {'version':reference['version'],'steamBuild':int(reference['steamBuildId']),'source':path,'sourceMd5':pck.entries[path]['md5'],'actorRegistered':False,'worldAdapterImplemented':False,'worldComponentAdapterImplemented':True,
  'projectileCollider':{'source':bulletPath,'sourceMd5':pck.entries[bulletPath]['md5'],'radiusPoints':bulletRadius},
  'movement':move['properties'],'jump':jump['properties'],'stats':{k:v for k,v in pck.resource(stats)['properties'].items() if isinstance(v,(int,float,bool))},'statsSource':stats,'statsMd5':pck.entries[stats]['md5'],'attacks':attacks,
  'scriptSources':[{'source':p.removesuffix('.gd')+'.gdc','sourceMd5':pck.entries[p.removesuffix('.gd')+'.gdc']['md5']} for p in scripts],
  'bindingAudit':{'directLandingDamageImplementedByBoundMethod':False,'exportedJumpDamageUnused':True,'exportedLandingRadiusUnused':True,'patrolMaxTargetDistanceOverwritten':True,'freshJumpTimer':0,'freshLandingTimer':0,'poolRespawnCallsReset':True,'coldSpawnerCallsInitWithoutRespawn':True},
  'engineSource':{'url':'https://raw.githubusercontent.com/godotengine/godot/3.5.3-stable/core/math/math_funcs.cpp','symbol':'Math::ease','line':97},
  'sourceConstants':{'defaultProjectileDamage':1,'deathWaveCutoffSeconds':0.5,'edgeMapDistancePoints':64,'cornerRandomThreshold':0.5,'fallEasePower':3,'riseShare':0.5,'noneDirectionOrder':['Bottom','Right','Left','Top']}}

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
 compiler=module('dimetrodon_catalog','tools/build-character-catalog.py');data=generate()
 text='--!strict\n-- Source Dimetrodon bindings for jump/edge-patrol components; actor registration and full client integration remain pending.\nlocal POINT = require(script.Parent.Stats).range.studsPerPoint\nlocal data = '+compiler.luau(data)+'''
data.jumpRule = {
 cooldown = data.jump.cooldown, duration = data.jump.jump_duration,
 height = data.jump.jump_height * POINT, delay = data.jump.jump_delay,
 landingCooldown = data.jump.landing_cooldown,
 freshCooldown = data.bindingAudit.freshJumpTimer, freshLandingCooldown = data.bindingAudit.freshLandingTimer,
 fallEasePower = data.sourceConstants.fallEasePower, riseShare = data.sourceConstants.riseShare,
}
data.patrolRule = {
 edgeDistancePoints = data.movement.edge_distance, edgeRandomizationPoints = data.movement.edge_randomization,
 minimumInsetPoints = data.sourceConstants.edgeMapDistancePoints / 2,
 cornerThreshold = data.sourceConstants.cornerRandomThreshold,
 noneDirectionOrder = data.sourceConstants.noneDirectionOrder,
 pixel = POINT,
}
local land = data.attacks.Land_shoot_behavior.properties
local death = data.attacks.AttackBehaviorNormal.properties
data.radialRule = {
 projectileDamage = data.sourceConstants.defaultProjectileDamage,
 landSpeed = land.projectile_speed * POINT, deathSpeed = death.projectile_speed * POINT,
 projectileRadius = data.projectileCollider.radiusPoints * POINT,
 projectileRange = require(script.Parent.JungleWalkers).shootingRules.projectileRangeStuds,
 deathWaveCutoffSeconds = data.sourceConstants.deathWaveCutoffSeconds,
 volley = { count = land.number_projectiles, spread = 0, constantSpread = land.constant_spread,
 offsetX = 0, offsetZ = 0, speedStep = 0,
 spawnRing = { radius = land.projectile_spawn_spread / 2 * POINT, away = land.shoot_away_from_unit } },
}
return data
'''
 with tempfile.TemporaryDirectory(dir=ROOT/'build') as folder:
  temp=Path(folder)/'NativeDimetrodon.luau';temp.write_text(text,encoding='utf-8');subprocess.run(['stylua',str(temp)],check=True);text=temp.read_text(encoding='utf-8')
 outputs={ROOT/'docs/characters/dimetrodon-source.json':json.dumps(data,indent=2)+'\n',ROOT/'src/shared/Config/NativeDimetrodon.luau':text}
 for path,value in outputs.items():
  if args.check:assert path.read_text(encoding='utf-8')==value,'Stale Dimetrodon component facts: '+str(path)
  else:path.write_text(value,encoding='utf-8',newline='\n')
 print('Dimetrodon bindings compiled; actorRegistered=false, World adapter pending')
if __name__=='__main__':main()
