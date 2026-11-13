"""Compile the first native Jungle pursuit bodies into the existing enemy engine.
Only explicitly selected pursuit/contact families are activated. No zone is exposed.
"""
from __future__ import annotations
import argparse, importlib.util, json, subprocess, sys, tempfile
from pathlib import Path
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
FAMILIES = {'baby_triceratops': ('BabyTriceratops', 40, 'Baby Triceratops'), 'gallimimus': ('Gallimimus', 41, 'Gallimimus'), 'lystrosaurus': ('Lystrosaurus', 42, 'Lystrosaurus'), 'pyroraptor': ('Pyroraptor', 43, 'Pyroraptor')}

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
  assert root['scriptSource'] == 'res://entities/units/enemies/enemy.gd'
  assert move['scriptSource'] == 'res://entities/units/movement_behaviors/follow_target_movement_behavior.gd'
  assert attack['scriptSource'] == 'res://entities/units/enemies/attack_behaviors/attack_behavior.gd'
  for node in [root,move,attack]:used_scripts.add(node['scriptSource'].removesuffix('.gd')+'.gdc')
  stats_path = root['properties']['stats']['resource'];stats = {k:v for k,v in pck.resource(stats_path)['properties'].items() if isinstance(v,(int,float,bool))}
  assert stats['armor'] == 0 and stats['armor_increase_each_wave'] == 0, 'Armor requires its own runtime policy'
  enemies[identity] = {'typeId':type_id,'displayName':name,'fallbackLook':'Shadeling','source':path,'sourceMd5':pck.entries[path]['md5'],'statsSource':stats_path,'statsMd5':pck.entries[stats_path]['md5'],'stats':stats,'body':circle(nodes[('.','Collision')]),'hurt':circle(nodes[('Hurtbox','Collision')]),'hit':circle(nodes[('Hitbox','Collision')]),'removeFirst':root['properties'].get('to_be_removed_in_priority',False)}
 zone = 'res://zones/zone_3_jungle/zone_jungle_data.tres'
 return {'version':reference['version'],'steamBuild':int(reference['steamBuildId']),'zoneId':pck.resource(zone)['properties']['my_id'],'zoneSource':zone,'zoneSourceMd5':pck.entries[zone]['md5'],'zonePlayable':False,'implemented':list(enemies),'enemies':enemies,'ruleSources':[{'source':path,'sourceMd5':pck.entries[path]['md5']} for path in sorted(used_scripts)],'runtimeCompatibility':{'mass':1,'nativeArtAccepted':False,'physicsAccepted':False,'open':['Existing global body/collision center approximation; source offsets retained explicitly','Native physics ordering and sprite acceptance','Remaining Jungle families, waves, bosses and area route']}}

def main():
 args=argparse.ArgumentParser(description=__doc__);args.add_argument('--check',action='store_true');args=args.parse_args()
 compiler=module('jungle_catalog','tools/build-character-catalog.py');data=generate()
 files={ROOT/'docs/characters/jungle-walkers-source.json':json.dumps(data,indent=2)+'\n',ROOT/'src/shared/Config/JungleWalkers.luau':'--!strict\n-- Source-backed Jungle pursuit facts; JungleEnemyKinds activates only these explicitly implemented families. No playable zone is claimed.\nreturn '+compiler.luau(data)+'\n'}
 for path,text in files.items():
  if path.suffix=='.luau':
   with tempfile.TemporaryDirectory(dir=ROOT/'build') as folder:
    temp=Path(folder)/path.name;temp.write_text(text,encoding='utf-8');subprocess.run(['stylua',str(temp)],check=True);text=temp.read_text(encoding='utf-8')
  if args.check:assert path.read_text(encoding='utf-8')==text,f'Stale Jungle pursuit facts: {path}'
  else:path.write_text(text,encoding='utf-8',newline='\n')
 print('Four Jungle pursuit families compiled; no playable area or new character counted')
if __name__=='__main__':main()
