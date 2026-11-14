"""Compile original Pachycephalosaurus charge/deflection facts; no actor or area activation."""
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


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    source = module('deflect_source', 'tools/character-source.py')
    scenes = module('deflect_scenes', 'tools/build-character-pets.py')
    catalog = module('deflect_catalog', 'tools/build-character-catalog.py')
    pck = source.Pck()
    reference = source.verify_reference(pck)
    path = 'res://entities/units/enemies/jungle/basic/pachycephalosaurus/pachycephalosaurus.tscn'
    scene = scenes.read_scene(pck, path)
    defaults = dict(cooldown=60.0, max_cd_randomization=10, min_range=0, max_range=300,
                    range_X=-1, range_Y=-1, attack_anim_speed=1.0, charge_duration=1.0,
                    charge_speed=500.0, target_calculation_timing=0, target=0,
                    rand_target_size=-1, only_positions_in_target_direction=False,
                    scale_charge_duration_with_range=False, recovery_duration=0.05,
                    long_cooldown_every_x_shoots=0, long_cooldown=0.0, deflect_stop_before_CD=20.0)
    behavior = 'res://entities/units/enemies/attack_behaviors/charging_attack_deflect_bullet_behavior.gd'
    variants = {}
    for variant in ['Normal', 'Mutant', 'Meca']:
        node = next(n for n in scene['nodes'] if n['name'] == 'AttackBehavior' + variant)
        assert node['scriptSource'] == behavior
        values = {k: v for k, v in node['properties'].items() if isinstance(v, (int, float, bool))}
        variants[variant] = {**defaults, **values}
    normal = variants['Normal']
    assert normal['target'] == 1 and normal['target_calculation_timing'] == 1
    assert normal['only_positions_in_target_direction'] and not normal['scale_charge_duration_with_range']
    assert normal['long_cooldown_every_x_shoots'] == 0
    base = json.loads((ROOT / 'docs/characters/jungle-around-charge-source.json').read_text(encoding='utf-8'))
    assert base['version'] == reference['version'] and int(base['steamBuild']) == int(reference['steamBuildId'])
    scripts = [behavior.removesuffix('.gd')+'.gdc', base['source'], base['rangeHelper']['source'],
               'res://entities/units/enemies/jungle/basic/pachycephalosaurus/pachycephalosaurus.gdc',
               'res://projectiles/player_projectile.gdc', 'res://projectiles/boomerang/boomerang_projectile.gdc',
               'res://weapons/ranged/ranged_weapon.gdc', 'res://weapons/melee/melee_weapon.gdc',
               'res://entities/structures/structure.gdc', 'res://entities/structures/turret/turret.gdc',
               'res://entities/structures/dart_trap/dart_trap.gdc',
               'res://global/entity_spawner.gdc',
               'res://projectiles/grenade_mine/grenade_mine_projectile.gdc',
               'res://projectiles/player_explosion.gdc', 'res://overlap/hitbox.gdc',
               'res://singletons/weapon_service.gdc', 'res://entities/units/unit/unit.gdc',
               'res://entities/units/pet/pet.gdc',
               'res://entities/units/pet/catling_gun/catling_gun.gdc',
               'res://entities/units/pet/blazemander/blazemander.gdc',
               'res://entities/units/pet/bot_o_mine/bot_o_mine.gdc',
               'res://entities/units/enemies/crash_zone/basic/fly/fly.gdc',
               'res://entities/units/enemies/crash_zone/basic/horned_fly/horned_fly.gdc']
    assert pck.entries[base['source']]['md5'] == base['sourceMd5']
    animation = base['animation']
    assert pck.entries[animation['source']]['md5'] == animation['sourceMd5']
    pet_origins = {}
    for slug in ['catling_gun', 'blazemander', 'bot_o_mine']:
        pet_path = f'res://entities/units/pet/{slug}/{slug}.tscn'
        pet_scene = scenes.read_scene(pck, pet_path)
        root = next(n['properties'] for n in pet_scene['nodes'] if n['parent'] is None)
        assert isinstance(root['shoot_projectiles'], bool), pet_path
        pet_origins[slug] = dict(source=pet_path, sourceMd5=pck.entries[pet_path]['md5'],
                                 shootProjectiles=root['shoot_projectiles'])
    facts = dict(version=reference['version'], steamBuild=int(reference['steamBuildId']),
                 source=path, sourceMd5=pck.entries[path]['md5'], variants=variants,
                 frameRate=base['frameRate'], minimumCooldownFrames=base['minimumCooldownFrames'],
                 massMultiplier=base['massMultiplier'], animation=animation,
                 projectileBounce=dict(rangePoints=10000, additionalDistancePoints=100,
                                       manualAimAdditionalDistancePoints=50, globalTargets=True,
                                       includesCharmed=True, includesBosses=False),
                 around=base['around'], ruleSources=[dict(source=s, sourceMd5=pck.entries[s]['md5']) for s in scripts],
                 actorRegistered=True, normalActorRegistered=True, normalProjectileDefenseConnected=True, projectileDefenseConnected=False, evolutionVariantsImplemented=False,
                 nativeProjectileInterceptionConnected=True,
                 defenseExceptions=dict(stickyFlightHitboxEnabled=False, explosionOriginIsSelf=True,
                                        explosionFactorySetsOriginBeforeStart=True),
                 priorHitDefenseReentryImplemented=True,
                 nativePetProjectileInterceptionConnected=True,
                 boomerangProjectileInterceptionConnected=True,
                 ordinaryStructureIsPet=False, ordinaryStructureIsRangedWeapon=False, meleeSecondaryOriginIsMeleeWeapon=True,
                 boomerangDefense=dict(phasePathUnchanged=True, velocityRemainsZero=True,
                                       rotationUsesZeroVelocityAngle=True, ownFlightDeadlineUnchanged=True,
                                       damageAndKnockbackUseInheritedBounce=True),
                 petProjectileOrigins=pet_origins,
                 scope='Native ranged weapon and source-flagged pet projectile defense with rotated collision offsets; Blazemander flames, Sticky flight and explosion exceptions audited. Boomerang inherited bounce keeps its phase path and own deadline. Normal actor connected. Evolution, remaining producer/event-order parity and playable area remain pending.')
    text = '--!strict\n-- Original normal Pachycephalosaurus clock and native projectile-defense facts; evolution and full area acceptance remain pending.\n'
    text += 'local source = ' + catalog.luau(facts) + '\n'
    text += '''local target = table.clone(require(script.Parent.JungleChargeTargets).rule.target)
local pixel = require(script.Parent.Stats).range.studsPerPoint
local a = source.variants.Normal
target.radius = math.floor(math.min(source.around.maximumDefaultRadiusPoints, a.max_range / source.around.rangeDivisor)) * pixel
local rule = {
    cooldown = a.cooldown / source.frameRate,
    jitter = a.max_cd_randomization / source.frameRate,
    minimumCooldown = source.minimumCooldownFrames / source.frameRate,
    fireAt = source.animation.fireAt / a.attack_anim_speed,
    duration = a.charge_duration,
    recovery = a.recovery_duration,
    speed = a.charge_speed * pixel,
    rangeX = a.range_X * pixel,
    rangeZ = a.range_Y * pixel,
    minRange = a.min_range * pixel,
    maxRange = a.max_range * pixel,
    target = target,
    massMultiplier = source.massMultiplier,
    deflectStopBeforeCooldown = a.deflect_stop_before_CD / source.frameRate,
}
return { source = source, rule = rule }
'''
    with tempfile.TemporaryDirectory(dir=ROOT / 'build') as folder:
        temp = Path(folder) / 'JungleDeflectCharges.luau'
        temp.write_text(text, encoding='utf-8')
        subprocess.run(['stylua', str(temp)], check=True)
        text = temp.read_text(encoding='utf-8')
    outputs = {'docs/characters/jungle-deflect-charge-source.json': json.dumps(facts, indent=2)+'\n',
               'src/shared/Config/JungleDeflectCharges.luau': text}
    for name, value in outputs.items():
        output = ROOT / name
        if args.check:
            assert output.read_text(encoding='utf-8') == value, name
        else:
            output.write_text(value, encoding='utf-8', newline='\n')
    print('Normal Pachycephalosaurus and native defense connected; evolution and full area acceptance remain pending')


if __name__ == '__main__':
    main()
