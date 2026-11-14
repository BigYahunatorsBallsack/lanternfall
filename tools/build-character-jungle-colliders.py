"""Compile approved saved Jungle collider transforms without reading a newer installed PCK."""
from __future__ import annotations
import argparse, importlib.util, json, subprocess, sys, tempfile
from pathlib import Path
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
 data=json.loads((ROOT/'docs/characters/jungle-collider-offsets-source.json').read_text(encoding='utf-8'))
 base=json.loads((ROOT/'docs/characters/jungle-walkers-source.json').read_text(encoding='utf-8'))
 ref=json.loads((ROOT/'docs/characters/reference.json').read_text(encoding='utf-8'))
 assert data['version']==base['version']==ref['version']
 assert int(data['steamBuild'])==int(base['steamBuild'])==int(ref['steamBuildId'])
 assert set(data['actors'])==set(base['enemies'])
 for name,row in data['actors'].items():
  original=base['enemies'][name]
  assert row['source']==original['source'] and row['sourceMd5']==original['sourceMd5'],name
  chain=row['sceneChain'];assert chain[0]==row['source'] and len(chain)==len(set(chain)),name
  for index,path in enumerate(chain):
   scene=data['scenes'][path]
   assert len(scene['sourceMd5'])==32 and all(c in '0123456789abcdef' for c in scene['sourceMd5']),path
   assert scene.get('baseScene')==(chain[index+1] if index+1<len(chain) else None),path
  assert data['scenes'][row['source']]['sourceMd5']==row['sourceMd5'],name
  for shape in ['hurt','hit']:
   r=row[shape];assert r['childPoints']==original[shape]['offsetPoints'],name
   assert r['initialParentScale']==[1,1] and r['initialParentRotation']==0,name
   assert r['totalPoints']==[a+b for a,b in zip(r['parentPoints'],r['childPoints'])],name
 spec=importlib.util.spec_from_file_location('collider_catalog',ROOT/'tools/build-character-catalog.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
 with tempfile.TemporaryDirectory(dir=ROOT/'build') as folder:
  temp=Path(folder)/'JungleColliderOffsets.luau'
  temp.write_text('--!strict\n-- Approved saved Jungle collider parent/child transforms; JungleEnemyKinds activates supported branches.\nreturn '+module.luau(data)+'\n',encoding='utf-8')
  subprocess.run(['stylua',str(temp)],check=True);text=temp.read_text(encoding='utf-8')
 path=ROOT/'src/shared/Config/JungleColliderOffsets.luau'
 if args.check: assert path.read_text(encoding='utf-8')==text,'Stale compiled collider snapshot'
 else: path.write_text(text,encoding='utf-8',newline='\n')
 print(str(len(data['actors']))+' approved saved collider records compiled; installed-version guard unchanged')
if __name__=='__main__':main()
