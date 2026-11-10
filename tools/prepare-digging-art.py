"""Prepare native digging frames, item icon and Blood Turret locally; never upload or write runtime IDs."""
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import re
import sys
import subprocess
from PIL import Image

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('source', ROOT / 'tools/character-source.py')
source = importlib.util.module_from_spec(spec)
spec.loader.exec_module(source)
pck = source.Pck()
scene = pck.read('res://entities/gpe/dig_site/dig_site.tscn').decode('utf-8')
textures = dict((int(ident), path) for path, ident in re.findall(r'\[ext_resource path="([^"]+)" type="Texture" id=(\d+)\]', scene))
order = [int(ident) for ident in re.findall(r'ExtResource\(\s*(\d+)\s*\)', re.search(r'^textures = \[(.+)\]', scene, re.M)[1])]
records = []
entries = [(f'DigSite{n}', textures[ident], 'digging') for n, ident in enumerate(order)]
entries += [('DigSite', 'res://items/all/04_primal_dread/dig_site/dig_site_icon.png', 'items'),
            ('BloodTurret', 'res://entities/structures/turret/bleeding_turret/blood_turret.png', 'structures')]
listing = json.loads((ROOT / 'tools/art2d/sprites.json').read_text(encoding='utf-8'))
listing.setdefault('digging', {'title': 'Originale Dig-Site-Phasen', 'pixels': 512, 'raw': True, 'items': {}})
def read_texture(path, ident):
    imported = pck.read(path + '.import').decode('utf-8')
    target = re.search(r'path="([^"]+)"', imported)[1]
    if target.endswith('.res'):
        cached = ROOT / 'build/character-source/atlases' / (ident + '.res')
        marker = cached.with_suffix('.md5')
        if not cached.exists() or not marker.exists() or marker.read_text() != pck.entries[target]['md5']:
            cached.parent.mkdir(parents=True, exist_ok=True)
            cached.write_bytes(pck.read(target))
            subprocess.run([str(ROOT/'build/character-source/gdre/gdre_tools.exe'), '--headless',
                            '--bin-to-txt='+str(cached), '--output='+str(cached.parent)], check=True, timeout=20)
            marker.write_text(pck.entries[target]['md5'])
        resource = cached.read_text(encoding='utf-8')
        atlas = re.search(r'path="([^"]+)" type="Texture"', resource)[1]
        def rectangle(key):
            return [int(float(n.strip())) for n in re.search(key+r' = Rect2\( (.+) \)', resource)[1].split(',')]
        x, y, width, height = rectangle('region')
        mx, my, mw, mh = rectangle('margin')
        image, texture, _ = read_texture(atlas, ident+'Atlas')
        result = Image.new('RGBA', (width+mw, height+mh))
        result.alpha_composite(image.crop((x, y, x+width, y+height)), (mx, my))
        return result, texture, {'resource': target, 'resourceMd5': pck.entries[target]['md5'],
                                 'region': [x,y,width,height], 'margin': [mx,my,mw,mh]}
    raw = pck.read(target)
    return Image.open(io.BytesIO(raw[raw.index(b'RIFF'):])).convert('RGBA'), target, None
for ident, path, group in entries:
    decoded, texture, atlas_info = read_texture(path, ident)
    side = max(decoded.size)
    canvas = Image.new('RGBA', (side, side))
    canvas.alpha_composite(decoded, ((side-decoded.width)//2, (side-decoded.height)//2))
    target = ROOT / 'assets/world2d/final' / group / (ident + '.png')
    target.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(target)
    records.append({'id': ident, 'source': path, 'textureSource': texture, 'textureMd5': pck.entries[texture]['md5'],
                    'output': target.relative_to(ROOT).as_posix(), 'sourceSize': list(decoded.size),
                    'canvasSize': side, 'pngSha256': hashlib.sha256(target.read_bytes()).hexdigest(),
                    'sourceRgbaSha256': hashlib.sha256(decoded.tobytes()).hexdigest()})
    if atlas_info: records[-1]['atlas'] = atlas_info
    listing[group]['items'][ident] = {'text': 'Original Brotato: ' + ident, 'source': target.relative_to(ROOT).as_posix(), 'trimmed': True}
(ROOT / 'tools/art2d/sprites.json').write_text(json.dumps(listing, indent=1, ensure_ascii=False)+'\n', encoding='utf-8')
(ROOT / 'assets/world2d/final/digging/manifest.json').write_text(json.dumps({'version':'1.2.0.1','uploadedCount':0,'images':records},indent=2)+'\n',encoding='utf-8')
print([(r['id'], r['sourceSize'], r['canvasSize']) for r in records])
