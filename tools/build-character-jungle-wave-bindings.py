"""Compile actual stable Jungle wave/group/unit/boss bindings; no production scheduler or playable-zone claim."""
from __future__ import annotations
import argparse, importlib.util, json, subprocess, sys, tempfile
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
def module(name,path):
 spec=importlib.util.spec_from_file_location(name,ROOT/path);result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result

def generate():
 source=module('jungle_wave_source','tools/character-source.py');pck=source.Pck();reference=source.verify_reference(pck)
 zonePath='res://zones/zone_3_jungle/zone_jungle_data.tres';zone=pck.resource(zonePath)['properties']
 fields=['waves_data','groups_data_in_all_waves','loot_alien_groups','horde_groups','bosses','elites','endless_enemy_scenes','endless_nightmare_enemy_scenes']
 roots={k:zone[k] for k in fields};queue=[];seen=set();resources={};scenes={}
 overlays=[]
 for path in sorted(pck.entries):
  if path.startswith('res://dlcs/') and path.endswith('.tres') and b'groups_in_all_zones' in pck.read(path):
   props=pck.resource(path)['properties']
   overlays.append({'source':path,'sourceMd5':pck.entries[path]['md5'],'contentId':props['my_id'],'groups':props['groups_in_all_zones']})
 roots['possibleActiveDlcGlobalGroups']=overlays
 normal=json.loads((ROOT/'docs/characters/jungle-walkers-source.json').read_text(encoding='utf-8'))
 assert normal['version']==reference['version']
 registered={v['source']:k for k,v in normal['enemies'].items()}
 def visit(value,owner):
  if isinstance(value,dict):
   path=value.get('resource')
   if path and value.get('resourceType')=='PackedScene':
    assert path in pck.entries,path
    row=scenes.setdefault(path,{'sourceMd5':pck.entries[path]['md5'],'boundBy':[],**({'registeredNormalJungleId':registered[path]} if path in registered else {})})
    if owner not in row['boundBy']:row['boundBy'].append(owner)
   elif path and value.get('resourceType')=='Resource' and (path.endswith('.tres') or '::' in path):
    queue.append(path)
   else:
    for child in value.values():visit(child,owner)
  elif isinstance(value,list):
   for child in value:visit(child,owner)
 visit(roots,zonePath)
 while queue:
  path=queue.pop(0)
  if path in seen:continue
  seen.add(path);row=pck.resource(path);props=row['properties'];base=path.split('::')[0]
  resources[path]={'sourceMd5':pck.entries[base]['md5'],'properties':props}
  visit(props,path)
 groups={path:{'id':path,'sourceMd5':row['sourceMd5'],**{k:v for k,v in row['properties'].items() if k!='script'}} for path,row in resources.items() if row['properties'].get('script',{}).get('resource')=='res://zones/wave_group_data.gd'}
 units={path:row for path,row in resources.items() if row['properties'].get('script',{}).get('resource')=='res://zones/wave_unit_data.gd'}
 for group in groups.values():
  for unit in group['wave_units_data']:assert unit['resource'] in units,unit
 wavePaths=[r['resource'] for r in roots['waves_data']];assert len(wavePaths)==20
 assert pck.entries['res://zones/wave_manager.gdc']['md5']=='37639a8d7aeffdc7e9990dcdd6acb3b2','Re-audit WaveManager clock constants before compiling changed script'
 scripts=['res://zones/wave_manager.gdc','res://zones/wave_data.gdc','res://zones/wave_group_data.gdc','res://zones/wave_unit_data.gdc','res://global/entity_spawner.gdc']
 return {'version':reference['version'],'steamBuild':int(reference['steamBuildId']),'zoneSource':zonePath,'zoneSourceMd5':pck.entries[zonePath]['md5'],'clockRules':{'version':reference['version'],'steamBuild':int(reference['steamBuildId']),'source':'res://zones/wave_manager.gdc','sourceMd5':pck.entries['res://zones/wave_manager.gdc']['md5'],'initialLastChecked':0,'neutralStartWindowSeconds':5,'productionAdapterImplemented':False},'scope':'Direct Jungle roots plus union of possible active DLC global groups; actual content selection/dynamic effects still pending.','zonePlayable':False,'productionAdapterImplemented':False,'roots':roots,'waves':[{'source':p,**resources[p]} for p in wavePaths],'groups':dict(sorted(groups.items())),'units':dict(sorted(units.items())),'otherResources':{p:r for p,r in sorted(resources.items()) if p not in groups and p not in units and p not in wavePaths},'scenes':dict(sorted(scenes.items())),'ruleSources':[{'source':p,'sourceMd5':pck.entries[p]['md5']} for p in scripts]}

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args();data=generate()
 compiler=module('jungle_wave_catalog','tools/build-character-catalog.py')
 with tempfile.TemporaryDirectory(dir=ROOT/'build') as folder:
  temp=Path(folder)/'NativeJungleWaveBindings.luau';temp.write_text('--!strict\n-- Actual source Jungle wave/group/unit/boss references; NativeWaveGroups is tested separately, production area binding remains pending.\nreturn '+compiler.luau(data)+'\n',encoding='utf-8');subprocess.run(['stylua',str(temp)],check=True);text=temp.read_text(encoding='utf-8')
 clock='--!strict\n-- Audited source WaveManager clock constants; NativeWaveGroups component reads these, production area adapter remains pending.\nreturn table.freeze('+compiler.luau(data['clockRules'])+')\n'
 with tempfile.TemporaryDirectory(dir=ROOT/'build') as folder:
  temp=Path(folder)/'NativeWaveGroups.luau';temp.write_text(clock,encoding='utf-8');subprocess.run(['stylua',str(temp)],check=True);clock=temp.read_text(encoding='utf-8')
 outputs={ROOT/'src/shared/Config/NativeWaveGroups.luau':clock,ROOT/'docs/characters/jungle-wave-bindings-source.json':json.dumps(data,indent=2)+'\n',ROOT/'src/shared/Config/NativeJungleWaveBindings.luau':text}
 for path,value in outputs.items():
  if args.check:assert path.read_text(encoding='utf-8')==value,'Stale Jungle wave binding: '+str(path)
  else:path.write_text(value,encoding='utf-8',newline='\n')
 print('20sourcewaves/'+str(len(data['groups']))+'groups/'+str(len(data['units']))+'units/'+str(len(data['scenes']))+'boundscenes; no playable zone claimed')
if __name__=='__main__':main()
