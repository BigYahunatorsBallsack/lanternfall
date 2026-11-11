"""Read only the six required stable native pet families into neutral, source-hashed facts.
No scripts or full scenes are copied; these facts alone do not implement pets.
"""
from __future__ import annotations
import argparse, csv, importlib.util, json, math, re, sys
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('pet_character_source',ROOT/'tools/character-source.py')
source=importlib.util.module_from_spec(spec);spec.loader.exec_module(source)
FAMILIES=['bonk_dog','catling_gun','blazemander','bot_o_mine','lootworm','ratzilla']
VISUAL={'texture','sprite_frames','frames','material','curse_particles','sound_attack','shooting_sounds','icon','item_appearances','sound','script','animation','shooting_sounds','sound_db_mod'}
def facts(props):
 return {k:v for k,v in props.items() if k not in VISUAL and (isinstance(v,(int,float,bool)) or k in ['scaling_stats','stats','movement_behavior','target_behavior','weapon_stats','ranged_weapon_stats','burning_data','explosion_effect','landmine_effect_stat','scene','double_chance','max_nb','tags','custom_args','effects'])}
def read_scene(pck,path):
 raw=pck.read(path).decode('utf-8');starts=list(re.finditer(r'^\[node .*\]\s*$',raw,re.M));assert starts,path
 prefix=raw[:starts[0].start()].replace('[gd_scene','[gd_resource type="PackedScene"',1)
 nodes=[]
 for i,match in enumerate(starts):
  attrs=dict(re.findall(r'(name|parent|type)="([^"]*)"',match.group()))
  text=raw[match.end():starts[i+1].start() if i+1<len(starts) else len(raw)]
  text=re.split(r'^\[connection ',text,flags=re.M)[0]
  parsed=source.parse_tres(prefix+'\n[resource]\n'+text,path)
  values={k:v for k,v in parsed['properties'].items() if k not in VISUAL and (isinstance(v,(int,float,bool)) or k in ['stats','shape','position','scale','size','pet_id','target_behavior','movement_behavior','charge_duration','min_squared_distance_for_jump_attack','weapon_stats','tree_damage_ratio'])}
  if values or 'script' in parsed['properties']:
   nodes.append({'name':attrs.get('name'),'parent':attrs.get('parent'),'type':attrs.get('type'),'scriptSource':parsed['properties'].get('script',{}).get('resource'),'properties':values})
 parsed=source.parse_tres(prefix+'\n[resource]\n',path)
 shapes={k:v for k,v in parsed['subresources'].items() if 'Shape' in v['resourceType']}
 root_instance=re.search(r'instance=ExtResource\(\s*(\d+)\s*\)',starts[0].group())
 base=next((v['path'] for v in parsed['externalResources'] if root_instance and str(v['id'])==root_instance[1]),None)
 return {'sourceMd5':pck.entries[path]['md5'],'baseScene':base,'nodes':nodes,'shapes':shapes}
