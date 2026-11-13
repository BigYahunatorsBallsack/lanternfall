"""Compile explicitly ported neutral Jungle body families into the enemy engine.
Evolution variants remain explicit pending work. No zone is exposed.
"""
from __future__ import annotations
import argparse, importlib.util, json, re, subprocess, sys, tempfile
from pathlib import Path
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
FAMILIES = {'baby_triceratops': ('BabyTriceratops', 40, 'Baby Triceratops'), 'gallimimus': ('Gallimimus', 41, 'Gallimimus'), 'lystrosaurus': ('Lystrosaurus', 42, 'Lystrosaurus'), 'pyroraptor': ('Pyroraptor', 43, 'Pyroraptor'), 'enigmacursor': ('Enigmacursor', 44, 'Enigmacursor'), 'baby_pterosaur': ('BabyPterosaur',45,'Baby Pterosaur'), 'graciliceratops': ('Graciliceratops',46,'Graciliceratops'), 'baby_trex': ('BabyTrex',47,'Baby T-Rex'), 'alamosaurus': ('Alamosaurus',48,'Alamosaurus'), 'dino_egg': ('DinoEgg',49,'Dino Egg'), 'stintaosaurus': ('Stintaosaurus',50,'Tsintaosaurus')}

def module(name, file):
 spec = importlib.util.spec_from_file_location(name, ROOT/file)
 result = importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result

