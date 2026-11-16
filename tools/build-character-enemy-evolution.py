"""Compile audited stable TeamEvolution/scene boost rules; no production enemy evolution is enabled."""
from __future__ import annotations
import argparse, importlib.util, json, re, subprocess, sys, tempfile
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
def module(name,path):
 spec=importlib.util.spec_from_file_location(name,ROOT/path);result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result
def root_properties(raw,path):
 source=module('evolution_root_source','tools/character-source.py')
 nodes=list(re.finditer(r'^\[node .*\]\s*$',raw,re.M))
 assert nodes and 'parent=' not in nodes[0].group(),'Expected a concrete root node: '+path
 prefix=raw[:nodes[0].start()].replace('[gd_scene','[gd_resource type="PackedScene"',1)
 body=raw[nodes[0].end():nodes[1].start() if len(nodes)>1 else len(raw)]
 body=re.split(r'^\[connection ',body,flags=re.M)[0]
 props=source.parse_tres(prefix+'\n[resource]\n'+body,path)['properties']
 assert isinstance(props.get('script'),dict) and props['script'].get('resourceType')=='Script','Missing bound root script: '+path
 return props
def generate():
 source=module('evolution_source','tools/character-source.py')
 pck=source.Pck();reference=source.verify_reference(pck)
 hashes={'res://global/team_evolution.gdc':'181c41245fca03a555deeb9b065f12b8','res://singletons/utils.gdc':'2c263b6d3c2355dd71d6ad4caf0705bf','res://effect_behaviors/scenes/evolution_scene_effect_behavior.gdc':'dc45c24ca1f29085674835e1d64879ad'}
 hashes.update({'res://effect_behaviors/enemies/meca_enemy_effect_behavior.gdc':'60ab0578879a5cb8ec12c1ad365d1815','res://effect_behaviors/enemies/mutant_enemy_effect_behavior.gdc':'5bec52f6fc3c57bf37cc7329a404af93'})
 for path,digest in hashes.items():assert pck.entries[path]['md5']==digest,'Re-audit changed evolution source before compiling defaults: '+path
 dataPath='res://effect_behaviors/scenes/evolution_scene_effect_behavior_data.tres'
 scenePath=pck.resource(dataPath)['properties']['scene']['resource']
 props=root_properties(pck.read(scenePath).decode('utf-8'),scenePath)
 assert props['script']['resource']=='res://effect_behaviors/scenes/evolution_scene_effect_behavior.gd'
 defaults={'hp_boost_meca':50,'hp_boost_per_evolution_meca':2,'damage_boost_meca_min':25,'damage_boost_meca_max':50,'speed_boost_meca_min':5,'speed_boost_meca_max':25,'hp_boost_mutant':25,'hp_boost_per_evolution_mutant':2.4,'damage_boost_mutant_min':15,'damage_boost_mutant_max':80,'speed_boost_mutant_min':5,'speed_boost_mutant_max':25}
 settings={**defaults,**{k:v for k,v in props.items() if isinstance(v,(int,float))}}
 assert set(settings)==set(defaults),'Unexpected numeric source setting needs an explicit binding'
 bindings={k:v for k,v in props.items() if isinstance(v,dict) and v.get('resourceType')=='Resource'}
 assert set(bindings)=={'meca_enemy_effect_behavior_data','mutant_enemy_effect_behavior_data'},'Evolution scene needs both explicit effect bindings'
 effects={}
 for variant in ['Meca','Mutant']:
  data=bindings[variant.lower()+'_enemy_effect_behavior_data']['resource']
  scene=pck.resource(data)['properties']['scene']['resource']
  script=root_properties(pck.read(scene).decode('utf-8'),scene)['script']['resource']
  assert script=='res://effect_behaviors/enemies/'+variant.lower()+'_enemy_effect_behavior.gd'
  effects[variant]={'source':data,'sourceMd5':pck.entries[data]['md5'],'scene':scene,'sceneMd5':pck.entries[scene]['md5'],'script':script,'scriptMd5':pck.entries[script+'c']['md5'],'bonusGold':0.33,'healOnKill':1 if variant=='Mutant' else 0}
 return {'version':reference['version'],'steamBuild':int(reference['steamBuildId']),'sourceData':dataPath,'sourceDataMd5':pck.entries[dataPath]['md5'],'sourceScene':scenePath,'sourceSceneMd5':pck.entries[scenePath]['md5'],'sourceScript':props['script']['resource'],'settings':settings,'rules':{'curveMaximum':100,'curveScale':50,'percent':100,'chanceDivisor':2,'endlessDivisor':2,'eliteMultiplier':4,'minimumMagnitude':1,'boostMagnitude':100,'mutantDamageMagnitude':150,'hpMagnitude':300},'behaviorData':bindings,'effects':effects,'ruleSources':[{'source':p,'sourceMd5':v} for p,v in hashes.items()],'productionAdapterImplemented':False,'nativeFullParityAccepted':False}
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
