"""Read only the six required stable native pet families into neutral, source-hashed facts.
No scripts or full scenes are copied; these facts alone do not implement pets.
"""
from __future__ import annotations
import argparse, csv, importlib.util, json, re, sys
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('pet_character_source',ROOT/'tools/character-source.py')
source=importlib.util.module_from_spec(spec);spec.loader.exec_module(source)
FAMILIES=['bonk_dog','catling_gun','blazemander','bot_o_mine','lootworm','ratzilla']
VISUAL={'texture','sprite_frames','frames','material','curse_particles','sound_attack','shooting_sounds','icon','item_appearances','sound','script','animation','shooting_sounds','sound_db_mod'}
def facts(props):
 return {k:v for k,v in props.items() if k not in VISUAL and (isinstance(v,(int,float,bool)) or k in ['scaling_stats','stats','movement_behavior','target_behavior','weapon_stats','ranged_weapon_stats','burning_data','explosion_effect','landmine_effect_stat','scene','double_chance','max_nb','tags','custom_args','effects'])}
def read_scene(pck,path):
 raw=pck.read(path).decode('utf-8');starts=list(re.finditer(r'^\[node .*\]\s*$',raw,re.M));assert starts,path
 prefix=raw[:starts[0].start()].replace('[gd_scene','[gd_resource type="PackedScene"',1)
 nodes=[]
 for i,match in enumerate(starts):
  attrs=dict(re.findall(r'(name|parent|type)="([^"]*)"',match.group()))
  text=raw[match.end():starts[i+1].start() if i+1<len(starts) else len(raw)]
  text=re.split(r'^\[connection ',text,flags=re.M)[0]
  parsed=source.parse_tres(prefix+'\n[resource]\n'+text,path)
  values={k:v for k,v in parsed['properties'].items() if k not in VISUAL and (isinstance(v,(int,float,bool)) or k in ['stats','shape','position','scale','target_behavior','movement_behavior','charge_duration','min_squared_distance_for_jump_attack','weapon_stats','tree_damage_ratio'])}
  if values or 'script' in parsed['properties']:
   nodes.append({'name':attrs.get('name'),'parent':attrs.get('parent'),'type':attrs.get('type'),'scriptSource':parsed['properties'].get('script',{}).get('resource'),'properties':values})
 parsed=source.parse_tres(prefix+'\n[resource]\n',path)
 shapes={k:v for k,v in parsed['subresources'].items() if 'Shape' in v['resourceType']}
 root_instance=re.search(r'instance=ExtResource\(\s*(\d+)\s*\)',starts[0].group())
 base=next((v['path'] for v in parsed['externalResources'] if root_instance and str(v['id'])==root_instance[1]),None)
 return {'sourceMd5':pck.entries[path]['md5'],'baseScene':base,'nodes':nodes,'shapes':shapes}
def generate(pck):
 rows=[];resources={};scenes={}
 for slug in FAMILIES:
  path=f'res://items/all/03_paws_n_claws/{slug}/{slug}.tres'
  item=pck.resource(path)['properties'];effect_path=item['effects'][0]['resource'];effect=pck.resource(effect_path)['properties'];scene=effect['scene']['resource']
  row={'slug':slug,'id':''.join(w.title() for w in slug.split('_')),'source':path,'sourceMd5':pck.entries[path]['md5'],'nameKey':item['name'],'tier':item['tier']+1,'price':item['value'],'limit':item['max_nb'],'tags':item.get('tags',[]),'iconSource':item['icon']['resource'],'effectSource':effect_path,'effectMd5':pck.entries[effect_path]['md5'],'effect':facts(effect)}
  scenes[scene]=read_scene(pck,scene)
  pending=[ref['resource'] for ref in source.references(effect) if ref['resource'].endswith('.tres') and '::' not in ref['resource']]
  for node in scenes[scene]['nodes']:
   pending.extend(ref['resource'] for ref in source.references(node['properties']) if ref['resource'].endswith('.tres') and '::' not in ref['resource'])
  seen=set()
  while pending:
   ref=pending.pop()
   if ref in seen:continue
   seen.add(ref);data=pck.resource(ref)['properties'];resources[ref]={'sourceMd5':pck.entries[ref]['md5'],'properties':facts(data)}
   pending.extend(r['resource'] for r in source.references(data) if r['resource'].endswith('.tres') and '::' not in r['resource'])
  rows.append(row)
 pending=[v['baseScene'] for v in scenes.values() if v.get('baseScene')]
 while pending:
  ref=pending.pop()
  if ref in scenes:continue
  scenes[ref]=read_scene(pck,ref)
  if scenes[ref].get('baseScene'):pending.append(scenes[ref]['baseScene'])
 return {'version':'1.2.0.1','steamBuild':26406319,'pets':rows,'resources':resources,'scenes':scenes,'note':'Neutral pet facts, not a claim of implemented behavior or available original artwork.'}
def main():
 a=argparse.ArgumentParser();a.add_argument('--pck',type=Path,default=source.DEFAULT_PCK);a.add_argument('--output',type=Path,default=ROOT/'docs/characters/pet-source.json');args=a.parse_args();out=generate(source.Pck(args.pck));args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(out,indent=2,ensure_ascii=False)+'\n',encoding='utf-8');print(len(out['pets']),'pet families,',len(out['resources']),'resources,',len(out['scenes']),'scenes inspected')
if __name__=='__main__':main()
