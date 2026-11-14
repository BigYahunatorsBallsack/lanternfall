"""Prepare verified Jungle body/pillar PNGs locally; no uploads or runtime asset identifiers."""
from __future__ import annotations
import argparse, hashlib, importlib.util, io, json, re, struct, sys
from pathlib import Path
from PIL import Image
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]

def body_texture(pck,path):
 scene=pck.read(path).decode('utf-8')
 refs={i:path for path,i in re.findall(r'\[ext_resource path="([^\"]+)" type="Texture" id=(\d+)\]',scene)}
 block=scene.split('[node name="Sprite"',1)[1].split('\n[node ',1)[0]
 ident=re.search(r'^texture = ExtResource\( (\d+) \)',block,re.M)[1]
 return refs[ident]

def texture_metadata(pck,path):
 imported=pck.read(path+'.import').decode('utf-8');texture=re.search(r'path="([^\"]+\.stex)"',imported)[1]
 raw=pck.read(texture);assert raw[:4]==b'GDST',texture
 width,custom_width,height,custom_height=struct.unpack_from('<4H',raw,4)
 return {'source':path,'textureSource':texture,'textureMd5':pck.entries[texture]['md5'],'widthPoints':custom_width or width,'heightPoints':custom_height or height}

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
 spec=importlib.util.spec_from_file_location('jungle_art_source',ROOT/'tools/character-source.py');source=importlib.util.module_from_spec(spec);spec.loader.exec_module(source)
 pck=source.Pck();reference=source.verify_reference(pck)
 data=json.loads((ROOT/'docs/characters/jungle-walkers-source.json').read_text(encoding='utf-8'))
 folder=ROOT/'assets/enemies/native-jungle';folder.mkdir(parents=True,exist_ok=True)
 selected=[]
 for identity,row in data['enemies'].items():
  selected.append((identity,body_texture(pck,row['source'])))
 pillar='res://projectiles/pillar_enemy/pillar_projectile.tscn'
 for path in re.findall(r'\[ext_resource path="([^"]+\.png)" type="Texture"',pck.read(pillar).decode('utf-8')):
  selected.append(('Pillar_'+Path(path).stem,path))
 manifest={'version':reference['version'],'steamBuild':reference['steamBuildId'],'uploadedCount':0,'runtimeAssetIdsChanged':False,'originalArtAcceptedInGame':False,'frames':[]}
 for identity,path in selected:
  metadata=texture_metadata(pck,path);texture=metadata['textureSource']
  raw=pck.read(texture)
  image=Image.open(io.BytesIO(raw[raw.index(b'RIFF'):])).convert('RGBA');out=io.BytesIO();image.save(out,format='PNG');png=out.getvalue()
  output=folder/(identity+'.png')
  if args.check:assert output.read_bytes()==png,'Stale local Jungle image: '+identity
  else:output.write_bytes(png)
  assert Image.open(io.BytesIO(png)).convert('RGBA').tobytes()==image.tobytes()
  manifest['frames'].append({'id':identity,'source':path,'textureSource':texture,'textureMd5':pck.entries[texture]['md5'],'output':output.relative_to(ROOT).as_posix(),'size':list(image.size),'alphaBounds':list(image.getbbox()),'rgbaSha256':hashlib.sha256(image.tobytes()).hexdigest(),'pngSha256':hashlib.sha256(png).hexdigest()})
 text=json.dumps(manifest,indent=2)+'\n';path=folder/'manifest.json'
 if args.check:assert path.read_text(encoding='utf-8')==text,'Stale Jungle image manifest'
 else:path.write_text(text,encoding='utf-8')
 print(str(len(selected))+' native Jungle body/pillar frames prepared locally; no uploads or runtime identifiers changed')
if __name__=='__main__':main()
