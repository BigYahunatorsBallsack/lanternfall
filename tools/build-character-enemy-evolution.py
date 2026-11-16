"""Compile audited stable TeamEvolution/scene boost rules; no production enemy evolution is enabled."""
from __future__ import annotations
import argparse, importlib.util, json, subprocess, sys, tempfile
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
def module(name,path):
 spec=importlib.util.spec_from_file_location(name,ROOT/path);result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result
def generate():
 source=module('evolution_source','tools/character-source.py');scene=module('evolution_scene','tools/build-character-pets.py')
 pck=source.Pck();reference=source.verify_reference(pck)
 hashes={'res://global/team_evolution.gdc':'181c41245fca03a555deeb9b065f12b8','res://singletons/utils.gdc':'2c263b6d3c2355dd71d6ad4caf0705bf','res://effect_behaviors/scenes/evolution_scene_effect_behavior.gdc':'dc45c24ca1f29085674835e1d64879ad'}
 for path,digest in hashes.items():assert pck.entries[path]['md5']==digest,'Re-audit changed evolution source before compiling defaults: '+path
 dataPath='res://effect_behaviors/scenes/evolution_scene_effect_behavior_data.tres'
 scenePath=pck.resource(dataPath)['properties']['scene']['resource']
 parsed=scene.read_scene(pck,scenePath);root=next(n for n in parsed['nodes'] if n['parent'] is None)
 assert root['scriptSource']=='res://effect_behaviors/scenes/evolution_scene_effect_behavior.gd'
 defaults={'hp_boost_meca':50,'hp_boost_per_evolution_meca':2,'damage_boost_meca_min':25,'damage_boost_meca_max':50,'speed_boost_meca_min':5,'speed_boost_meca_max':25,'hp_boost_mutant':25,'hp_boost_per_evolution_mutant':2.4,'damage_boost_mutant_min':15,'damage_boost_mutant_max':80,'speed_boost_mutant_min':5,'speed_boost_mutant_max':25}
 settings={**defaults,**{k:v for k,v in root['properties'].items() if isinstance(v,(int,float))}}
 assert set(settings)==set(defaults),'Unexpected numeric source setting needs an explicit binding'
 return {'version':reference['version'],'steamBuild':int(reference['steamBuildId']),'sourceData':dataPath,'sourceDataMd5':pck.entries[dataPath]['md5'],'sourceScene':scenePath,'sourceSceneMd5':pck.entries[scenePath]['md5'],'sourceScript':root['scriptSource'],'settings':settings,'rules':{'curveMaximum':100,'curveScale':50,'percent':100,'chanceDivisor':2,'endlessDivisor':2,'eliteMultiplier':4,'minimumMagnitude':1,'boostMagnitude':100,'mutantDamageMagnitude':150,'hpMagnitude':300},'behaviorData':{k:v for k,v in root['properties'].items() if isinstance(v,dict) and v.get('resourceType')=='Resource'},'ruleSources':[{'source':p,'sourceMd5':v} for p,v in hashes.items()],'productionAdapterImplemented':False,'nativeFullParityAccepted':False}
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args();data=generate();compiler=module('evolution_catalog','tools/build-character-catalog.py')
 with tempfile.TemporaryDirectory(dir=ROOT/'build') as folder:
  temp=Path(folder)/'NativeEnemyEvolution.luau';temp.write_text('--!strict\n-- Audited stable team evolution and scene boost percentages; component only, production enemy evolution remains pending.\nreturn '+compiler.luau(data)+'\n',encoding='utf-8');subprocess.run(['stylua',str(temp)],check=True);text=temp.read_text(encoding='utf-8')
 outputs={ROOT/'docs/characters/enemy-evolution-source.json':json.dumps(data,indent=2)+'\n',ROOT/'src/shared/Config/NativeEnemyEvolution.luau':text}
 for path,value in outputs.items():
  if args.check:assert path.read_text(encoding='utf-8')==value,'Stale enemy evolution binding: '+str(path)
  else:path.write_text(value,encoding='utf-8',newline='\n')
 print('Audited TeamEvolution/boost rules compiled; production adapter remains disabled')
if __name__=='__main__':main()