def generate(pck):
 rows=[];resources={};scenes={}
 for slug in FAMILIES:
  path=f'res://items/all/03_paws_n_claws/{slug}/{slug}.tres'
  item=pck.resource(path)['properties'];effect_path=item['effects'][0]['resource'];effect=pck.resource(effect_path)['properties'];scene=effect['scene']['resource']
  row={'slug':slug,'id':''.join(w.title() for w in slug.split('_')),'source':path,'sourceMd5':pck.entries[path]['md5'],'nameKey':item['name'],'tier':item['tier']+1,'price':item['value'],'limit':item['max_nb'],'tags':item.get('tags',[]),'iconSource':item['icon']['resource'],'effectSource':effect_path,'effectMd5':pck.entries[effect_path]['md5'],'effect':facts(effect)}
  scenes[scene]=read_scene(pck,scene)
  pending=[ref['resource'] for ref in source.references(effect) if ref['resource'].endswith('.tres') and '::' not in ref['resource']]
  for node in scenes[scene]['nodes']:
   pending.extend(ref['resource'] for ref in source.references(node['properties']) if ref['resource'].endswith('.tres') and '::' not in ref['resource'])
  seen=set()
  while pending:
   ref=pending.pop()
   if ref in seen:continue
   seen.add(ref);data=pck.resource(ref)['properties'];resources[ref]={'sourceMd5':pck.entries[ref]['md5'],'properties':facts(data)}
   pending.extend(r['resource'] for r in source.references(data) if r['resource'].endswith('.tres') and '::' not in r['resource'])
  rows.append(row)
 for ref in ['res://projectiles/bullet/bullet_projectile.tscn','res://projectiles/flames/flame_projectile.tscn','res://overlap/hitbox.tscn','res://items/materials/gold.tscn']:
  scenes[ref]=read_scene(pck,ref)
 pending=[v['baseScene'] for v in scenes.values() if v.get('baseScene')]
 while pending:
  ref=pending.pop()
  if ref in scenes:continue
  scenes[ref]=read_scene(pck,ref)
  if scenes[ref].get('baseScene'):pending.append(scenes[ref]['baseScene'])
 rule_sources=[]
 scripts={n['scriptSource'] for scene in scenes.values() for n in scene['nodes'] if n.get('scriptSource')}
 scripts.update(['res://singletons/weapon_service.gd','res://singletons/utils.gd','res://global/pet_service.gd','res://global/entity_spawner.gd','res://singletons/zone_service.gd','res://entities/units/enemies/bosses/boss.gd'])
 for script in sorted(scripts):
  path=next((candidate for candidate in [script,script.removesuffix('.gd')+'.gdc'] if candidate in pck.entries),None)
  if path:rule_sources.append({'source':path,'sourceMd5':pck.entries[path]['md5']})
 player_scene=read_scene(pck,'res://entities/units/player/player.tscn');body=next(n['properties'] for n in player_scene['nodes'] if n['name']=='Collision' and n['parent']=='.');shape=body['shape']['resource'].split('::')[1]
 player_body={'source':'res://entities/units/player/player.tscn','sourceMd5':player_scene['sourceMd5'],'radiusPoints':player_scene['shapes'][shape]['properties']['radius'],'offsetXPoints':body['position']['values'][0],'offsetZPoints':body['position']['values'][1]}
 return {'version':'1.2.0.1','steamBuild':26406319,'pets':rows,'resources':resources,'scenes':scenes,'ruleSources':rule_sources,'playerBody':player_body,'engineDefaults':{'circleRadiusPoints':10,'circleReference':'https://docs.godotengine.org/en/3.5/classes/class_circleshape2d.html','bonkTweenTransition':5,'bonkTweenEase':2,'tweenReference':'https://docs.godotengine.org/en/3.5/classes/class_tween.html','tweenEquationReference':'https://github.com/godotengine/godot/blob/3.5/scene/animation/easing_equations.h'},'note':'Neutral pet facts, not a claim of implemented behavior or available original artwork.'}
STAT_IDS={'stat_melee_damage':'meleeDamage','stat_ranged_damage':'rangedDamage','stat_elemental_damage':'elementalDamage','stat_engineering':'engineering','stat_max_hp':'maxHp'}

def weapon(data, structure=False, ranged=False, exploding=False):
 result={'damage':data['damage'],'cooldownFrames':data['cooldown'],'critChance':data['crit_chance'],'critDamage':data['crit_damage'],'lifeSteal':data['lifesteal'],'rangePoints':data['max_range'],'minRangePoints':data['min_range'],'knockbackPoints':data['knockback'],'positiveKnockback':data['can_have_positive_knockback'],'negativeKnockback':data['can_have_negative_knockback'],'isStructure':structure,'isRanged':ranged,'exploding':exploding,'scaling':[[STAT_IDS[k],v] for k,v in data['scaling_stats']]}
 if ranged:
  result.update({'projectileSpeedPoints':data['projectile_speed'],'nativeAccuracy':data['accuracy'],'nativeSpread':data['projectile_spread'],'count':data['nb_projectiles'],'pierce':data['piercing'],'pierceFalloff':data['piercing_dmg_reduction'],'bounce':data['bounce'],'bounceFalloff':data['bounce_dmg_reduction'],'canBounce':data['can_bounce']})
 return result

