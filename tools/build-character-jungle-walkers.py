"""Compile explicitly ported neutral Jungle body families into the enemy engine.
Evolution variants remain explicit pending work. No zone is exposed.
"""
from __future__ import annotations
import argparse, importlib.util, json, re, subprocess, sys, tempfile
from pathlib import Path
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
FAMILIES = {'baby_triceratops': ('BabyTriceratops', 40, 'Baby Triceratops'), 'gallimimus': ('Gallimimus', 41, 'Gallimimus'), 'lystrosaurus': ('Lystrosaurus', 42, 'Lystrosaurus'), 'pyroraptor': ('Pyroraptor', 43, 'Pyroraptor'), 'enigmacursor': ('Enigmacursor', 44, 'Enigmacursor'), 'baby_pterosaur': ('BabyPterosaur',45,'Baby Pterosaur'), 'graciliceratops': ('Graciliceratops',46,'Graciliceratops'), 'baby_trex': ('BabyTrex',47,'Baby T-Rex'), 'alamosaurus': ('Alamosaurus',48,'Alamosaurus'), 'dino_egg': ('DinoEgg',49,'Dino Egg'), 'stintaosaurus': ('Stintaosaurus',50,'Tsintaosaurus'), 'triceratops': ('Triceratops',51,'Triceratops'), 'parasaurolorus': ('Parasaurolorus',52,'Parasaurolophus'), 'ankylosaurus': ('Ankylosaurus',53,'Ankylosaurus'), 'pachycephalosaurus': ('Pachycephalosaurus',54,'Pachycephalosaurus'), 'velociraptor': ('Velociraptor',55,'Velociraptor'), 'jeholopterus': ('Jeholopterus',56,'Jeholopterus'), 'giant_dragonfly': ('GiantDragonfly',57,'Giant Dragonfly'), 'harpymimus_looter': ('HarpymimusLooter',58,'Harpymimus Looter')}

# Crossing families share one scene-bound movement policy; original presentation remains pending.
CROSSERS = {'oviraptor': ('Oviraptor',59,'Oviraptor'), 'iguanodon': ('Iguanodon',60,'Iguanodon')}
FAMILIES.update(CROSSERS)
FAMILIES['pterosaur']=('Pterosaur',61,'Pterosaur')
FAMILIES['dilophosaurus']=('Dilophosaurus',64,'Dilophosaurus')
FAMILIES.update({'hesperosaurus':('Hesperosaurus',62,'Hesperosaurus'),'stegosaurus':('Stegosaurus',63,'Stegosaurus')})

PLANTS = {'carnivorus_plant': ('CarnivorousPlant',65,'Carnivorous Plant'), 'carnivorus_plant_mother': ('CarnivorousPlantMother',66,'Carnivorous Plant Mother')}
FAMILIES.update(PLANTS)
FAMILIES['pachyrhinosaurus']=('Pachyrhinosaurus',67,'Pachyrhinosaurus')
FAMILIES['evil_mob_jungle']=('JungleGobbler',68,'Jungle Gobbler')

CHARGE_DEFAULTS = {'cooldown':60.0,'long_cooldown_every_x_shoots':0,'long_cooldown':0.0,'max_cd_randomization':10,'min_range':0,'max_range':300,'range_X':-1,'range_Y':-1,'attack_anim_speed':1.0,'charge_duration':1.0,'charge_speed':500.0,'target_calculation_timing':0,'target':0,'rand_target_size':-1,'only_positions_in_target_direction':False,'scale_charge_duration_with_range':False,'recovery_duration':0.05}

def module(name, file):
 spec = importlib.util.spec_from_file_location(name, ROOT/file)
 result = importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result

