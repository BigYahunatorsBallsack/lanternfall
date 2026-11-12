"""Compile native fog light data and prepare its texture locally, without asset uploads."""
import argparse
import hashlib
import importlib.util
import io
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from PIL import Image

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
# Script identities captured from the original 1.2.0.1 recovery before Steam's 1.2.0.2 update.
ORIGINAL_SCRIPTS = {
    'res://visual_effects/fog_viewport.gdc': '92b0c65d331d391bf44ef76c0d990d0e',
    'res://main.gdc': '903bd37107ab9c164addda2167477fb1',
    'res://particles/burning/burning_particles.gdc': '022970f9405dc39c1bdd570e58a40555',
    'res://entities/units/unit/unit.gdc': 'aa94391f2d9681ac36b7f8617b82ff13',
    'res://entities/gpe/fire_puddle/fire_puddle.gdc': 'a31c18617860b08b845c0c5d82430604',
}


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    source = module('fog_source', ROOT / 'tools/character-source.py')
    compiler = module('fog_catalog', ROOT / 'tools/build-character-catalog.py')
    scenes = module('fog_scenes', ROOT / 'tools/build-character-bullet-hell.py')
    pck = source.Pck()
    literals = {v.decode() for v in re.findall(rb'[ -~]{4,}', pck.read('res://singletons/progress_data.gdc')) if re.fullmatch(rb'1\.\d+\.\d+\.\d+', v)}
    installed_version = max(literals, key=lambda value: tuple(map(int, value.split('.'))))
    steam_manifest = pck.path.parent.parent.parent / 'appmanifest_1942280.acf'
    installed_build = int(re.search(r'"buildid"\s*"(\d+)"', steam_manifest.read_text(encoding='utf-8'))[1])
    if installed_version != '1.2.0.1':
        original_version = ROOT / 'build/character-source/native/.autoconverted/singletons/progress_data.gdc'
        assert hashlib.md5(original_version.read_bytes()).hexdigest() == '2da3ced0fea7d9f82a41ac55f26082b6', 'Original version cache changed'
        assert b'1.2.0.1' in original_version.read_bytes(), 'Original version evidence missing'
    lights = {}
    sources = ['res://visual_effects/fog_viewport.gdc', 'res://visual_effects/shader_noise_displacement_add.tres', 'res://main.tscn', 'res://main.gdc', 'res://particles/burning/burning_particles.gdc', 'res://entities/units/unit/unit.gdc', 'res://entities/gpe/fire_puddle/fire_puddle.gdc']
    for kind, name in [('player', 'player_light_in_shadow'), ('fire', 'elemental_light_in_shadow'), ('structure', 'structure_and_pet_light_in_shadow')]:
        path = f'res://visual_effects/{name}.tscn'
        sources.append(path)
        text = pck.read(path).decode('utf-8')
        header = text.split('\n[node ')[0].replace('[gd_scene', '[gd_resource type="PackedScene"', 1) + '\n[resource]\n'
        resources = source.parse_tres(header, path)['subresources']
        _, nodes = scenes.scene(pck, path)
        layers = []
        rotations = []
        pulse = None
        for node in nodes:
            props = node['properties']
            if 'texture' in props:
                color = source.ValueParser(props.get('self_modulate', 'Color( 1, 1, 1, 1 )')).parse()['values']
                scale = source.ValueParser(props.get('scale', 'Vector2( 1, 1 )')).parse()['values']
                layers.append({'scale': scale, 'color': color})
            animation = props.get('"anims/New Anim"')
            if animation:
                animation = resources[re.search(r'\d+', animation)[0]]['properties']
                track = animation['tracks/0/path']
                keys = animation['tracks/0/keys']
                if 'rotation_degrees' in str(track):
                    rotations.append({'length': animation['length'], 'keyEnd': keys['times'][-1]})
                elif 'scale' in str(track):
                    pulse = {'length': animation['length'], 'times': keys['times'], 'values': [v['values'][0] for v in keys['values']], 'interpolation': animation['tracks/0/interp']}
        # Animation nodes are listed deepest child first, so match sprite hierarchy in reverse.
        for layer, rotation in zip(layers, reversed(rotations)):
            layer['rotation'] = rotation
        lights[kind] = {'layers': layers, 'pulse': pulse, 'warp': {k: v for k, v in resources['1']['properties'].items() if k.startswith('shader_param/wave_')}}
    icon = 'res://visual_effects/player_light_in_shadow.png'
    imported = pck.read(icon + '.import').decode('utf-8')
    texture = re.search(r'path="([^"]+\.stex)"', imported)[1]
    raw = pck.read(texture)
    assert raw[:4] == b'GDST'
    image = Image.open(io.BytesIO(raw[raw.index(b'RIFF'):])).convert('RGBA')
    assert image.size == (512, 512)
    local = ROOT / 'assets/characters/native-fog'
    local.mkdir(parents=True, exist_ok=True)
    output = io.BytesIO()
    image.save(output, format='PNG')
    mask = image.getchannel('R').resize((128, 128), Image.Resampling.BILINEAR)
    provenance = []
    for path in sources:
        installed_md5 = pck.entries[path]['md5']
        expected = ORIGINAL_SCRIPTS.get(path)
        row = {'source': path, 'sourceMd5': installed_md5}
        if expected:
            if installed_md5 != expected:
                cached = ROOT / 'build/character-source/native/.autoconverted' / path.removeprefix('res://')
                assert hashlib.md5(cached.read_bytes()).hexdigest() == expected, f'Missing original 1.2.0.1 script: {path}'
                row.update(sourceMd5=expected, origin='verified original bytecode cache', installedMd5=installed_md5)
            else:
                row['origin'] = 'installed bytes match original 1.2.0.1 hash'
        else:
            row['origin'] = 'installed visual candidate; original 1.2.0.1 identity unverified' if installed_version != '1.2.0.1' else 'original installed 1.2.0.1 visual'
        provenance.append(row)
    facts = {'targetVersion': '1.2.0.1', 'targetSteamBuild': 26406319,
             'installedVisualCandidateVersion': installed_version, 'installedSteamBuild': installed_build,
             'originalRulesVerified': True, 'originalVisualIdentitiesVerified': installed_version == '1.2.0.1',
             'sources': provenance,
             'rules': {'viewport': [1920, 1080], 'waveCap': 20, 'waveScaleBase': 2.75, 'waveScaleLoss': 1.75, 'visibilityMin': -100, 'visibilityMax': 9999, 'fadeSeconds': 0.25, 'explosionHoldSeconds': 0.25, 'permanentLossBase': 15, 'permanentLossPerWave': 1.5, 'permanentLossMax': 45},
             'lights': lights,
             'runtimeCompatibility': {'maskSize': 128, 'renderHeight': 108, 'fallbackHeight': 36, 'updatesPerSecond': 10, 'displayOrder': -2, 'nativeTextureSize': 512,
                                      'nativeGraphicsAccepted': False, 'openGraphics': ['OpenSimplex UV displacement', 'per-channel colored multiply', 'native animation/process ordering', 'native resolution and device performance', 'burning-emitter native position offsets and snapshot latency']}}
    manifest = {'source': icon, 'textureSource': texture, 'textureMd5': pck.entries[texture]['md5'], 'installedVersion': installed_version, 'installedSteamBuild': installed_build, 'original1201IdentityVerified': installed_version == '1.2.0.1', 'size': list(image.size), 'rgbaSha256': hashlib.sha256(image.tobytes()).hexdigest(), 'pngSha256': hashlib.sha256(output.getvalue()).hexdigest(), 'uploadedCount': 0, 'runtimeAssetIdsChanged': False}
    outputs = {ROOT / 'docs/characters/fog-source.json': json.dumps(facts, indent=2) + '\n', local / 'manifest.json': json.dumps(manifest, indent=2) + '\n',
               ROOT / 'src/shared/Config/NativeFog.luau': '--!strict\n-- Verified original fog rules plus explicitly unverified visual candidates after Steam updated; consumed by fog rules and renderer.\nreturn ' + compiler.luau(facts) + '\n',
               ROOT / 'src/shared/Config/NativeFogMask.luau': '--!strict\n-- Local grayscale light candidate, reduced to 128 square; original 1.2.0.1 texture identity remains unverified. Consumed by NativeFogRaster, never uploaded.\nreturn "' + mask.tobytes().hex() + '"\n'}
    for path, text in outputs.items():
        if path.suffix == '.luau':
            with tempfile.TemporaryDirectory(dir=ROOT / 'build') as temp:
                candidate = Path(temp) / path.name
                candidate.write_text(text, encoding='utf-8')
                subprocess.run(['stylua', str(candidate)], check=True)
                text = candidate.read_text(encoding='utf-8')
        if args.check:
            assert path.read_text(encoding='utf-8') == text, f'Stale fog facts: {path}'
        else:
            path.write_text(text, encoding='utf-8', newline='\n')
    png = local / 'native-light.png'
    if args.check:
        assert png.read_bytes() == output.getvalue(), 'Stale native fog texture'
    else:
        png.write_bytes(output.getvalue())
    print(f'Original 1.2.0.1 fog rules pinned; installed visual candidates {installed_version}/build{installed_build}; original visual identities and graphics acceptance remain open')


if __name__ == '__main__':
    main()