def catalog(out):
 resources=out['resources'];kinds={}
 def props(ref):return resources[ref['resource']]['properties']
 def inherited_nodes(path):
  scene=out['scenes'][path];nodes=inherited_nodes(scene['baseScene']) if scene.get('baseScene') else {}
  for n in scene['nodes']:
   key=(n['name'],n['parent']);nodes[key]={**nodes.get(key,{}),**n['properties']}
  return nodes
 def radius(properties):
  path,sub=properties['shape']['resource'].split('::');return out['scenes'][path]['shapes'][sub]['properties'].get('radius',10)
 for row in out['pets']:
  effect=row['effect'];slug=row['slug'];structure=effect['is_structure'];ranged=slug in ['catling_gun','bot_o_mine']
  speed=next(n['properties']['stats'] for n in out['scenes'][effect['scene']['resource']]['nodes'] if 'stats' in n['properties'])
  weapon_ref=effect.get('weapon_stats') or next(n['properties']['weapon_stats'] for n in out['scenes'][effect['scene']['resource']]['nodes'] if 'weapon_stats' in n['properties'])
  pet={'speedPoints':props(speed)['speed'],'isStructure':structure,'weapon':weapon(props(weapon_ref),structure,ranged)}
  if slug=='lootworm':
   nodes=inherited_nodes(effect['scene']['resource']);body=nodes['Collision','.'];hit=nodes['Hitbox','.'];sensor=nodes['TreeArea2D','.'];attract=nodes['CollisionShape2D','ItemAttractArea'];pickup=nodes['CollisionShape2D','ItemPickUpArea']
   pet.update({'lootworm':True,'doubleChance':effect['double_chance'],'treeDamageRatio':nodes[next(key for key in nodes if key[1] is None and 'tree_damage_ratio' in nodes[key])]['tree_damage_ratio'] if any(key[1] is None and 'tree_damage_ratio' in nodes[key] for key in nodes) else 5,'bodyRadiusPoints':radius(body),'bodyOffsetXPoints':body['position']['values'][0],'bodyOffsetZPoints':body['position']['values'][1],'hitRadiusPoints':radius(nodes['Collision','Hitbox']),'hitOffsetXPoints':hit['position']['values'][0],'hitOffsetZPoints':hit['position']['values'][1],'treeRadiusPoints':radius(nodes['CollisionShape2D','TreeArea2D']),'treeOffsetXPoints':sensor['position']['values'][0],'treeOffsetZPoints':sensor['position']['values'][1],'attractRadiusPoints':radius(attract)*attract['scale']['values'][0],'pickupRadiusPoints':radius(pickup)*pickup['scale']['values'][0],'pickupOffsetXPoints':pickup['position']['values'][0],'pickupOffsetZPoints':pickup['position']['values'][1]})
  if slug=='catling_gun':
   nodes=inherited_nodes(effect['scene']['resource']);body=nodes['Collision','.'];viewport=nodes['Viewport','Animation']['size']['values']
   ax,az=nodes['Animation','.']['position']['values'];vx,vz=nodes['offset','Animation/Viewport']['position']['values'];bx,bz=nodes['sp_body','Animation/Viewport/offset']['position']['values']
   rigs={}
   for side in ['Left','Right']:
    pivot_name='Gun_pivot_'+('l' if side=='Left' else 'r');pivot=nodes[pivot_name,'Animation/Viewport/offset/sp_body'];parent='Animation/Viewport/offset/sp_body/'+pivot_name
    a,b,c,d,x,z=1,0,0,1,0,0
    for name in ['gun_offset','sp_gun',side+'Muzzle']:
     n=nodes[name,parent];px,pz=n.get('position',{}).get('values',[0,0]);sx,sz=n.get('scale',{}).get('values',[1,1]);angle=n.get('rotation',0);co,si=math.cos(angle),math.sin(angle)
     x,z=x+a*px+c*pz,z+b*px+d*pz
     a,b,c,d=(a*co+c*si)*sx,(b*co+d*si)*sx,(-a*si+c*co)*sz,(-b*si+d*co)*sz
     parent+='/'+name
    rigs[side.lower()]={'pivotXPoints':pivot['position']['values'][0],'pivotZPoints':pivot['position']['values'][1],'restRotation':pivot.get('rotation',0),'muzzleXPoints':x,'muzzleZPoints':z}
   pet.update({'catling':True,'bodyRadiusPoints':radius(body),'bodyOffsetXPoints':body['position']['values'][0],'bodyOffsetZPoints':body['position']['values'][1],'boostRadiusPoints':radius(nodes['CollisionShape2D','PlayerTriggerZone']),'targetRadiusPoints':radius(nodes['CollisionShape2D','TargetTriggerZone']),'boostAttackRatio':0.5,'muzzleOriginXPoints':ax+vx+bx-100,'muzzleOriginZPoints':az+vz+bz-100,'bodyRotation':nodes['sp_body','Animation/Viewport/offset'].get('rotation',0),'guns':rigs,'wander':{'marginXPoints':viewport[0]/2,'marginZPoints':viewport[1]/2,'arrivalPoints':10,'tries':8,'forbiddenPushPoints':8,'zeroSquaredPoints':0.001}})
  if 'explosion_effect' in effect:pet['explosion']=weapon(props(props(effect['explosion_effect'])['stats']),exploding=True)
  if 'ranged_weapon_stats' in effect:pet['ranged']=weapon(props(effect['ranged_weapon_stats']),ranged=True)
  if 'landmine_effect_stat' in effect:pet['mine']=weapon(props(props(effect['landmine_effect_stat'])['stats']),structure=True,exploding=True)
  if slug=='bot_o_mine':
   nodes=inherited_nodes(effect['scene']['resource'])
   body=nodes['Collision','.'];shape_path,sub=body['shape']['resource'].split('::')
   pet.update({'followOwner':True,'bodyRadiusPoints':out['scenes'][shape_path]['shapes'][sub]['properties']['radius'],'bodyOffsetXPoints':body['position']['values'][0],'bodyOffsetZPoints':body['position']['values'][1],'stopDistancePoints':nodes['MovementBehavior','.']['distance_to_target'],'mineIntervalFrames':props(effect['landmine_effect_stat'])['spawn_cooldown'],'mineAreaPoints':100})
   muzzle=next(n for n in out['scenes'][effect['scene']['resource']]['nodes'] if n['name']=='Muzzle')
   parts=muzzle['parent'].split('/')[2:]+['Muzzle'];parent='Animation/Viewport';a,b,c,d,x,y=1,0,0,1,0,0
   for name in parts:
    n=nodes.get((name,parent),{});px,py=n.get('position',{}).get('values',[0,0]);sx,sy=n.get('scale',{}).get('values',[1,1]);angle=n.get('rotation',0);co,si=math.cos(angle),math.sin(angle)
    x,y=x+a*px+c*py,y+b*px+d*py
    a,b,c,d=(a*co+c*si)*sx,(b*co+d*si)*sx,(-a*si+c*co)*sy,(-b*si+d*co)*sy
    parent+='/'+name
   ax,ay=nodes['Animation','.']['position']['values']
   pet.update({'muzzleXPoints':ax+x-100,'muzzleZPoints':ay+y-100})
  if slug in ['ratzilla','bonk_dog','blazemander']:
   scene=out['scenes'][effect['scene']['resource']]
   nodes=inherited_nodes(effect['scene']['resource'])
   def node(name,parent):return nodes.get((name,parent),{})
   body=node('Collision','.');hit=node('Collision','Hitbox');target=node('TargetBehavior','.')
   hit_pos=node('Hitbox','.').get('position',{}).get('values',[0,0]);hit_collision_pos=hit.get('position',{}).get('values',[0,0])
   pet.update({'bodyRadiusPoints':radius(body),'bodyOffsetXPoints':body['position']['values'][0],'bodyOffsetZPoints':body['position']['values'][1],'hitRadiusPoints':radius(hit),'hitOffsetXPoints':hit_pos[0]+hit_collision_pos[0],'hitOffsetZPoints':hit_pos[1]+hit_collision_pos[1],'targetRadiusPoints':radius(next(v for (name,parent),v in nodes.items() if parent=='TargetBehavior/Range' and 'shape' in v)),'targetFamily':target.get('pet_id',''),'excludeBosses':target.get('exclude_elite_and_boss_target',False)})
   if slug=='blazemander':
    detect=node('Enemy_detection','.');offset=detect.get('position',{}).get('values',[0,0]);b=props(effect['burning_data'])
    burn={'damage':b['damage'],'ticks':b['duration'],'chance':b['chance'],'spread':b['spread'],'scaling':[[STAT_IDS[k],v] for k,v in b['scaling_stats']]}
    pet.update({'preferUnburned':True,'globalFallback':False,'shareEliteOnly':True,'detectionRadiusPoints':radius(node('Collision','Enemy_detection')),'detectionOffsetXPoints':offset[0],'detectionOffsetZPoints':offset[1],'meleeDelaySeconds':0.15,'rangedInitialMinimumShare':0.25,'rays':6})
    pet['weapon']['burning']=burn;pet['ranged']['burning']=burn;pet['ranged']['radial']=True
    flame=inherited_nodes('res://projectiles/flames/flame_projectile.tscn');fc=flame['Collision','Hitbox'];fh=flame['Hitbox','.'].get('position',{}).get('values',[0,0]);cp=fc.get('position',{}).get('values',[0,0])
    pet['ranged']['projectile']={'radiusPoints':radius(fc),'offsetForwardPoints':fh[0]+cp[0],'offsetSidePoints':fh[1]+cp[1]}
   if slug=='bonk_dog':
    root=scene['nodes'][0]['properties'];effect_explosion=props(effect['explosion_effect']);geometry=json.loads((ROOT/'docs/characters/structure-source.json').read_text())['geometry']
    pet.update({'jumpSeconds':root['charge_duration'],'jumpMinimumSquaredPoints':root['min_squared_distance_for_jump_attack'],'jumpInitialMinimumShare':0.25,'jumpRetryShare':0.4,'explosionScale':effect_explosion['scale'],'explosionRadiusPoints':geometry['explosionRadiusPoints']})
  kinds[row['id']]=pet
 bullet=inherited_nodes('res://projectiles/bullet/bullet_projectile.tscn');hit=bullet['Hitbox','.'];collision=bullet['Collision','Hitbox'];shape_path,sub=collision['shape']['resource'].split('::');hx,hz=hit['position']['values'];cx,cz=collision['position']['values']
 projectile={'radiusPoints':out['scenes'][shape_path]['shapes'][sub]['properties']['radius'],'offsetForwardPoints':hx+cx,'offsetSidePoints':hz+cz,'autoRangeBonusPoints':100}
 gold=inherited_nodes('res://items/materials/gold.tscn');shape=gold['CollisionShape2D','.']['shape']['resource'];path,sub=shape.split('::');extents=out['scenes'][path]['shapes'][sub]['properties']['extents']['values']
 material={'halfXPoints':extents[0],'halfZPoints':extents[1],'attractSpeedPoints':500,'accelerationPointsPerFrame':20,'idleFrames':10,'mergeGrowth':0.05,'maximumScale':2,'bagScale':1.25}
 data={'frameRate':60,'minimumCooldownFrames':2,'minimumRangePoints':25,'projectile':projectile,'material':material,'playerBody':{k:v for k,v in out['playerBody'].items() if k.endswith('Points')},'beastMasterStats':['meleeDamage','rangedDamage','elementalDamage','engineering'],'kinds':kinds}
 def lua(value,depth=0):
  if isinstance(value,bool):return 'true' if value else 'false'
  if isinstance(value,(int,float)):return str(value)
  if isinstance(value,str):return json.dumps(value)
  lines=[]
  for key,val in (value.items() if isinstance(value,dict) else enumerate(value)):
   prefix=f'{key} = ' if isinstance(value,dict) else ''
   lines.append('\t'*(depth+1)+prefix+lua(val,depth+1)+',')
  return '{\n'+'\n'.join(lines)+'\n'+'\t'*depth+'}'
 return '--!strict\n-- Generated original pet weapon definitions; consumed by StructureService/PetRules. Regenerate with tools/build-character-pets.py.\nreturn '+lua(data)+'\n'

