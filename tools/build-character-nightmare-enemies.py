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
 common=['res://entities/units/enemies/enemy.tscn','res://entities/units/enemies/enemy.gdc','res://entities/units/enemies/attack_behaviors/shoot.tres','res://entities/units/enemies/attack_behaviors/shooting_attack_behavior.gdc','res://entities/units/enemies/crash_zone/basic/bloated_spawner/bloated_spawner.gdc','res://entities/units/enemies/crash_zone/basic/horned_fly/horned_fly.gdc','res://entities/units/enemies/crash_zone/basic/corrupted_buffer/corrupted_buffer.gdc','res://entities/units/player/player.tscn','res://entities/units/unit/unit.gdc','res://entities/units/unit/stats.gdc','res://singletons/entity_service.gdc']
 animation=pck.resource(common[2])['properties']
 timing={'fireAt':next(animation[k]['times'][i] for k in animation if k.endswith('/keys') and isinstance(animation[k],dict) and 'values' in animation[k] for i,v in enumerate(animation[k]['values']) if isinstance(v,dict) and v.get('method')=='shoot'),'duration':animation.get('length',1)}
 _,player_nodes=scenes.scene(pck,'res://entities/units/player/player.tscn')
 boost_duration=float(next(n['properties']['wait_time'] for n in player_nodes if n['name']=='BoostTimer'))
 facts={'version':'1.2.0.1','steamBuild':26406319,'minimumDanger':6,'sources':[{'source':path,'sourceMd5':pck.entries[path]['md5']} for path in common],'circleDefault':{'radius':10,'source':'https://docs.godotengine.org/en/3.5/classes/class_circleshape2d.html'},'shootAnimation':timing,'implemented':['BloatedSpawner','DireJunkie','HornedFly','HornedSpitter','CorruptedBuffer'],'pending':['InfectedSlasherEgg','MadSlasher'],'rules':{'spawnedChildren':5,'allyBoostDuration':boost_duration,'spawnSquarePixels':200,'physicsRate':60,'arrivePixels':10,'projectileRadiusPixels':17},'runtimeCompatibility':{'wanderTimeoutSeconds':8,'projectileRangeStuds':300,'mass':1,'note':'Existing engine fallback values, not native source facts; full Area/physics and projectile lifetime acceptance remains open'},'enemies':rows}
 outputs={ROOT/'docs/characters/nightmare-enemies-source.json':json.dumps(facts,indent=2)+'\n',ROOT/'src/shared/Config/NightmareEnemies.luau':'--!strict\n-- Stable Nightmare enemy facts; NightmareEnemyKinds activates only the explicitly implemented families.\nreturn '+compiler.luau(facts)+'\n'}
 for path,text in outputs.items():
  if path.suffix=='.luau':
   with tempfile.TemporaryDirectory(dir=ROOT/'build') as temp:
    candidate=Path(temp)/path.name;candidate.write_text(text,encoding='utf-8');subprocess.run(['stylua',str(candidate)],check=True);text=candidate.read_text(encoding='utf-8')
  if args.check:assert path.read_text(encoding='utf-8')==text,f'Stale Nightmare enemy facts: {path}'
  else:path.write_text(text,encoding='utf-8',newline='\n')
 print('Seven source identities checked; five behavior families selected, two explicitly pending')
if __name__=='__main__':main()