def generate():
 source = module('jungle_source', 'tools/character-source.py')
 scenes = module('jungle_scenes', 'tools/build-character-pets.py')
 images = module('jungle_images', 'tools/prepare-character-jungle-art.py')
 pck = source.Pck();reference = source.verify_reference(pck)
 cache = {};used_scripts = {'res://entities/entity.gdc','res://entities/units/unit/unit.gdc','res://entities/units/movement_behaviors/movement_behavior.gdc'}
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
  scale=node['properties'].get('scale',{}).get('values',[1,1]);assert scale[0]==scale[1] and scale[0]>0, 'Nonuniform native circle needs another geometry'
  return {'radiusPoints':shape['properties'].get('radius',10)*scale[0], 'offsetPoints':offset, 'source':path, 'sourceMd5':pck.entries[path]['md5']}
 enemies = {}
 for slug,(identity,type_id,name) in FAMILIES.items():
  folder = 'carnivorous_plant_mother' if slug=='carnivorus_plant_mother' else 'parasaurolus' if slug=='parasaurolorus' else slug
  path = f'res://entities/units/enemies/jungle/basic/{folder}/{slug}.tscn'
  nodes = resolve(path);root = nodes[('@','@')];move = nodes[('.','MovementBehavior')];attack = nodes[('.','AttackBehavior')]
  assert root['scriptSource'] == ('res://entities/units/enemies/crash_zone/basic/evil_mob/evil_mob.gd' if slug=='evil_mob_jungle' else 'res://entities/units/enemies/jungle/basic/oviraptor/oviraptor.gd' if slug in CROSSERS else 'res://entities/units/enemies/crash_zone/basic/looter/looter.gd' if slug=='harpymimus_looter' else 'res://entities/units/enemies/crash_zone/basic/pursuer/pursuer.gd' if slug=='velociraptor' else f'res://entities/units/enemies/jungle/basic/{folder}/{slug}.gd' if slug in ['baby_trex','dino_egg','stintaosaurus','ankylosaurus','pachycephalosaurus','pterosaur'] or slug in PLANTS else 'res://entities/units/enemies/enemy.gd')
  if slug in ['triceratops','parasaurolorus','ankylosaurus','pachycephalosaurus']:
   expected='target_rand_pos_movement_behavior.gd' if slug=='ankylosaurus' else 'follow_target_movement_behavior.gd'
   assert move['scriptSource']=='res://entities/units/movement_behaviors/'+expected
   if slug not in ['ankylosaurus','pachycephalosaurus']:assert move['properties']['should_target_vertically'] and not move['properties'].get('stop_close_to_target',False)
   assert attack['scriptSource']=='res://entities/units/movement_behaviors/detect_evolution_attack_behavior.gd'
   if slug=='pachycephalosaurus':assert not move['properties'].get('should_target_vertically',False) and not move['properties'].get('stop_close_to_target',False)
  elif slug in ['velociraptor','jeholopterus','giant_dragonfly']:
   assert move['scriptSource']=='res://entities/units/movement_behaviors/detect_target_movement_behavior.gd'
   expected_attack='res://entities/units/movement_behaviors/detect_evolution_attack_behavior.gd' if slug=='giant_dragonfly' else 'res://entities/units/enemies/attack_behaviors/'+('charging_attack_behavior.gd' if slug=='jeholopterus' else 'attack_behavior.gd')
   assert attack['scriptSource']==expected_attack
   before=nodes[('MovementBehavior','MovementBehaviorBeforeTargetDetection')]
   after=nodes[('MovementBehavior','MovementBehaviorAfterTargetDetection')]
   assert before['scriptSource']=='res://entities/units/movement_behaviors/'+({'jeholopterus':'follow_target_movement_behavior.gd','giant_dragonfly':'follow_rand_pos_around_player_movement_behavior.gd'}.get(slug,'target_rand_pos_around_player_movement_behavior.gd'))
   assert after['scriptSource']=='res://entities/units/movement_behaviors/'+('anticipate_target_movement_behavior.gd' if slug!='velociraptor' else 'follow_target_movement_behavior.gd')
   assert not after['properties'].get('should_target_vertically',False) and not after['properties'].get('stop_close_to_target',False)
   assert before['properties'].get('update_every_x_frames',-1)==-1
   for n in [before,after]:used_scripts.add(n['scriptSource'].removesuffix('.gd')+'.gdc')
  elif slug=='evil_mob_jungle':
   assert move['scriptSource']=='res://entities/units/movement_behaviors/target_rand_gold_pos_behavior.gd'
   assert attack['scriptSource']=='res://entities/units/enemies/attack_behaviors/attack_behavior.gd'
  elif slug=='pachyrhinosaurus':
   assert move['scriptSource']=='res://entities/units/movement_behaviors/follow_target_movement_behavior.gd'
   assert move['properties']['should_target_vertically'] and not move['properties'].get('stop_close_to_target',False)
   assert attack['scriptSource']=='res://entities/units/movement_behaviors/detect_evolution_attack_behavior.gd'
  elif slug=='dilophosaurus':
   assert move['scriptSource']=='res://entities/units/movement_behaviors/follow_target_movement_behavior.gd'
   assert attack['scriptSource']=='res://entities/units/movement_behaviors/detect_evolution_attack_behavior.gd'
   assert not move['properties'].get('should_target_vertically',False) and not move['properties'].get('stop_close_to_target',False)
  elif slug in ['hesperosaurus','stegosaurus']:
   assert move['scriptSource']=='res://entities/units/movement_behaviors/target_rand_pos_around_player_movement_behavior.gd'
   assert attack['scriptSource']=='res://entities/units/movement_behaviors/detect_evolution_attack_behavior.gd'
   assert move['properties']['update_every_x_frames']==-1
  elif slug=='pterosaur':
   assert move['scriptSource']=='res://entities/units/movement_behaviors/target_rand_pos_around_player_movement_behavior.gd'
   assert attack['scriptSource']=='res://entities/units/movement_behaviors/detect_evolution_attack_behavior.gd'
   assert move['properties']['update_every_x_frames']==-1
  elif slug in CROSSERS:
   assert move['scriptSource']=='res://entities/units/movement_behaviors/go_towards_border_opposite_movement_behavior.gd'
   assert attack['scriptSource']=='res://entities/units/enemies/attack_behaviors/attack_behavior.gd'
   assert root['properties']['collision_mask']==0 and not root['properties']['should_collide_with_borders']
  elif slug=='harpymimus_looter':
   assert move['scriptSource']=='res://entities/units/movement_behaviors/target_rand_pos_movement_behavior.gd'
   assert attack['scriptSource']=='res://entities/units/enemies/attack_behaviors/attack_behavior.gd'
  elif slug == 'enigmacursor' or slug in PLANTS:
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
  assert slug in PLANTS or (stats['armor'] == 0 and stats['armor_increase_each_wave'] == 0), 'Armor requires its own runtime policy'
  enemies[identity] = {'typeId':type_id,'displayName':name,'fallbackLook':'Shadeling','source':path,'sourceMd5':pck.entries[path]['md5'],'statsSource':stats_path,'statsMd5':pck.entries[stats_path]['md5'],'stats':stats,'body':circle(nodes[('.','Collision')]),'hurt':circle(nodes[('Hurtbox','Collision')]),'hit':circle(nodes[('Hitbox','Collision')]),'removeFirst':root['properties'].get('to_be_removed_in_priority',False),'mass':root['properties'].get('mass',1),'obstacleCollision':bool(root['properties']['collision_mask'] & 128)}
  enemies[identity]['sprite']=images.texture_metadata(pck,images.body_texture(pck,path))
  enemies[identity]['bodyLayer']=root['properties']['collision_layer']
  enemies[identity]['bodyMask']=root['properties']['collision_mask']
  enemies[identity]['bodyBorders']=root['properties'].get('should_collide_with_borders',True)
  enemies[identity]['playerCollision']=bool(root['properties']['collision_mask'] & 2)
  if slug=='evil_mob_jungle':
   raw=pck.read(path).decode('utf-8');prefix=raw.split('\n[node ')[0].replace('[gd_scene','[gd_resource type="PackedScene"',1)+'\n[resource]\n'
   block=raw.split('\n[node ',1)[1].split(']\n',1)[1].split('\n[node ',1)[0]
   props=source.parse_tres(prefix+block,path)['properties']
   assert props['quantity_to_evolve']==[0,10,20] and props['decrease_speed_by_evolve']==125
   assert props['is_loot'] and not props['can_be_boosted'] and not props['can_be_cursed']
   attract=circle(nodes[('ItemAttractArea','CollisionShape2D')]);pickup=circle(nodes[('ItemPickUpArea','CollisionShape2D')])
   stage_sprites=[images.texture_metadata(pck,t['resource']) for t in props['textures_evolution']]
   assert len(stage_sprites)==len(props['quantity_to_evolve'])
   enemies[identity].update(lootEncounter=True,isLoot=True,canBeBoosted=False,canBeCursed=False,nativeFixedSpeed=True,nativeDamageRounding=True,
    goldEater={'thresholds':props['quantity_to_evolve'],'speedDecreasePoints':props['decrease_speed_by_evolve'],'healthPerStage':0.5,'resistanceBase':0.5,'resistancePerStage':0.25,'dropSpreadPoints':{'perValue':25,'minimum':stats['gold_spread'],'maximum':200},'attractRadiusPoints':attract['radiusPoints'],'attractOffsetXPoints':attract['offsetPoints'][0],'attractOffsetZPoints':attract['offsetPoints'][1],'pickupRadiusPoints':pickup['radiusPoints'],'pickupOffsetXPoints':pickup['offsetPoints'][0],'pickupOffsetZPoints':pickup['offsetPoints'][1],'doubleChance':0},
    stageSprites=stage_sprites,speedBindingAudit='EvilMob.reset_speed_stat copies stats.speed directly; sampled offset, accessibility and percent modifiers are unused')
  if slug in PLANTS:
   assert stats['armor']==0 and stats['armor_increase_each_wave']==(0.25 if slug=='carnivorus_plant' else 0.5)
   assert stats['speed']==0 and stats['speed_randomization']==0 and stats['knockback_resistance']==1
   assert move['properties']['target_range']==9999 and move['properties']['target_range_randomization']==0
   assert 'became_full' not in pck.read(path).decode('utf-8') and '[connection' not in pck.read(path).decode('utf-8')
   enemies[identity].update(canBeBoosted=root['properties']['can_be_boosted'],nativeArmor={'base':stats['armor'],'perWave':stats['armor_increase_each_wave']},
    bindingAudit={'rootScript':root['scriptSource'],'rootScriptMd5':pck.entries[root['scriptSource'].removesuffix('.gd')+'.gdc']['md5'],'detectionZoneHasEatingConnection':False,'initialChildScale':nodes[('Hurtbox','Collision')]['properties'].get('scale',{}).get('values',[1,1])})
  if slug=='pterosaur':
   variants={}
   for variant in ['Normal','Meca','Mutant']:
    node=nodes[('AttackBehavior','AttackBehavior'+variant)]
    assert node['scriptSource']=='res://entities/units/enemies/attack_behaviors/charging_attack_behavior.gd'
    used_scripts.add(node['scriptSource'].removesuffix('.gd')+'.gdc')
    variants[variant]={**CHARGE_DEFAULTS,**{k:v for k,v in node['properties'].items() if isinstance(v,(int,float,bool))}}
   normal=variants['Normal']
   assert normal['target']==0 and normal['target_calculation_timing']==0 and normal['range_X']==-1 and normal['range_Y']==-1
   assert normal['long_cooldown_every_x_shoots']==3 and not normal['scale_charge_duration_with_range']
   enemies[identity].update(chargingVariants=variants,activeChargeVariant='Normal',directPlayerCharge=True,evolutionVariantsImplemented=False,
    wanderAroundTarget={'rangePoints':move['properties']['range_around_player'],'jitterPoints':move['properties']['range_randomization']},
    bindingAudit={'effectiveMovement':move['scriptSource'],'anticipationChildrenActive':False,'rootScript':root['scriptSource'],'rootScriptMd5':pck.entries[root['scriptSource'].removesuffix('.gd')+'.gdc']['md5'],'exportedProjectileChance':root['properties']['proj_chance'],'projectileChanceUsedByBoundOverride':False})
  if slug in CROSSERS:
   crossing=json.loads((ROOT/'docs/characters/crossing-paths-source.json').read_text(encoding='utf-8'))
   approved=crossing['families'][identity]
   assert crossing['version']==reference['version'] and approved['sourceMd5']==pck.entries[path]['md5']
   assert move['properties']['warning_time']==approved['warningSeconds'] and move['properties']['max_Y_diff']==approved['maxYDiff']
   assert nodes[('.','Collision')]['properties']['one_way_collision']
   enemies[identity].update(sourceOnly=False,actorRegistered=True,crossingPath={'warningSeconds':approved['warningSeconds'],'maxYDiff':approved['maxYDiff']},bodyOneWay=True,bodyOneWayMarginPoints=nodes[('.','Collision')]['properties'].get('one_way_collision_margin',1.0),collisionMask=0)
  if slug=='harpymimus_looter':
   assert root['properties']['is_loot'] and not root['properties']['can_be_cursed']
   assert stats['always_drop_consumables'] and stats['can_drop_consumables'] and stats['item_drop_chance']==1
   group_path='res://zones/zone_3_jungle/0000_all/group_2.tres';unit_path='res://zones/zone_3_jungle/0000_all/unit_2.tres'
   group=pck.resource(group_path)['properties'];unit=pck.resource(unit_path)['properties']
   assert group['is_loot'] and unit['unit_scene']['resource']==path
   enemies[identity].update(wanderArena=True,lootEncounter=True,isLoot=True,canBeCursed=False,
    spawnGroup={'source':group_path,'sourceMd5':pck.entries[group_path]['md5'],'unitSource':unit_path,'unitSourceMd5':pck.entries[unit_path]['md5'],
    'timing':group['spawn_timing'],'repeats':group['repeating'],'interval':group['repeating_interval'],'chance':unit['spawn_chance'],'areaConnected':False})
   used_scripts.add('res://main.gdc')
  if slug in ['jeholopterus','giant_dragonfly']:
   if slug=='giant_dragonfly':
    variants={}
    for variant in ['Normal','Meca','Mutant']:
     node=nodes[('AttackBehavior','AttackBehavior'+variant)]
     assert node['scriptSource']=='res://entities/units/enemies/attack_behaviors/charging_attack_behavior.gd'
     used_scripts.add(node['scriptSource'].removesuffix('.gd')+'.gdc')
     variants[variant]={**CHARGE_DEFAULTS,**{k:v for k,v in node['properties'].items() if isinstance(v,(int,float,bool))}}
    normal=variants['Normal']
   else:
    normal={**CHARGE_DEFAULTS,**{k:v for k,v in attack['properties'].items() if isinstance(v,(int,float,bool))}}
    variants={'Normal':normal}
   assert normal['target']==0 and normal['target_calculation_timing']==0 and normal['range_X']==-1 and normal['range_Y']==-1
   assert normal['long_cooldown_every_x_shoots']==(3 if slug=='giant_dragonfly' else 2) and not normal['scale_charge_duration_with_range']
   assert not before['properties'].get('stop_close_to_target',False)
   props=move['properties'];ap=after['properties']
   enemies[identity].update(chargingVariants=variants,activeChargeVariant='Normal',directPlayerCharge=True,evolutionVariantsImplemented=False,
    detection={'radiusPoints':props.get('detection_range',300),'speedBonusPoints':props.get('speed_bonus_on_target_detection',300),'anticipateAfter':{'seconds':ap.get('anticipation_time',0.3),'horizontalOnly':ap.get('should_target_vertically',False)}})
   if slug=='giant_dragonfly':
    bp=before['properties']
    enemies[identity]['detection'].update(wanderRangePoints=bp.get('range_around_player',200),wanderJitterPoints=bp.get('range_randomization',0),wanderMode='Offset',wanderWithin=bp.get('allow_within',True))
    raw=pck.read(path).decode('utf-8')
    special='res://entities/units/enemies/jungle/basic/giant_dragonfly/giant_dragonfly.gdc'
    assert root['scriptSource']=='res://entities/units/enemies/enemy.gd' and 'giant_dragonfly.gd' not in raw
    assert not any(line.startswith('[connection') and 'BoostTimer' in line for line in raw.splitlines())
    assert b'BoostTimer' not in pck.read('res://entities/units/enemies/enemy.gdc')
    assert nodes[('.','BoostTimer')]['properties']['autostart'] and not nodes[('.','BoostTimer')]['scriptSource']
    enemies[identity]['bindingAudit']={'effectiveScript':root['scriptSource'],'effectiveScriptMd5':pck.entries['res://entities/units/enemies/enemy.gdc']['md5'],'specialScriptBound':False,'unboundScript':special,'unboundScriptMd5':pck.entries[special]['md5'],'boostTimerConnected':False,'boostTimerAutostart':True}
  if slug in ['triceratops','parasaurolorus','ankylosaurus','pachycephalosaurus']:
   defaults=dict(CHARGE_DEFAULTS)
   if slug=='pachycephalosaurus':defaults['deflect_stop_before_CD']=20.0
   variants={}
   for variant in ['Normal','Mutant','Meca']:
    node=nodes[('AttackBehavior','AttackBehavior'+variant)]
    expected_attack='charging_attack_deflect_bullet_behavior.gd' if slug=='pachycephalosaurus' else 'charging_attack_behavior.gd'
    assert node['scriptSource']=='res://entities/units/enemies/attack_behaviors/'+expected_attack
    used_scripts.add(node['scriptSource'].removesuffix('.gd')+'.gdc')
    variants[variant]={**defaults,**{k:v for k,v in node['properties'].items() if isinstance(v,(int,float,bool))}}
   normal=variants['Normal'];assert normal['long_cooldown_every_x_shoots']==0 and normal['charge_duration']>0 and normal['recovery_duration']>0 and not normal['scale_charge_duration_with_range']
   enemies[identity].update(chargingVariants=variants,activeChargeVariant='Normal',evolutionVariantsImplemented=False)
   if slug=='ankylosaurus':
    targeting=json.loads((ROOT/'docs/characters/jungle-around-charge-source.json').read_text(encoding='utf-8'))
    assert targeting['version']==reference['version'] and targeting['variant']['sourceMd5']==pck.entries[path]['md5'] and targeting['variant']['effective']==normal
    assert root['properties']['_is_during_deflect_charge']==False
    enemies[identity].update(aroundPlayerCharge=True,wanderArena=True,nativeHurtSlowEffects=False,normalDeflectCharge=False)
   elif slug=='pachycephalosaurus':
    defense=json.loads((ROOT/'docs/characters/jungle-deflect-charge-source.json').read_text(encoding='utf-8'))
    assert defense['version']==reference['version'] and defense['sourceMd5']==pck.entries[path]['md5']
    assert variants==defense['variants']
    assert root['properties']['_is_during_deflect_charge']==False
    enemies[identity].update(normalDeflectCharge=True,nativeHurtSlowEffects=False)
   else:
    assert normal['target']==3 and normal['target_calculation_timing']==0 and normal['range_X']==-1 and normal['range_Y']>0
    enemies[identity]['followXShare']=0.5
   used_scripts.add('res://entities/units/enemies/attack_behaviors/charging_attack_behavior.gdc')
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
  if slug in ['baby_trex','velociraptor']:
   properties=root['properties']
   if slug=='baby_trex':
    alternate=nodes[('.','MovementBehaviorOnBoost')]
    assert alternate['scriptSource']==move['scriptSource'] and not alternate['properties'].get('stop_close_to_target',False)
    assert not properties['reset_nb_times_boosted_on_hit']
   else:
    assert properties['reset_nb_times_boosted_on_hit'] and properties['damage_on_boost']==0 and properties['size_on_boost']==0 and properties['change_movement_behavior_after_x_boosts']==-1
    props=move['properties'];bp=before['properties']
    enemies[identity]['detection']={'radiusPoints':props.get('detection_range',300),'speedBonusPoints':props.get('speed_bonus_on_target_detection',300),'wanderRangePoints':bp.get('range_around_player',300),'wanderJitterPoints':bp.get('range_randomization',100)}
   assert nodes[('.','BoostTimer')]['properties']['autostart']
   fields=['boost_cooldown','max_boosts','speed_on_boost','damage_on_boost','size_on_boost','change_movement_behavior_after_x_boosts','bonus_speed_on_change_movement_behavior','reset_nb_times_boosted_on_hit']
   if slug=='baby_trex':fields.append('max_player_speed_multiplier')
   enemies[identity]['pursuer']={k:properties[k] for k in fields}
   enemies[identity]['pursuer'].update(collisionScalingShare=0.25,spriteRisePoints=40)
   used_scripts.update(['res://entities/units/enemies/crash_zone/basic/pursuer/pursuer.gdc','res://entities/units/unit/unit.gdc','res://singletons/entity_service.gdc'])
  if slug in ['baby_pterosaur','graciliceratops']:
   enemies[identity]['anticipate'] = {'seconds':move['properties']['anticipation_time'],'horizontalOnly':move['properties'].get('should_target_vertically',False)}
  if slug in ['enigmacursor','hesperosaurus','stegosaurus','dilophosaurus','pachyrhinosaurus'] or slug in PLANTS:
   variants = {}
   for variant in ['Normal','Meca','Mutant']:
    node = nodes[('AttackBehavior','AttackBehavior'+variant)]
    assert node['scriptSource'] == 'res://entities/units/enemies/attack_behaviors/shooting_attack_behavior.gd'
    used_scripts.add(node['scriptSource'].removesuffix('.gd')+'.gdc')
    # Script defaults are explicit neutral facts; resource overrides remain authoritative.
    defaults = {'damage':1,'damage_increase_each_wave':1.0,'max_range':500,'min_range':0,'cooldown':60.0,'initial_cooldown':0,'max_cd_randomization':10,'attack_anim_speed':1.0,'number_projectiles':1,'projectile_spread':0.0,'constant_spread':False,'speed_change_after_each_projectile':0,'projectile_speed':3000}
    if slug!='enigmacursor':defaults.update(long_cooldown_every_x_shoots=0,long_cooldown=0,position={'variantType':'Vector2','values':[0,0]})
    values = {**defaults,**node['properties']}
    if slug in PLANTS:
     plant_raw=pck.read(path).decode('utf-8')
     prefix=plant_raw.split('\n[node ')[0].replace('[gd_scene','[gd_resource type="PackedScene"',1)+'\n[resource]\n'
     block=plant_raw.split('[node name="AttackBehavior'+variant+'"',1)[1].split('\n[node ',1)[0].split(']\n',1)[1]
     angles=source.parse_tres(prefix+block,path)['properties']['specific_degrees_spawns']
     assert len(angles)==values['number_projectiles'] and all(isinstance(v,(int,float)) for v in angles)
     values['specific_degrees_spawns']=angles
    variants[variant] = {k:v for k,v in values.items() if isinstance(v,(int,float,bool)) or k == 'position' or k=='specific_degrees_spawns'}
   raw = pck.read(path).decode('utf-8')
   prefix = raw.split('\n[node ')[0].replace('[gd_scene','[gd_resource type="PackedScene"',1)+'\n[resource]\n'
   external = {str(r['id']):r['path'] for r in source.parse_tres(prefix,path)['externalResources']}
   normal_block = raw.split('[node name="AttackBehaviorNormal"',1)[1].split('\n[node ',1)[0]
   projectile_ref = re.search(r'^projectile_scene = ExtResource\( (\d+) \)',normal_block,re.M)
   projectile_source = external[projectile_ref[1]] if projectile_ref else 'res://projectiles/bullet_enemy/enemy_projectile.tscn'
   assert projectile_source == ('res://projectiles/bullet_enemy/enemy_projectile.tscn' if slug in PLANTS else 'res://projectiles/slash/slash_projectile_2.tscn' if slug=='pachyrhinosaurus' else 'res://projectiles/pillar_enemy/pillar_projectile.tscn'), 'Different native projectile needs its own behavior'
   enemies[identity].update(movement=move['properties'],shootingVariants=variants,activeVariant='Normal',evolutionVariantsImplemented=False,projectileSource=projectile_source)
   if slug!='enigmacursor':
    assert 'anims/shoot' not in raw
    projectile_variants={}
    for variant in ['Normal','Mutant','Meca']:
     block=raw.split('[node name="AttackBehavior'+variant+'"',1)[1].split('\n[node ',1)[0]
     ref=re.search(r'^projectile_scene = ExtResource\( (\d+) \)',block,re.M)
     assert ref or slug in PLANTS
     proj=external[ref[1]] if ref else 'res://projectiles/bullet_enemy/enemy_projectile.tscn'
     projectile_variants[variant]={'source':proj,'sourceMd5':pck.entries[proj]['md5']}
    assert projectile_variants['Normal']['source']==projectile_source
    assert projectile_variants['Meca']['source']==('res://projectiles/laser_enemy/enemy_laser.tscn' if slug in PLANTS else 'res://projectiles/slash/slash_projectile_2.tscn')
    assert projectile_variants['Mutant']['source']=='res://projectiles/acid_projectile/acid_projectile.tscn'
    enemies[identity].update(genericShootAnimation=True,projectileVariants=projectile_variants)
    if slug in PLANTS:
     assert variants['Normal']['use_specific_angle'] and variants['Normal']['use_transform_offset']
     assert not variants['Normal']['constant_spread']
     resolve(projectile_source);bullet=cache[projectile_source]
     collision=next(n for n in bullet['nodes'] if n['parent']=='Hitbox' and n['name']=='Collision')
     enemies[identity].update(bulletProjectile=True,nativeDamageRounding=True,projectileRadiusPoints=circle(collision)['radiusPoints'])
     used_scripts.add('res://projectiles/bullet_enemy/enemy_projectile.gdc')
    elif slug=='pachyrhinosaurus':
     assert variants['Normal']['parallel_slashes'] and variants['Normal']['parallel_spacing']==60
     assert variants['Normal']['constant_spread'] and not variants['Normal'].get('use_transform_offset',False)
     assert not variants['Normal'].get('delete_projectile_on_death',False)
     enemies[identity].update(forwardSlashProjectile=True,followTargetShoot=True,followXShare=0.5,nativeDamageRounding=True)
    elif slug=='dilophosaurus':
     assert variants['Normal']['scale_projectiles_with_count'] and variants['Normal']['min_projectile_scale']==0.7
     assert not variants['Normal'].get('parallel_slashes',False) and variants['Normal']['use_transform_offset']
     enemies[identity]['followTargetShoot']=True
    else:
     enemies[identity]['wanderAroundTarget']={'rangePoints':move['properties']['range_around_player'],'jitterPoints':move['properties']['range_randomization']}

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
 forward_path='res://projectiles/slash/slash_projectile_2.tscn'
 forward_raw=pck.read(forward_path).decode('utf-8')
 resource=source.parse_tres(forward_raw.split('\n[node ')[0].replace('[gd_scene','[gd_resource type="PackedScene"',1)+'\n[resource]\n',forward_path)
 anim=next(r['properties'] for r in resource['subresources'].values() if r['resourceType']=='Animation' and r['properties'].get('resource_name')=='shoot')
 def track(animation,path):return next(animation[k.replace('/path','/keys')] for k,v in animation.items() if k.endswith('/path') and v.get('values')==[path])
 pos=track(anim,'Hitbox/Collision:position');ext=track(anim,'Hitbox/Collision:shape:extents')
 reset=next(r['properties'] for r in resource['subresources'].values() if r['resourceType']=='Animation' and r['properties'].get('resource_name')=='RESET')
 methods=next(anim[k.replace('/type','/keys')] for k,v in anim.items() if k.endswith('/type') and v=='method')
 times={v['method']:t for t,v in zip(methods['times'],methods['values']) if t>0}
 fscene=scenes.read_scene(pck,forward_path)
 parent=next(n['properties']['position']['values'] for n in fscene['nodes'] if n['name']=='Hitbox' and n['parent']=='.')
 forward={'source':forward_path,'sourceMd5':pck.entries[forward_path]['md5'],'hitFrom':times['enable_hitbox'],'hitUntil':times['disable_hitbox'],'stopAt':times['stop'],'times':pos['times'],'positions':[v['values'] for v in pos['values']],'extents':[v['values'] for v in ext['values']],'hitboxOffset':parent,'resetPosition':track(reset,'Hitbox/Collision:position')['values'][0]['values'],'resetExtents':track(reset,'Hitbox/Collision:shape:extents')['values'][0]['values']}
 assert parent==[165,-15]
 spawn_animations=[]
 for anim_path in ['res://entities/units/enemies/attack_behaviors/shoot.tres','res://entities/units/enemies/attack_behaviors/shoot_charmed.tres']:
  props=pck.resource(anim_path)['properties']
  track=next(v for k,v in props.items() if k.endswith('/keys') and isinstance(v,dict) and any(isinstance(value,dict) and value.get('method')=='shoot' for value in v.get('values',[])))
  fire=next(t for t,v in zip(track['times'],track['values']) if v['method']=='shoot')
  spawn_animations.append({'source':anim_path,'sourceMd5':pck.entries[anim_path]['md5'],'fireAt':fire,'seconds':props.get('length',1)})
 assert spawn_animations[0]['fireAt']==spawn_animations[1]['fireAt'] and spawn_animations[0]['seconds']==spawn_animations[1]['seconds']
 zone = 'res://zones/zone_3_jungle/zone_jungle_data.tres'
 return {'version':reference['version'],'steamBuild':int(reference['steamBuildId']),'zoneId':pck.resource(zone)['properties']['my_id'],'zoneSource':zone,'zoneSourceMd5':pck.entries[zone]['md5'],'zonePlayable':False,'implemented':list(enemies),'sourceOnly':[],'enemies':enemies,'spawningRules':{'animations':spawn_animations,'frameRate':60,'minimumCooldownFrames':1,'goalPrecisionPoints':10,'chargeMassMultiplier':5},'shootingRules':{'frameRate':60,'minimumCooldownFrames':1,'animationFireAt':fire_at,'animationSeconds':animation.get('length',1),'animationSource':animation_path,'animationSourceMd5':pck.entries[animation_path]['md5'],'pillar':pillar,'forwardSlash':forward,'projectileRadiusPoints':pillar['radiusPoints'],'projectileRangeStuds':300,'projectileRangeNote':'Existing engine lifetime/area compatibility limit, not a native range stat'},'ruleSources':[{'source':path,'sourceMd5':pck.entries[path]['md5']} for path in sorted(used_scripts)],'runtimeCompatibility':{'mass':1,'nativeArtAccepted':False,'physicsAccepted':False,'open':['Existing global body/collision center approximation; source offsets retained explicitly','Native physics ordering and sprite acceptance','Spawning reuses existing square/edge clamp; native forbidden-zone retries/push-out remain part of the pending area/physics port','Enigmacursor Meca/Mutant branches are source facts only; no native evolution-system acceptance','Fallback circle telegraphs instead of original animated pillar sprites','Remaining Jungle families, waves, bosses and area route']}}

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
