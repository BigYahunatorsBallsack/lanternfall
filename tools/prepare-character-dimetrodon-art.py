"""Prepare the bound Dimetrodon body, jump shadow and landing-warning PNGs; local files only."""
from __future__ import annotations
import argparse, hashlib, importlib.util, io, json, re, sys
from pathlib import Path
from PIL import Image
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
def module(name,path):
 spec=importlib.util.spec_from_file_location(name,ROOT/path);result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
 source=module('dimetrodon_art_source','tools/character-source.py');art=module('dimetrodon_art_helpers','tools/prepare-character-jungle-art.py')
 pck=source.Pck();reference=source.verify_reference(pck)
 scenePath='res://entities/units/enemies/jungle/basic/dimetrodon/dimetrodon.tscn'
 scene=pck.read(scenePath).decode('utf-8');refs={i:path for path,i in re.findall(r'\[ext_resource path="([^\"]+)" type="Texture" id=(\d+)\]',scene)}
 selected=[('Dimetrodon','Sprite'),('DimetrodonShadow','Shadow'),('DimetrodonLandingWarning','Land_shadow_warning')]
 folder=ROOT/'assets/enemies/native-dimetrodon'
 if not args.check:folder.mkdir(parents=True,exist_ok=True)
 manifest={'version':reference['version'],'steamBuild':reference['steamBuildId'],'sceneSource':scenePath,'sceneMd5':pck.entries[scenePath]['md5'],'uploadedCount':0,'runtimeAssetIdsChanged':False,'originalArtAcceptedInGame':False,'frames':[]}
 for identity,node in selected:
  block=scene.split('[node name="'+node+'"',1)[1].split('\n[node ',1)[0]
  ident=re.search(r'^texture = ExtResource\( (\d+) \)',block,re.M)[1];path=refs[ident]
  metadata=art.texture_metadata(pck,path);raw=pck.read(metadata['textureSource'])
  image=Image.open(io.BytesIO(raw[raw.index(b'RIFF'):])).convert('RGBA');out=io.BytesIO();image.save(out,format='PNG');png=out.getvalue();output=folder/(identity+'.png')
  if args.check:assert output.read_bytes()==png,'Stale Dimetrodon image: '+identity
  else:output.write_bytes(png)
  assert Image.open(io.BytesIO(png)).convert('RGBA').tobytes()==image.tobytes()
  manifest['frames'].append({'id':identity,**metadata,'output':output.relative_to(ROOT).as_posix(),'size':list(image.size),'alphaBounds':list(image.getbbox()),'rgbaSha256':hashlib.sha256(image.tobytes()).hexdigest(),'pngSha256':hashlib.sha256(png).hexdigest()})
 value=json.dumps(manifest,indent=2)+'\n';path=folder/'manifest.json'
 if args.check:assert path.read_text(encoding='utf-8')==value,'Stale Dimetrodon art manifest'
 else:path.write_text(value,encoding='utf-8',newline='\n')
 print('3 bound Dimetrodon frames prepared locally; no uploads or runtime identifiers changed')
if __name__=='__main__':main()
