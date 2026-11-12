"""Read seven original Nightmare enemy identities; compile only the explicitly implemented behavior families."""
import argparse, importlib.util, json, re, subprocess, sys, tempfile
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
def module(name,path):
 spec=importlib.util.spec_from_file_location(name,path);result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
 source=module('nightmare_enemy_source',ROOT/'tools/character-source.py');compiler=module('nightmare_enemy_catalog',ROOT/'tools/build-character-catalog.py');scenes=module('nightmare_enemy_scenes',ROOT/'tools/build-character-bullet-hell.py');pck=source.Pck(source.DEFAULT_PCK)
 rows={}
 names={'bloated_spawner':'BloatedSpawner','dire_junkie':'DireJunkie','horned_fly':'HornedFly','horned_spitter':'HornedSpitter','corrupted_buffer':'CorruptedBuffer','infected_slasher_egg':'InfectedSlasherEgg','mad_slasher':'MadSlasher'}
 for native,identity in names.items():
  path=f'res://entities/units/enemies/crash_zone/basic/{native}/{native}.tscn';stat_path=path.replace('.tscn','_stats.tres');refs,nodes=scenes.scene(pck,path)
  def props(node):
   values={}
   for key,value in node['properties'].items():
    if value.startswith('ExtResource') or value.startswith('SubResource'):continue
    try: parsed=source.ValueParser(value).parse()
    except ValueError:continue
    if isinstance(parsed,(int,float,bool,str)): values[key]=parsed
   return values
  text=pck.read(path).decode('utf-8')
  circles={}
  for shape,body in re.findall(r'\[sub_resource type="CircleShape2D" id=(\d+)\]\n(.*?)(?=\n\[|\Z)',text,re.S):
   radius=re.search(r'^radius = ([0-9.]+)',body,re.M);circles[shape]=float(radius[1]) if radius else 10
  geometry={'body':40,'hurt':32,'hit':16.0312}
  # Match each local collision override with its explicit parent, retaining inherited circles when absent.
  for header,body in re.findall(r'(\[node [^\n]+\])\n(.*?)(?=\n\[|\Z)',text,re.S):
   if 'name="Collision"' not in header and 'name="BoostCollision"' not in header:continue
   match=re.search(r'shape = SubResource\( (\d+) \)',body)
   if not match:continue
   key='boost' if 'name="BoostCollision"' in header else 'hurt' if 'parent="Hurtbox"' in header else 'hit' if 'parent="Hitbox"' in header else 'body'
   geometry[key]=circles[match[1]]
  stats={k:v for k,v in pck.resource(stat_path)['properties'].items() if isinstance(v,(int,float,bool))}
  movements=next((props(n) for n in nodes if n['name']=='MovementBehavior'),{})
  attack=next((props(n) for n in nodes if n['name']=='AttackBehavior'),{})
  rows[identity]={'nativeId':native,'source':path,'sourceMd5':pck.entries[path]['md5'],'statsSource':stat_path,'statsMd5':pck.entries[stat_path]['md5'],'stats':stats,'circles':geometry,'root':props(nodes[0]),'movement':movements,'attack':attack,'boostTimer':next((props(n) for n in nodes if n['name']=='BoostTimer'),{})}
 common=['res://entities/units/enemies/enemy.tscn','res://entities/units/enemies/enemy.gdc','res://entities/units/enemies/attack_behaviors/shoot.tres','res://entities/units/enemies/attack_behaviors/shooting_attack_behavior.gdc','res://entities/units/enemies/crash_zone/basic/bloated_spawner/bloated_spawner.gdc','res://entities/units/enemies/crash_zone/basic/horned_fly/horned_fly.gdc','res://entities/units/enemies/crash_zone/basic/corrupted_buffer/corrupted_buffer.gdc','res://entities/units/player/player.tscn','res://entities/units/enemies/crash_zone/basic/infected_slasher_egg/infected_slasher_egg.gdc','res://entities/units/enemies/attack_behaviors/spawning_attack_behavior.gdc','res://entities/units/unit/unit.gdc','res://entities/units/unit/stats.gdc','res://singletons/entity_service.gdc']
 animation=pck.resource(common[2])['properties']
 timing={'fireAt':next(animation[k]['times'][i] for k in animation if k.endswith('/keys') and isinstance(animation[k],dict) and 'values' in animation[k] for i,v in enumerate(animation[k]['values']) if isinstance(v,dict) and v.get('method')=='shoot'),'duration':animation.get('length',1)}
 _,player_nodes=scenes.scene(pck,'res://entities/units/player/player.tscn')
 boost_duration=float(next(n['properties']['wait_time'] for n in player_nodes if n['name']=='BoostTimer'))
 slash_path='res://projectiles/slash/slash_projectile.tscn'
 slash_text=pck.read(slash_path).decode('utf-8')
 slash_resource=source.parse_tres(slash_text.split('\n[node ')[0].replace('[gd_scene','[gd_resource type="PackedScene"',1)+'\n[resource]\n',slash_path)
 animation=next(r['properties'] for r in slash_resource['subresources'].values() if r['resourceType']=='Animation' and r['properties'].get('resource_name')=='shoot')
 def track(path):
  return next(animation[k.replace('/path','/keys')] for k,v in animation.items() if k.endswith('/path') and v.get('values')==[path])
 position=track('Hitbox/Collision:position');extents=track('Hitbox/Collision:shape:extents')
 methods=next(animation[k.replace('/type','/keys')] for k,v in animation.items() if k.endswith('/type') and v=='method')
 method_times={value['method']:time for time,value in zip(methods['times'],methods['values'])}
 _,slash_nodes=scenes.scene(pck,slash_path)
 hitbox_offset=source.ValueParser(next(n['properties']['position'] for n in slash_nodes if n['name']=='Hitbox')).parse()['values']
 slash={'source':slash_path,'sourceMd5':pck.entries[slash_path]['md5'],'hitFrom':method_times['enable_hitbox'],'hitUntil':next(time for time,value in zip(methods['times'],methods['values']) if value['method']=='disable_hitbox' and time>0),'stopAt':method_times['stop'],'times':position['times'],'positions':[v['values'] for v in position['values']],'extents':[v['values'] for v in extents['values']],'hitboxOffset':hitbox_offset,'resetPosition':next(r['properties']['tracks/2/keys']['values'][0]['values'] for r in slash_resource['subresources'].values() if r['resourceType']=='Animation' and r['properties'].get('resource_name')=='RESET'),'resetExtents':next(r['properties']['tracks/3/keys']['values'][0]['values'] for r in slash_resource['subresources'].values() if r['resourceType']=='Animation' and r['properties'].get('resource_name')=='RESET')}
 prepare_path='res://entities/units/enemies/attack_behaviors/enemy_charge_prep_animation.tres'
 prepare=pck.resource(prepare_path)['properties']
 prepare_method=next(prepare[k.replace('/type','/keys')] for k,v in prepare.items() if k.endswith('/type') and v=='method')
 slash['actorFireAt']=next(t for t,v in zip(prepare_method['times'],prepare_method['values']) if v['method']=='shoot')
 slash['actorAnimationSeconds']=prepare['length']
 slash['actorAnimationSource']={'source':prepare_path,'sourceMd5':pck.entries[prepare_path]['md5']}
 facts={'version':'1.2.0.1','steamBuild':26406319,'minimumDanger':6,'slash':slash,'sources':[{'source':path,'sourceMd5':pck.entries[path]['md5']} for path in common],'circleDefault':{'radius':10,'source':'https://docs.godotengine.org/en/3.5/classes/class_circleshape2d.html'},'shootAnimation':timing,'implemented':['BloatedSpawner','DireJunkie','HornedFly','HornedSpitter','CorruptedBuffer','InfectedSlasherEgg','MadSlasher'],'pending':[],'rules':{'spawnedChildren':5,'allyBoostDuration':boost_duration,'spawnSquarePixels':200,'physicsRate':60,'arrivePixels':10,'projectileRadiusPixels':17},'runtimeCompatibility':{'referencePlayerSpeedPixels':450,'slashVisual':{'floorLift':0.1,'thickness':0.04,'activeTransparency':0.4,'warningTransparency':0.75},'wanderTimeoutSeconds':8,'projectileRangeStuds':300,'mass':1,'note':'Existing engine fallback values, not native source facts; full Area/physics and projectile lifetime acceptance remains open'},'enemies':rows}
 outputs={ROOT/'docs/characters/nightmare-enemies-source.json':json.dumps(facts,indent=2)+'\n',ROOT/'src/shared/Config/NightmareEnemies.luau':'--!strict\n-- Stable Nightmare enemy facts; NightmareEnemyKinds activates only the explicitly implemented families.\nreturn '+compiler.luau(facts)+'\n'}
 for path,text in outputs.items():
  if path.suffix=='.luau':
   with tempfile.TemporaryDirectory(dir=ROOT/'build') as temp:
    candidate=Path(temp)/path.name;candidate.write_text(text,encoding='utf-8');subprocess.run(['stylua',str(candidate)],check=True);text=candidate.read_text(encoding='utf-8')
  if args.check:assert path.read_text(encoding='utf-8')==text,f'Stale Nightmare enemy facts: {path}'
  else:path.write_text(text,encoding='utf-8',newline='\n')
 print('Seven source identities checked; seven behavior families selected; no source-only identity counted as implemented')
if __name__=='__main__':main()
