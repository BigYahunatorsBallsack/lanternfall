"""Bind audited EntityService factor-cache constants and co-op scene for the live native enemy stat provider."""
from __future__ import annotations
import argparse, importlib.util, json, subprocess, sys, tempfile
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
def module(name,path):
 spec=importlib.util.spec_from_file_location(name,ROOT/path);result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result
def generate():
 source=module('stat_cache_source','tools/character-source.py');roots=module('stat_cache_roots','tools/build-character-enemy-evolution.py')
 pck=source.Pck();reference=source.verify_reference(pck)
 hashes={'res://singletons/entity_service.gdc':'f1a861f576858bbaa3e913d83c7b1807','res://entities/units/unit/unit.gdc':'aa94391f2d9681ac36b7f8617b82ff13','res://singletons/utils.gdc':'2c263b6d3c2355dd71d6ad4caf0705bf','res://singletons/coop_service.gdc':'c7acffec9f3ec81159811794fd343149','res://main.gdc':'e42c7c4356e6cb9d2da8190067ebf7e5'}
 for path,digest in hashes.items():assert pck.entries[path]['md5']==digest,'Re-audit changed native stat cache source: '+path
 scene='res://singletons/coop_service.tscn';props=roots.root_properties(pck.read(scene).decode('utf-8'),scene)
 assert props['script']['resource']=='res://singletons/coop_service.gd'
 coop={key:props['additional_enemy_'+key+'_per_coop_player'] for key in ['health','damage']}
 assert all(isinstance(value,(int,float)) for value in coop.values())
 return {'version':reference['version'],'steamBuild':int(reference['steamBuildId']),'sourceScene':scene,'sourceSceneMd5':pck.entries[scene]['md5'],'coopPerAdditionalPlayer':coop,'rules':{'percent':100,'minimumFactor':0.01,'minimumPlayerSpeedPercent':-75,'curseHealthDivisor':10,'curseDamageDivisor':25,'endlessHealthMultiplier':2.25,'endlessSpeedDivisor':13.33,'endlessSpeedCap':1.75},'ruleSources':[{'source':p,'sourceMd5':digest} for p,digest in hashes.items()],'productionProviderImplemented':True,'enemyTimeResetImplemented':False,'nativeFullParityAccepted':False}
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args();data=generate();catalog=module('stat_cache_catalog','tools/build-character-catalog.py')
 with tempfile.TemporaryDirectory(dir=ROOT/'build') as folder:
  path=Path(folder)/'NativeEnemyStatCache.luau';path.write_text('--!strict\n-- Audited source enemy factor-cache rules; EnemySim.NativeEnemyStats supplies live contexts for supported actor births and boosts.\nreturn '+catalog.luau(data)+'\n',encoding='utf-8');subprocess.run(['stylua',str(path)],check=True);text=path.read_text(encoding='utf-8')
 outputs={ROOT/'src/shared/Config/NativeEnemyStatCache.luau':text,ROOT/'docs/characters/enemy-stat-cache-source.json':json.dumps(data,indent=2)+'\n'}
 for path,value in outputs.items():
  if args.check:assert path.read_text(encoding='utf-8')==value,'Stale native stat cache binding: '+str(path)
  else:path.write_text(value,encoding='utf-8',newline='\n')
 print('Source stat cache rules and actual co-op factors compiled for the live native actor provider; full parity remains open')
if __name__=='__main__':main()
