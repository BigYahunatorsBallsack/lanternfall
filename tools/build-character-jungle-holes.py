"""Compile factual Jungle hole layouts and distinct physical/forbidden shapes; no terrain or area is activated."""
from __future__ import annotations
import argparse,importlib.util,json,math,re,subprocess,sys,tempfile
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
def module(name,path):
 spec=importlib.util.spec_from_file_location(name,ROOT/path);out=importlib.util.module_from_spec(spec);spec.loader.exec_module(out);return out
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
 source=module('holes_source','tools/character-source.py');reader=module('holes_scene','tools/build-character-pets.py');compiler=module('holes_lua','tools/build-character-catalog.py')
 pck=source.Pck();reference=source.verify_reference(pck)
 main_path='res://main.tscn';raw=pck.read(main_path).decode();refs={i:v for v,i in re.findall(r'\[ext_resource path="([^\"]+)" type="[^\"]+" id=(\d+)\]',raw)}
 groups={}
 for line in raw.splitlines():
  if line.startswith(('holes_scene','holes_old_scene','holes_explorer_scene')):groups[line.split('=')[0].strip()]=[refs[i] for i in re.findall(r'ExtResource\( (\d+) \)',line)]
 layouts={}
 hole='res://entities/gpe/hole/hole.tscn'
 for paths in groups.values():
  for path in paths:
   text=pck.read(path).decode();chunks=re.split(r'(?=^\[node )',text,flags=re.M);positions=[]
   external={i:v for v,i in re.findall(r'\[ext_resource path="([^\"]+)" type="[^\"]+" id=(\d+)\]',text)}
   assert 'instance=ExtResource' not in chunks[1].splitlines()[0], 'Inherited layouts need explicit resolution'
   assert not re.search(r'^(position|scale|rotation) =',chunks[1],re.M), 'Root layout transforms need explicit composition'
   for chunk in chunks[2:]:
    heading=chunk.splitlines()[0]
    instance=re.search(r'instance=ExtResource\( (\d+) \)',heading)
    assert instance and external[instance[1]]==hole and 'parent="."' in heading
    assert not re.search(r'^(scale|rotation) =',chunk,re.M), 'Non-default layout transforms need explicit composition'
    at=re.search(r'^position = Vector2\( ([^,]+), ([^)]+) \)',chunk,re.M)
    positions.append([float(v) for v in at.groups()] if at else [0,0])
   layouts[path]={'sourceMd5':pck.entries[path]['md5'],'positionsPoints':positions}
 scene=reader.read_scene(pck,hole);collision=next(n['properties'] for n in scene['nodes'] if n['name']=='CollisionShape2D');shape=scene['shapes'][collision['shape']['resource'].split('::')[1]]
 assert shape['resourceType']=='CapsuleShape2D'
 angle=collision.get('rotation',0)
 waves=[]
 for i in range(1,21):
  path=f'res://zones/zone_3_jungle/{i:03d}/wave_{i}.tres'
  if pck.resource(path)['properties'].get('spawn_holes',False):waves.append({'wave':i,'source':path,'sourceMd5':pck.entries[path]['md5']})
 facts={'version':reference['version'],'steamBuild':int(reference['steamBuildId']),'zoneId':2,'areaPlayable':False,'terrainActivated':False,'mainSource':main_path,'mainSourceMd5':pck.entries[main_path]['md5'],'groups':groups,'layouts':layouts,'waves':waves,'physical':{'source':hole,'sourceMd5':pck.entries[hole]['md5'],'radiusPoints':shape['properties']['radius'],'halfLengthPoints':shape['properties']['height']/2,'rotation':angle,'axisX':-math.sin(angle),'axisZ':math.cos(angle),'capsuleHeightMeaning':'Godot3 height is the center segment length; total length is height+2*radius','engineSource':'https://github.com/godotengine/godot/blob/3.x/scene/resources/capsule_shape_2d.cpp'},'forbiddenRadiusPoints':130,'sampling':{'edgePoints':64,'maxEdgeShare':0.2,'areaTries':5,'pushOutEpsilonSquaredPoints':0.001,'pushOutPaddingPoints':8,'cellSizePoints':64,'cellRetries':3,'goalTries':8},'layoutOffsetPoints':[1,1],'selection':{'explorerWhenMapSizeEquals':33,'oldForOtherNonzero':True},'ruleSources':[{'source':s,'sourceMd5':pck.entries[s]['md5']} for s in ['res://entities/gpe/hole/hole.gdc','res://global/gpe_spawner.gdc','res://singletons/zone_service.gdc','res://entities/units/movement_behaviors/target_rand_pos_movement_behavior.gdc','res://entities/units/movement_behaviors/target_rand_pos_around_player_movement_behavior.gdc']]}
 outputs={ROOT/'docs/characters/jungle-holes-source.json':json.dumps(facts,indent=2)+'\n',ROOT/'src/shared/Config/JungleHoles.luau':'--!strict\n-- Native Jungle hole shapes/layouts for geometry tests and the pending terrain port; no area or terrain is activated.\nreturn '+compiler.luau(facts)+'\n'}
 for path,text in outputs.items():
  if path.suffix=='.luau':
   with tempfile.TemporaryDirectory(dir=ROOT/'build') as folder:
    temp=Path(folder)/path.name;temp.write_text(text,encoding='utf-8');subprocess.run(['stylua',str(temp)],check=True);text=temp.read_text(encoding='utf-8')
  if args.check:assert path.read_text(encoding='utf-8')==text,'Stale native hole facts: '+str(path)
  else:path.write_text(text,encoding='utf-8',newline='\n')
 print('Nine native hole layouts and separate capsule/forbidden geometry compiled; terrain not activated')
if __name__=='__main__':main()
