"""Compile native shared-edge grouped-birth geometry and timing; no area availability changes."""
from __future__ import annotations
import argparse, importlib.util, json, subprocess, sys, tempfile
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
def module(name,path):
 spec=importlib.util.spec_from_file_location(name,ROOT/path);out=importlib.util.module_from_spec(spec);spec.loader.exec_module(out);return out
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
 source=module('group_source','tools/character-source.py');scenes=module('group_scene','tools/build-character-pets.py');compiler=module('group_lua','tools/build-character-catalog.py')
 pck=source.Pck();reference=source.verify_reference(pck)
 path='res://entities/birth/entity_group_birth.tscn';scene=scenes.read_scene(pck,path)
 root=next(n['properties'] for n in scene['nodes'] if not n['parent']);collision=next(n['properties'] for n in scene['nodes'] if n['name']=='CollisionShape2D');shape=scene['shapes'][collision['shape']['resource'].split('::')[1]]
 player='res://entities/units/player/player.tscn';body=scenes.read_scene(pck,player);node=next(n['properties'] for n in body['nodes'] if n['name']=='Collision' and n['parent']=='.');radius=body['shapes'][node['shape']['resource'].split('::')[1]]['properties']['radius']
 facts={'version':reference['version'],'steamBuild':int(reference['steamBuildId']),'source':path,'sourceMd5':pck.entries[path]['md5'],'frameRate':60,'markerSeconds':root['time_before_spawn']/60,'jitterXPoints':25,'jitterZPoints':50,'radiusPoints':shape['properties']['radius'],'playerBody':{'source':player,'sourceMd5':pck.entries[player]['md5'],'radiusPoints':radius,'offsetPoints':node['position']['values']},'ruleSources':[{'source':p,'sourceMd5':pck.entries[p]['md5']} for p in ['res://global/entity_spawner.gdc','res://entities/birth/entity_group_birth.gdc','res://entities/birth/entity_birth.gdc']],'areaPlayable':False}
 outputs={ROOT/'docs/characters/group-birth-source.json':json.dumps(facts,indent=2)+'\n',ROOT/'src/shared/Config/GroupBirth.luau':'--!strict\n-- Native grouped edge births: source geometry and timing consumed by SpawnRules and SpawnDirector; no area availability changes.\nreturn '+compiler.luau(facts)+'\n'}
 for path,text in outputs.items():
  if path.suffix=='.luau':
   with tempfile.TemporaryDirectory(dir=ROOT/'build') as folder:
    temp=Path(folder)/path.name;temp.write_text(text,encoding='utf-8');subprocess.run(['stylua',str(temp)],check=True);text=temp.read_text(encoding='utf-8')
  if args.check:assert path.read_text(encoding='utf-8')==text,'Stale group birth facts: '+str(path)
  else:path.write_text(text,encoding='utf-8',newline='\n')
 print('Native grouped-birth facts checked; no new character or playable area')
if __name__=='__main__':main()
