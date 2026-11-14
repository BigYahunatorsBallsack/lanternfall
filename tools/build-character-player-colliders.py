"""Compile approved player collision facts without reading a newer installed PCK."""
from __future__ import annotations
import argparse
import importlib.util
import json
import subprocess
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    data = json.loads((ROOT / 'docs/characters/player-colliders-source.json').read_text(encoding='utf-8'))
    pets = json.loads((ROOT / 'docs/characters/pet-source.json').read_text(encoding='utf-8'))
    colliders = json.loads((ROOT / 'docs/characters/jungle-collider-offsets-source.json').read_text(encoding='utf-8'))
    ref = json.loads((ROOT / 'docs/characters/reference.json').read_text(encoding='utf-8'))
    assert data['version'] == pets['version'] == ref['version']
    assert int(data['steamBuild']) == int(ref['steamBuildId'])
    assert data['source'] == pets['playerBody']['source']
    assert data['sourceMd5'] == pets['playerBody']['sourceMd5']
    assert data['body']['radiusPoints'] == pets['playerBody']['radiusPoints']
    assert data['body']['totalPoints'] == [pets['playerBody']['offsetXPoints'], pets['playerBody']['offsetZPoints']]
    chain = data['sceneChain']
    assert chain[0] == data['source'] and len(set(chain)) == len(chain)
    for i, path in enumerate(chain):
        scene = data['scenes'][path]
        expected = data['sourceMd5'] if i == 0 else colliders['scenes'][path]['sourceMd5']
        assert scene['sourceMd5'] == expected, path
        assert scene.get('baseScene') == (chain[i + 1] if i + 1 < len(chain) else None), path
    for shape in ['body', 'hurt']:
        row = data[shape]
        assert row['radiusPoints'] > 0
        assert row['initialParentScale'] == row['initialChildScale'] == [1, 1]
        assert row['initialParentRotation'] == row['initialChildRotation'] == 0
        assert row['totalPoints'] == [a + b for a, b in zip(row['parentPoints'], row['childPoints'])]
    spec = importlib.util.spec_from_file_location('player_catalog', ROOT / 'tools/build-character-catalog.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    with tempfile.TemporaryDirectory(dir=ROOT / 'build') as folder:
        temp = Path(folder) / 'PlayerColliders.luau'
        temp.write_text('--!strict\n-- Approved native player body and hurt-circle facts; PlayerHurtGeometry and Simulation read these independently.\nreturn ' + module.luau(data) + '\n', encoding='utf-8')
        subprocess.run(['stylua', str(temp)], check=True)
        text = temp.read_text(encoding='utf-8')
    path = ROOT / 'src/shared/Config/PlayerColliders.luau'
    if args.check:
        assert path.read_text(encoding='utf-8') == text, 'Stale compiled player collider snapshot'
    else:
        path.write_text(text, encoding='utf-8', newline='\n')
    print('Approved player body/hurt circles compiled; installed-version guard unchanged')


if __name__ == '__main__':
    main()