def generate():
 source = module('jungle_source', 'tools/character-source.py')
 scenes = module('jungle_scenes', 'tools/build-character-pets.py')
 pck = source.Pck();reference = source.verify_reference(pck)
 cache = {};used_scripts = set()
 def resolve(path):
  scene = scenes.read_scene(pck,path);cache[path] = scene
  nodes = resolve(scene['baseScene']) if scene.get('baseScene') else {}
  nodes = {key:dict(value) for key,value in nodes.items()}
  for node in scene['nodes']:
   key = (node['parent'] or '@',node['name'] if node['parent'] else '@')
   before = nodes.get(key,{})
   nodes[key] = {'scriptSource':node.get('scriptSource') or before.get('scriptSource'), 'properties':{**before.get('properties',{}),**node['properties']}}
  return nodes
 def circle(node):
  path,ident = node['properties']['shape']['resource'].split('::')
  shape = cache[path]['shapes'][ident]
  assert shape['resourceType'] == 'CircleShape2D'
  offset = node['properties'].get('position',{}).get('values',[0,0])
  return {'radiusPoints':shape['properties'].get('radius',10), 'offsetPoints':offset, 'source':path, 'sourceMd5':pck.entries[path]['md5']}
 enemies = {}
 for slug,(identity,type_id,name) in FAMILIES.items():
  path = f'res://entities/units/enemies/jungle/basic/{slug}/{slug}.tscn'
  nodes = resolve(path);root = nodes[('@','@')];move = nodes[('.','MovementBehavior')];attack = nodes[('.','AttackBehavior')]
  assert root['scriptSource'] == (f'res://entities/units/enemies/jungle/basic/{slug}/{slug}.gd' if slug in ['baby_trex','dino_egg','stintaosaurus'] else 'res://entities/units/enemies/enemy.gd')
  if slug == 'enigmacursor':
   assert move['scriptSource'] == 'res://entities/units/movement_behaviors/stay_in_range_from_player_movement_behavior.gd'
   assert attack['scriptSource'] == 'res://entities/units/movement_behaviors/detect_evolution_attack_behavior.gd'
  elif slug=='stintaosaurus':
   assert move['scriptSource']=='res://entities/units/movement_behaviors/target_rand_pos_movement_behavior.gd'
   assert attack['scriptSource']=='res://entities/units/enemies/attack_behaviors/attack_behavior.gd'
  elif slug in ['alamosaurus','dino_egg']:
   expected='target_rand_pos_movement_behavior.gd' if slug=='alamosaurus' else 'stay_in_range_from_player_movement_behavior.gd'
   assert move['scriptSource']=='res://entities/units/movement_behaviors/'+expected
   assert attack['scriptSource']=='res://entities/units/enemies/attack_behaviors/spawning_attack_behavior.gd'
  elif slug in ['baby_pterosaur','graciliceratops']:
   assert move['scriptSource'] == 'res://entities/units/movement_behaviors/anticipate_target_movement_behavior.gd'
   assert attack['scriptSource'] == 'res://entities/units/enemies/attack_behaviors/attack_behavior.gd'
   assert not move['properties'].get('stop_close_to_target',False), 'Close-target stopping needs an explicit policy'
  else:
   assert move['scriptSource'] == 'res://entities/units/movement_behaviors/follow_target_movement_behavior.gd'
   assert attack['scriptSource'] == 'res://entities/units/enemies/attack_behaviors/attack_behavior.gd'
  for node in [root,move,attack]:used_scripts.add(node['scriptSource'].removesuffix('.gd')+'.gdc')
  stats_path = root['properties']['stats']['resource'];stats = {k:v for k,v in pck.resource(stats_path)['properties'].items() if isinstance(v,(int,float,bool))}
  assert stats['armor'] == 0 and stats['armor_increase_each_wave'] == 0, 'Armor requires its own runtime policy'
  enemies[identity] = {'typeId':type_id,'displayName':name,'fallbackLook':'Shadeling','source':path,'sourceMd5':pck.entries[path]['md5'],'statsSource':stats_path,'statsMd5':pck.entries[stats_path]['md5'],'stats':stats,'body':circle(nodes[('.','Collision')]),'hurt':circle(nodes[('Hurtbox','Collision')]),'hit':circle(nodes[('Hitbox','Collision')]),'removeFirst':root['properties'].get('to_be_removed_in_priority',False),'mass':root['properties'].get('mass',1)}
  if slug=='stintaosaurus':
   assert nodes[('.','BoostZone')]['properties']['collision_mask']==4
   enemies[identity]['healing']={k:root['properties'][k] for k in ['heal','heal_increase_each_wave','player_heal','player_heal_increase_each_wave']}
   enemies[identity]['healing'].update(zone=circle(nodes[('BoostZone','BoostCollision')]),charmRetainsEnemyMask=True)
   used_scripts.add('res://effect_behaviors/enemies/charm_enemy_effect_behavior.gdc')
  if slug in ['alamosaurus','dino_egg']:
   props=attack['properties']
   assert not props['spawn_at_random_pos'] and not props['spawn_at_player_range']
   raw=pck.read(path).decode('utf-8');refs={i:v for v,i in re.findall(r'\[ext_resource path="([^"]+)" type="[^"]+" id=(\d+)\]',raw)}
   target=re.search(r'^enemy_to_spawn = ExtResource\( (\d+) \)',raw,re.M)
   child=refs[target[1]]
   expected='dino_egg' if slug=='alamosaurus' else 'baby_trex'
   assert child==f'res://entities/units/enemies/jungle/basic/{expected}/{expected}.tscn'
   enemies[identity]['spawning']={'properties':props,'child':'DinoEgg' if slug=='alamosaurus' else 'BabyTrex','childSource':child,'childSourceMd5':pck.entries[child]['md5'],'diesOnRequest':slug=='dino_egg','movement':move['properties']}
   used_scripts.update(['res://global/entity_spawner.gdc','res://singletons/zone_service.gdc'])
  if slug == 'baby_trex':
   properties=root['properties']
   alternate=nodes[('.','MovementBehaviorOnBoost')]
   assert alternate['scriptSource']==move['scriptSource'] and not alternate['properties'].get('stop_close_to_target',False)
   assert not properties['reset_nb_times_boosted_on_hit']
   assert nodes[('.','BoostTimer')]['properties']['autostart']
   enemies[identity]['pursuer']={k:properties[k] for k in ['boost_cooldown','max_boosts','speed_on_boost','damage_on_boost','size_on_boost','change_movement_behavior_after_x_boosts','bonus_speed_on_change_movement_behavior','reset_nb_times_boosted_on_hit','max_player_speed_multiplier']}
   enemies[identity]['pursuer'].update(collisionScalingShare=0.25,spriteRisePoints=40)
   used_scripts.update(['res://entities/units/enemies/crash_zone/basic/pursuer/pursuer.gdc','res://entities/units/unit/unit.gdc','res://singletons/entity_service.gdc'])
  if slug in ['baby_pterosaur','graciliceratops']:
   enemies[identity]['anticipate'] = {'seconds':move['properties']['anticipation_time'],'horizontalOnly':move['properties'].get('should_target_vertically',False)}
  if slug == 'enigmacursor':
   variants = {}
   for variant in ['Normal','Meca','Mutant']:
    node = nodes[('AttackBehavior','AttackBehavior'+variant)]
    assert node['scriptSource'] == 'res://entities/units/enemies/attack_behaviors/shooting_attack_behavior.gd'
    used_scripts.add(node['scriptSource'].removesuffix('.gd')+'.gdc')
    # Script defaults are explicit neutral facts; resource overrides remain authoritative.
    defaults = {'damage':1,'damage_increase_each_wave':1.0,'max_range':500,'min_range':0,'cooldown':60.0,'initial_cooldown':0,'max_cd_randomization':10,'attack_anim_speed':1.0,'number_projectiles':1,'projectile_spread':0.0,'constant_spread':False,'speed_change_after_each_projectile':0,'projectile_speed':3000}
    values = {**defaults,**node['properties']}
    variants[variant] = {k:v for k,v in values.items() if isinstance(v,(int,float,bool)) or k == 'position'}
   raw = pck.read(path).decode('utf-8')
   prefix = raw.split('\n[node ')[0].replace('[gd_scene','[gd_resource type="PackedScene"',1)+'\n[resource]\n'
   external = {str(r['id']):r['path'] for r in source.parse_tres(prefix,path)['externalResources']}
   normal_block = raw.split('[node name="AttackBehaviorNormal"',1)[1].split('\n[node ',1)[0]
   projectile_ref = re.search(r'^projectile_scene = ExtResource\( (\d+) \)',normal_block,re.M)
   assert projectile_ref and external[projectile_ref[1]] == 'res://projectiles/pillar_enemy/pillar_projectile.tscn', 'Different native projectile needs its own behavior'
   enemies[identity].update(movement=move['properties'],shootingVariants=variants,activeVariant='Normal',evolutionVariantsImplemented=False,projectileSource=external[projectile_ref[1]])
 animation_path = 'res://entities/units/enemies/attack_behaviors/enemy_charge_prep_animation.tres'
 animation = pck.resource(animation_path)['properties']
 methods = next(v for k,v in animation.items() if k.endswith('/keys') and isinstance(v,dict) and any(isinstance(value,dict) and value.get('method') == 'shoot' for value in v.get('values',[])))
 fire_at = next(t for t,v in zip(methods['times'],methods['values']) if v['method']=='shoot')
 pillar_path = 'res://projectiles/pillar_enemy/pillar_projectile.tscn'
 pillar_scene = scenes.read_scene(pck,pillar_path)
 raw = pck.read(pillar_path).decode('utf-8');header = raw.split('\n[node ')[0].replace('[gd_scene','[gd_resource type="PackedScene"',1)+'\n[resource]\n'
 sub = source.parse_tres(header,pillar_path)['subresources']
 anim = next(r['properties'] for r in sub.values() if r['resourceType']=='Animation' and r['properties'].get('resource_name')=='shoot')
 track = next(v for k,v in anim.items() if k.endswith('/keys') and isinstance(v,dict) and any(isinstance(value,dict) and value.get('method')=='enable_hitbox' for value in v.get('values',[])))
 method_times = {v['method']:t for t,v in zip(track['times'],track['values']) if t>0}
 hitbox = next(n['properties'] for n in pillar_scene['nodes'] if n['name']=='Hitbox')
 collision = next(n['properties'] for n in pillar_scene['nodes'] if n['name']=='Collision')
 shape_id = collision['shape']['resource'].split('::')[1]
 pillar = {'source':pillar_path,'sourceMd5':pck.entries[pillar_path]['md5'],'radiusPoints':pillar_scene['shapes'][shape_id]['properties']['radius'],'offsetPoints':[a+b for a,b in zip(hitbox['position']['values'],collision['position']['values'])],'hitFrom':method_times['enable_hitbox'],'hitUntil':method_times['disable_hitbox'],'stopAt':method_times['stop']}
 spawn_animations=[]
 for anim_path in ['res://entities/units/enemies/attack_behaviors/shoot.tres','res://entities/units/enemies/attack_behaviors/shoot_charmed.tres']:
  props=pck.resource(anim_path)['properties']
  track=next(v for k,v in props.items() if k.endswith('/keys') and isinstance(v,dict) and any(isinstance(value,dict) and value.get('method')=='shoot' for value in v.get('values',[])))
  fire=next(t for t,v in zip(track['times'],track['values']) if v['method']=='shoot')
  spawn_animations.append({'source':anim_path,'sourceMd5':pck.entries[anim_path]['md5'],'fireAt':fire,'seconds':props.get('length',1)})
 assert spawn_animations[0]['fireAt']==spawn_animations[1]['fireAt'] and spawn_animations[0]['seconds']==spawn_animations[1]['seconds']
 zone = 'res://zones/zone_3_jungle/zone_jungle_data.tres'
 return {'version':reference['version'],'steamBuild':int(reference['steamBuildId']),'zoneId':pck.resource(zone)['properties']['my_id'],'zoneSource':zone,'zoneSourceMd5':pck.entries[zone]['md5'],'zonePlayable':False,'implemented':list(enemies),'enemies':enemies,'spawningRules':{'animations':spawn_animations,'frameRate':60,'minimumCooldownFrames':1,'goalPrecisionPoints':10},'shootingRules':{'frameRate':60,'minimumCooldownFrames':1,'animationFireAt':fire_at,'animationSeconds':animation.get('length',1),'animationSource':animation_path,'animationSourceMd5':pck.entries[animation_path]['md5'],'pillar':pillar,'projectileRadiusPoints':pillar['radiusPoints'],'projectileRangeStuds':300,'projectileRangeNote':'Existing engine lifetime/area compatibility limit, not a native range stat'},'ruleSources':[{'source':path,'sourceMd5':pck.entries[path]['md5']} for path in sorted(used_scripts)],'runtimeCompatibility':{'mass':1,'nativeArtAccepted':False,'physicsAccepted':False,'open':['Existing global body/collision center approximation; source offsets retained explicitly','Native physics ordering and sprite acceptance','Spawning reuses existing square/edge clamp; native forbidden-zone retries/push-out remain part of the pending area/physics port','Enigmacursor Meca/Mutant branches are source facts only; no native evolution-system acceptance','Fallback circle telegraphs instead of original animated pillar sprites','Remaining Jungle families, waves, bosses and area route']}}

def main():
 args=argparse.ArgumentParser(description=__doc__);args.add_argument('--check',action='store_true');args=args.parse_args()
 compiler=module('jungle_catalog','tools/build-character-catalog.py');data=generate()
 files={ROOT/'docs/characters/jungle-walkers-source.json':json.dumps(data,indent=2)+'\n',ROOT/'src/shared/Config/JungleWalkers.luau':'--!strict\n-- Source-backed neutral Jungle families; JungleEnemyKinds activates explicitly ported branches. No playable zone is claimed.\nreturn '+compiler.luau(data)+'\n'}
 for path,text in files.items():
  if path.suffix=='.luau':
   with tempfile.TemporaryDirectory(dir=ROOT/'build') as folder:
    temp=Path(folder)/path.name;temp.write_text(text,encoding='utf-8');subprocess.run(['stylua',str(temp)],check=True);text=temp.read_text(encoding='utf-8')
  if args.check:assert path.read_text(encoding='utf-8')==text,f'Stale Jungle pursuit facts: {path}'
  else:path.write_text(text,encoding='utf-8',newline='\n')
 print(str(len(data['implemented']))+' neutral Jungle body families compiled; evolution and playable Jungle remain open')
if __name__=='__main__':main()