def main():
 a=argparse.ArgumentParser();a.add_argument('--pck',type=Path,default=source.DEFAULT_PCK);a.add_argument('--output',type=Path,default=ROOT/'docs/characters/pet-source.json');a.add_argument('--check',action='store_true');args=a.parse_args();out=generate(source.Pck(args.pck))
 files={args.output:json.dumps(out,indent=2,ensure_ascii=False)+'\n',ROOT/'src/shared/Config/Pets.luau':catalog(out)}
 import subprocess
 import tempfile
 for path,text in files.items():
  if path.suffix=='.luau':
   with tempfile.TemporaryDirectory(dir=ROOT/'build') as temp:
    candidate=Path(temp)/path.name;candidate.write_text(text,encoding='utf-8');subprocess.run(['stylua',str(candidate)],check=True);text=candidate.read_text(encoding='utf-8')
  if args.check:
   assert path.read_text(encoding='utf-8')==text,f'Stale generated pet data: {path}'
  else:
   path.parent.mkdir(parents=True,exist_ok=True);path.write_text(text,encoding='utf-8',newline='\n')
 print(len(out['pets']),'pet families,',len(out['resources']),'resources,',len(out['scenes']),'scenes inspected; generated config checked' if args.check else 'scenes inspected; generated config written')
if __name__=='__main__':main()
