"""Compile the concrete normal Diplodocus with finite Alamosaurus spawning and its independent slash child."""
from __future__ import annotations
import argparse,importlib.util,json,subprocess,sys,tempfile
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,ROOT/path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def generate():
    source=module('diplo_source','tools/character-source.py');scene=module('diplo_scene','tools/build-character-pets.py');art=module('diplo_art','tools/prepare-character-jungle-art.py')
    pck=source.Pck();reference=source.verify_reference(pck)
    facts=json.loads((ROOT/'docs/characters/boss-phases-source.json').read_text(encoding='utf-8'));actor=facts['actors']['Diplodocus'];path=actor['source']
    assert facts['version']==reference['version'] and facts['steamBuild']==int(reference['steamBuildId']),'Boss profile reference mismatch'
    for entry in facts['ruleSources']:assert pck.entries[entry['source']]['md5']==entry['sourceMd5'],'Rebuild audited boss profiles first'
    assert pck.entries[path]['md5']==actor['sourceMd5']
    cache,chain={},[]
    def resolve(path):
        d=scene.read_scene(pck,path);cache[path]=d;chain.append(path)
        nodes=resolve(d['baseScene']) if d.get('baseScene') else {}
        nodes={k:{'properties':dict(v['properties']),'scriptSource':v.get('scriptSource')} for k,v in nodes.items()}
        for n in d['nodes']:
            key=(n['parent'] or '@',n['name'] if n['parent'] else '@');before=nodes.get(key,{})
            nodes[key]={'scriptSource':n.get('scriptSource') or before.get('scriptSource'),'properties':{**before.get('properties',{}),**n['properties']}}
        return nodes
    nodes=resolve(path);root=nodes[('@','@')]
    assert root['scriptSource']=='res://entities/units/enemies/jungle/elites/diplodocus/diplodocus.gd'
    assert root['properties']['can_be_boosted'] is False
    movement=nodes[('.','MovementBehavior')]
    assert movement['scriptSource']=='res://entities/units/movement_behaviors/follow_target_movement_behavior.gd'
    assert not movement['properties'].get('should_target_vertically',False) and not movement['properties'].get('stop_close_to_target',False),'Re-audit root shoot_in_unit_direction target'
    phases=module('diplo_phases','tools/build-character-boss-phases.py')
    raw=pck.read(path).decode();rootAttack=phases.node_properties(raw,path,source,'AttackBehavior','.')
    basePath='res://entities/units/enemies/bosses/boss_state.tscn';baseRaw=pck.read(basePath).decode()
    baseAttack=phases.node_properties(baseRaw,basePath,source,'AttackBehavior','.')
    childAttack=phases.node_properties(raw,path,source,'AttackBehavior','States/State1')
    childMovement=phases.node_properties(baseRaw,basePath,source,'MovementBehavior','.')
    assert childMovement['script']['resource']==movement['scriptSource']
    assert rootAttack['script']['resource']=='res://entities/units/enemies/attack_behaviors/spawning_attack_behavior.gd'
    assert rootAttack['enemy_to_spawn']['resource']=='res://entities/units/enemies/jungle/basic/alamosaurus/alamosaurus.tscn'
    assert rootAttack['max_nb_of_spawns']==999 and rootAttack['spawn_random_pos_area']==-1 and not rootAttack['spawn_at_random_pos'] and not rootAttack['spawn_at_player_range']
    assert baseAttack['script']['resource']=='res://entities/units/enemies/attack_behaviors/shooting_attack_behavior.gd'
    assert childAttack['projectile_scene']['resource']=='res://projectiles/slash/slash_projectile.tscn' and 'script' not in childAttack
    defaults={'damage':1,'min_range':0,'random_rotation':0,'speed_change_after_each_projectile':0,'constant_spread':False,'move_locked':False,'recovery_cooldown':0,'projectile_speed_randomization':0,'use_transform_offset':False,'spawn_projectiles_on_target':False,'projectile_spawn_only_on_borders':False,'shoot_from_proj_pos_towards_player':False,'parallel_slashes':False}
    child={**defaults,**baseAttack,**childAttack}
    assert child['shoot_in_unit_direction'] and not any(child[k] for k in ['move_locked','recovery_cooldown','projectile_speed_randomization','use_transform_offset','spawn_projectiles_on_target','projectile_spawn_only_on_borders','shoot_from_proj_pos_towards_player','parallel_slashes'])
    hashes={'res://entities/units/enemies/attack_behaviors/spawning_attack_behavior.gdc':'cbddd1b76bf3363315729d319a34798d','res://singletons/utils.gdc':'2c263b6d3c2355dd71d6ad4caf0705bf'}
    for p,h in hashes.items():assert pck.entries[p]['md5']==h,'Re-audit finite spawning rules'
    def circle(nodes,parent):
        props=nodes[(parent,'Collision')]['properties'];file,ident=props['shape']['resource'].split('::');shape=cache[file]['shapes'][ident]
        assert shape['resourceType']=='CircleShape2D'
        offset=props.get('position',{}).get('values',[0,0])
        if parent!='.':
            pp=nodes[('.',parent)]['properties'];assert pp.get('scale',{}).get('values',[1,1])==[1,1]
            offset=[a+b for a,b in zip(offset,pp.get('position',{}).get('values',[0,0]))]
        return {'radiusPoints':shape['properties']['radius'],'offsetPoints':offset}
    body,hurt,hit=circle(nodes,'.'),circle(nodes,'Hurtbox'),circle(nodes,'Hitbox')
    statsPath=root['properties']['stats']['resource'];stats={k:v for k,v in pck.resource(statsPath)['properties'].items() if isinstance(v,(int,float,bool))}
    projectile=child['projectile_scene']['resource']
    return {'version':reference['version'],'steamBuild':int(reference['steamBuildId']),'source':path,'sourceMd5':actor['sourceMd5'],
        'sceneChain':[{'source':p,'sourceMd5':pck.entries[p]['md5']} for p in chain],
        'statsSource':statsPath,'statsMd5':pck.entries[statsPath]['md5'],'stats':stats,'body':body,'hurt':hurt,'hit':hit,
        'mass':root['properties'].get('mass',1),'bodyLayer':root['properties']['collision_layer'],'bodyMask':root['properties']['collision_mask'],'bodyBorders':root['properties'].get('should_collide_with_borders',True),
        'sprite':art.texture_metadata(pck,art.body_texture(pck,path)),
        'normalProjectile':{'source':projectile,'sourceMd5':pck.entries[projectile]['md5']},
        'ruleSources':[{'source':p,'sourceMd5':h} for p,h in hashes.items()],
        'phaseBaseScene':basePath,'phaseBaseSceneMd5':pck.entries[basePath]['md5'],
        'spawn':{k:v for k,v in rootAttack.items() if isinstance(v,(int,float,bool))},'phaseAttack':child,'exhaustedFrames':99999999,
        'bossInit':{'earlyWave':8,'middleWave':12,'endWave':20,'firstHpShare':0.5,'middleHpShare':0.75,'middleDamageShare':0.75,'easyZoneHpShare':0.9,'timerSeconds':1},
        'normalActorRegistered':True,'evolutionProfilesImplemented':False,'nativeFullParityAccepted':False}
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args();data=generate();catalog=module('diplo_catalog','tools/build-character-catalog.py')
    text='--!strict\n-- Concrete normal Diplodocus elite; EnemySim owns its native shared-animation controller and source phase transitions.\nlocal POINT=require(script.Parent.Stats).range.studsPerPoint\nlocal C=require(script.Parent.NativeBossPhases)\nlocal J=require(script.Parent.JungleWalkers)\nlocal data='+catalog.luau(data)+'''
local s=data.stats
local root=data.spawn
local a=data.phaseAttack
local clock=C.shootingClockRules
local shooting={frameRate=clock.frameRate,minimumCooldownFrames=clock.minimumCooldownFrames,
 fireAt=clock.animationFireAt,animationSeconds=clock.animationSeconds,
 profiles={{cooldown=root.cooldown,randomization=root.max_cd_randomization,initial=0,longEvery=0,longFrames=0,
 animationSpeed=root.attack_anim_speed,minRange=0,maxRange=0,unrestricted=true,
 spawnLimit=root.max_nb_of_spawns,exhaustedFrames=data.exhaustedFrames},
 {cooldown=a.cooldown,randomization=a.max_cd_randomization,initial=a.initial_cooldown,
 longEvery=a.long_cooldown_every_x_shoots,longFrames=a.long_cooldown,animationSpeed=a.attack_anim_speed,
 minRange=a.min_range*POINT,maxRange=a.max_range*POINT}}}
data.controller={family='Diplodocus',shooting=shooting,phases=C.actors.Diplodocus,init=data.bossInit,
 projectileDamage=a.damage,
 attacks={{kind='Spawn',summon={enemy='Alamosaurus',count=root.nb_to_spawn,area=root.spawn_in_radius_around_unit*POINT},minimumCount=1},
 {kind='NormalSlash',speed=a.projectile_speed*POINT,volley={count=a.number_projectiles,spread=a.projectile_spread,constantSpread=a.constant_spread,
 offsetX=0,offsetZ=0,speedStep=a.speed_change_after_each_projectile*POINT,spawnSquare=a.projectile_spawn_spread*POINT,baseAimFromSpawn=true}}}}
data.kind={
 id='Diplodocus',typeId=74,displayName='Diplodocus',look='Brute',nativeArtPending=true,
 nativeZoneId=J.zoneId,nativeScene=data.source,specialSpawn=true,nativeBoss=data.controller,
 hp=s.health,hpPerWave=s.health_increase_each_wave,contactDamage=s.damage,damagePerWave=s.damage_increase_each_wave,
 speed=s.speed*POINT,nativeSpeedPoints={base=s.speed,randomization=s.speed_randomization},xp=s.value,
 shotDamagePerWave=a.damage_increase_each_wave,
 radius=data.body.radiusPoints*POINT,hurtRadius=data.hurt.radiusPoints*POINT,hitRadius=data.hit.radiusPoints*POINT,
 nativeBodyOffsetX=data.body.offsetPoints[1]*POINT,nativeBodyOffsetZ=data.body.offsetPoints[2]*POINT,
 nativeHurtOffsetX=data.hurt.offsetPoints[1]*POINT,nativeHurtOffsetZ=data.hurt.offsetPoints[2]*POINT,
 nativeHitOffsetX=data.hit.offsetPoints[1]*POINT,nativeHitOffsetZ=data.hit.offsetPoints[2]*POINT,
 nativeBodyLayer=data.bodyLayer,nativeBodyMask=data.bodyMask,nativeObstacleCollision=bit32.band(data.bodyMask,128)~=0,
 nativeMovement={borderClamp=data.bodyBorders,goalInsetX=data.sprite.widthPoints*POINT/2,goalInsetZ=data.sprite.heightPoints*POINT/2,precision=J.spawningRules.goalPrecisionPoints*POINT,collidePlayers=bit32.band(data.bodyMask,2)~=0},
 mass=data.mass,knockbackResistance=s.knockback_resistance,nativeArmor={base=s.armor,perWave=s.armor_increase_each_wave},
 nativeHealthRounding=true,nativeDamageRounding=true,nativeCanBeBoosted=false,nativeCanBeCharmed=false,
 loot={consumableChance=s.base_drop_chance,crateShare=s.item_drop_chance,crate=true,alwaysOrbs=true},
}
return data
'''
    with tempfile.TemporaryDirectory(dir=ROOT/'build') as folder:
        p=Path(folder)/'NativeDiplodocus.luau';p.write_text(text,encoding='utf-8');subprocess.run(['stylua',str(p)],check=True);subprocess.run(['stylua',str(p)],check=True);text=p.read_text(encoding='utf-8')
    for p,v in {ROOT/'docs/characters/diplodocus-source.json':json.dumps(data,indent=2)+'\n',ROOT/'src/shared/Config/NativeDiplodocus.luau':text}.items():
        if args.check:assert p.read_text(encoding='utf-8')==v,'Stale Diplodocus source: '+str(p)
        else:p.write_text(v,encoding='utf-8',newline='\n')
    print('Normal Diplodocus elite compiled; evolution and complete area acceptance remain open')
if __name__=='__main__':main()
