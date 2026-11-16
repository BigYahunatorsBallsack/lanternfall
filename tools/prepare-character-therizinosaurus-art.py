"""Prepare the bound Therizinosaurus body PNG locally without uploads or runtime asset identifiers."""
from __future__ import annotations
import argparse, hashlib, importlib.util, io, json, sys
from pathlib import Path
from PIL import Image
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
 spec=importlib.util.spec_from_file_location('theri_art_source',ROOT/'tools/character-source.py');source=importlib.util.module_from_spec(spec);spec.loader.exec_module(source)
 pck=source.Pck();reference=source.verify_reference(pck)
 facts=json.loads((ROOT/'docs/characters/therizinosaurus-source.json').read_text(encoding='utf-8'))
 assert facts['version']==reference['version']
 texture=facts['sprite']['textureSource'];raw=pck.read(texture)
 assert pck.entries[texture]['md5']==facts['sprite']['textureMd5']
 image=Image.open(io.BytesIO(raw[raw.index(b'RIFF'):])).convert('RGBA');output=io.BytesIO();image.save(output,format='PNG');png=output.getvalue()
 assert Image.open(io.BytesIO(png)).convert('RGBA').tobytes()==image.tobytes()
 folder=ROOT/'assets/enemies/native-therizinosaurus';path=folder/'Therizinosaurus.png'
 manifest={'version':reference['version'],'steamBuild':reference['steamBuildId'],'source':facts['source'],'sourceMd5':facts['sourceMd5'],'textureSource':texture,'textureMd5':pck.entries[texture]['md5'],'output':path.relative_to(ROOT).as_posix(),'size':list(image.size),'alphaBounds':list(image.getbbox()),'rgbaSha256':hashlib.sha256(image.tobytes()).hexdigest(),'pngSha256':hashlib.sha256(png).hexdigest(),'uploadedCount':0,'runtimeAssetIdsChanged':False,'originalArtAcceptedInGame':False}
 text=json.dumps(manifest,indent=2)+'\n'
 if args.check:
  assert path.read_bytes()==png,'Stale local Therizinosaurus PNG'
  assert (folder/'manifest.json').read_text(encoding='utf-8')==text,'Stale Therizinosaurus art manifest'
 else:
  folder.mkdir(parents=True,exist_ok=True);path.write_bytes(png);(folder/'manifest.json').write_text(text,encoding='utf-8',newline='\n')
 print('Therizinosaurus body prepared locally; no uploads or runtime asset IDs changed')
if __name__=='__main__':main()
