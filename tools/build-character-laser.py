"""Compile the source infinite enemy laser geometry and audited timer rules without activating a boss."""
from __future__ import annotations
import argparse,importlib.util,json,re,subprocess,sys,tempfile
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
def module(name,path):
 s=importlib.util.spec_from_file_location(name,ROOT/path);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def generate():
 source=module('laser_source','tools/character-source.py');phases=module('laser_scene','tools/build-character-boss-phases.py');p=source.Pck();ref=source.verify_reference(p)
 path='res://projectiles/laser_enemy/enemy_laser_infinite.tscn';script='res://projectiles/laser_enemy/enemy_laser.gdc'
 assert p.entries[path]['md5']=='4cce0f7717b6f3f2645ffd063abdd14f'
 assert p.entries[script]['md5']=='d7910eed6ea19d16fa089013dd4baff1'
 raw=p.read(path).decode();collision=phases.node_properties(raw,path,source,'Collision','Hitbox')
 prefix=raw[:re.search(r'^\[node ',raw,re.M).start()].replace('[gd_scene','[gd_resource type="PackedScene"',1)
 shapes=source.parse_tres(prefix+'\n[resource]\n',path)['subresources']
 shape=shapes[collision['shape']['resource'].split('::')[1]];assert shape['resourceType']=='RectangleShape2D'
 return {'version':ref['version'],'steamBuild':int(ref['steamBuildId']),'source':path,'sourceMd5':p.entries[path]['md5'],'scriptSource':script,'scriptMd5':p.entries[script]['md5'],
 'halfExtentsPoints':shape['properties']['extents']['values'],'offsetPoints':collision['position']['values'],
 'frameRate':60,'delaySeconds':0.75,'afterSeconds':0.4,
 'audit':{'sourceFollowsTranslation':True,'rotationFixedAtBirth':True,'stopAfterFirstHit':True,'deleteWithSource':False,'basePhysicsAutomaticallyCalled':True,'callbackOrder':['EnemyLaser','Projectile'],'afterDecrementsOnEnablingFrame':True},
 'enginePackVersion':p.engine,'engineSource':{'scope':'Godot3-family callback semantics, not an exact installed executable build match','url':'https://raw.githubusercontent.com/godotengine/godot/3.5.3-stable/modules/gdscript/gdscript.cpp','symbol':'GDScriptInstance::call_multilevel','lines':[1124,1134]},'originalVisualAccepted':False}
def main():
 a=argparse.ArgumentParser(description=__doc__);a.add_argument('--check',action='store_true');args=a.parse_args();data=generate();cat=module('laser_catalog','tools/build-character-catalog.py')
 text='--!strict\n-- Source centered infinite enemy laser geometry and clocks; NativeLaserService owns hostile instances.\nlocal data='+cat.luau(data)+'\nreturn data\n'
 with tempfile.TemporaryDirectory(dir=ROOT/'build') as folder:
  path=Path(folder)/'NativeEnemyLaser.luau';path.write_text(text,encoding='utf-8')
  for _ in range(2):subprocess.run(['stylua',str(path)],check=True)
  text=path.read_text(encoding='utf-8')
 for path,value in {ROOT/'src/shared/Config/NativeEnemyLaser.luau':text,ROOT/'docs/characters/enemy-laser-source.json':json.dumps(data,indent=2)+'\n'}.items():
  if args.check:assert path.read_text(encoding='utf-8')==value,'Stale laser source: '+str(path)
  else:path.write_text(value,encoding='utf-8',newline='\n')
 print('Source infinite laser geometry and clock rules compiled')
if __name__=='__main__':main()
