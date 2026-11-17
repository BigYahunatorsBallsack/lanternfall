"""Compile normal Carnotaurus jump/landing shots and its custom landed-only timer switch."""
from __future__ import annotations
import argparse,importlib.util,json,subprocess,sys,tempfile
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,ROOT/path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def generate():
    source=module('carno_source','tools/character-source.py');scene=module('carno_scene','tools/build-character-pets.py');art=module('carno_art','tools/prepare-character-jungle-art.py')
    pck=source.Pck();reference=source.verify_reference(pck)
    facts=json.loads((ROOT/'docs/characters/boss-phases-source.json').read_text(encoding='utf-8'));actor=facts['actors']['Carnotaurus'];path=actor['source']
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
    assert root['scriptSource']=='res://entities/units/enemies/jungle/elites/carnotaurus/carnotaurus.gd'
    assert root['properties']['can_be_boosted'] is False
    movement=nodes[('.','MovementBehavior')]
    assert movement['scriptSource']=='res://entities/units/movement_behaviors/follow_target_movement_behavior.gd'
    assert not movement['properties'].get('should_target_vertically',False) and not movement['properties'].get('stop_close_to_target',False),'Re-audit root shoot_in_unit_direction target'
    phases=module('carno_phases','tools/build-character-boss-phases.py')
    raw=pck.read(path).decode();jump=phases.node_properties(raw,path,source,'AttackBehavior','.')
    assert jump['script']['resource']=='res://entities/units/enemies/attack_behaviors/jump_attack_behavior.gd'
    basePath='res://entities/units/enemies/bosses/boss_state.tscn';baseRaw=pck.read(basePath).decode()
    base=phases.node_properties(baseRaw,basePath,source,'AttackBehavior','.')
    childMovement=phases.node_properties(baseRaw,basePath,source,'MovementBehavior','.')
    assert childMovement['script']['resource']==movement['scriptSource']
    defaults={'damage':1,'damage_increase_each_wave':1,'cooldown':60,'max_cd_randomization':10,'initial_cooldown':0,'long_cooldown_every_x_shoots':0,'long_cooldown':0,'attack_anim_speed':1,'min_range':0,'max_range':500,'number_projectiles':1,'random_rotation':0,'speed_change_after_each_projectile':0,'constant_spread':False,'move_locked':False,'recovery_cooldown':0,'projectile_speed_randomization':0,'use_transform_offset':False,'spawn_projectiles_on_target':False,'projectile_spawn_only_on_borders':False,'shoot_from_proj_pos_towards_player':False,'shoot_away_from_unit':False,'parallel_slashes':False,'delete_projectile_on_death':False,'projectile_spread':0,'projectile_spawn_spread':0}
    child={**defaults,**base,**phases.node_properties(raw,path,source,'AttackBehavior','States/State1')}
    land={**defaults,**phases.node_properties(raw,path,source,'LandShoot','.')}
    assert 'projectile_scene' not in child and 'projectile_scene' not in land
    assert land['script']['resource']==base['script']['resource']=='res://entities/units/enemies/attack_behaviors/shooting_attack_behavior.gd'
    assert child['damage']==land['damage'] and child['damage_increase_each_wave']==land['damage_increase_each_wave']
    assert child['delete_projectile_on_death'] and not land['delete_projectile_on_death']
    assert land['projectile_spawn_only_on_borders'] and land['constant_spread'] and land['shoot_away_from_unit']
    assert child['use_transform_offset'] and child['move_locked'] and not child['parallel_slashes'] and not child['projectile_spawn_only_on_borders']
    assert not any(child[k] for k in ['projectile_speed_randomization','shoot_from_proj_pos_towards_player','spawn_projectiles_on_target'])
    timer=phases.node_properties(raw,path,source,'CheckStateTimer','.')
    shadow=phases.node_properties(raw,path,source,'Shadow','AttackBehavior')
    warning=phases.node_properties(raw,path,source,'Land_shadow_warning','AttackBehavior')
    presentation={'shadow':shadow,'warning':warning,'shadowTexture':art.texture_metadata(pck,shadow['texture']['resource']),'warningTexture':art.texture_metadata(pck,warning['texture']['resource'])}
    hashes={'res://entities/units/enemies/attack_behaviors/jump_attack_behavior.gdc':'83970734202a9c6ee372a0bbcd6e5413','res://entities/units/enemies/jungle/elites/carnotaurus/carnotaurus.gdc':'372e3bb1b2aa3bd24d0bea3c65ee6fbc'}
    for p,h in hashes.items():assert pck.entries[p]['md5']==h,'Re-audit Carnotaurus custom callbacks'
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
    projectile='res://projectiles/bullet_enemy/enemy_projectile.tscn';bullet=circle(resolve(projectile),'Hitbox')
    return {'version':reference['version'],'steamBuild':int(reference['steamBuildId']),'source':path,'sourceMd5':actor['sourceMd5'],
        'sceneChain':[{'source':p,'sourceMd5':pck.entries[p]['md5']} for p in chain],
        'statsSource':statsPath,'statsMd5':pck.entries[statsPath]['md5'],'stats':stats,'body':body,'hurt':hurt,'hit':hit,
        'mass':root['properties'].get('mass',1),'bodyLayer':root['properties']['collision_layer'],'bodyMask':root['properties']['collision_mask'],'bodyBorders':root['properties'].get('should_collide_with_borders',True),
        'sprite':art.texture_metadata(pck,art.body_texture(pck,path)),
        'bullet':{'source':projectile,'sourceMd5':pck.entries[projectile]['md5'],**bullet},
        'ruleSources':[{'source':p,'sourceMd5':h} for p,h in hashes.items()],
        'phaseBaseScene':basePath,'phaseBaseSceneMd5':pck.entries[basePath]['md5'],
        'jump':{k:v for k,v in jump.items() if isinstance(v,(int,float,bool))},'phaseAttack':child,'landAttack':land,'presentation':presentation,
        'enginePackVersion':pck.engine,'customTimerSeconds':timer['wait_time'],'bindingAudit':{'freshJumpTimer':0,'freshLandingTimer':0,'jumpDamageUnused':True,'landingRadiusUnused':True,'baseHpTimeThresholdsUnused':True,'elapsedCounterAdvances':False,'switchBeforeNextJumpPhysics':True},
        'engineSource':{'url':'https://raw.githubusercontent.com/godotengine/godot/3.x/modules/gdscript/gdscript.cpp','symbol':'GDScriptInstance::call_multilevel','scope':'Godot3-family callback semantics, not an exact installed executable build match'},
        'bossInit':{'earlyWave':8,'middleWave':12,'endWave':20,'firstHpShare':0.5,'middleHpShare':0.75,'middleDamageShare':0.75,'easyZoneHpShare':0.9,'timerSeconds':timer['wait_time']},
        'normalActorRegistered':True,'evolutionProfilesImplemented':False,'nativeFullParityAccepted':False}
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args();data=generate();catalog=module('carno_catalog','tools/build-character-catalog.py')
    text='--!strict\n-- Concrete normal Carnotaurus elite; EnemySim owns its native shared-animation controller and source phase transitions.\nlocal POINT=require(script.Parent.Stats).range.studsPerPoint\nlocal C=require(script.Parent.NativeBossPhases)\nlocal J=require(script.Parent.JungleWalkers)\nlocal data='+catalog.luau(data)+'''
local s=data.stats
local a=data.phaseAttack
local land=data.landAttack
local clock=C.shootingClockRules
local constants=require(script.Parent.NativeDimetrodon).sourceConstants
data.jumpRule={cooldown=data.jump.cooldown,duration=data.jump.jump_duration,height=data.jump.jump_height*POINT,
 delay=data.jump.jump_delay,landingCooldown=data.jump.landing_cooldown,freshCooldown=data.bindingAudit.freshJumpTimer,
 freshLandingCooldown=data.bindingAudit.freshLandingTimer,riseShare=constants.riseShare,fallEasePower=constants.fallEasePower}
data.presentationRule={parentScale=1,groundOffsetZ=data.presentation.shadow.position.values[2]*POINT,
 initialScale=data.presentation.shadow.scale.values[2],airScale=constants.shadowAirScale,heightShrinkShare=constants.shadowHeightShrinkShare,
 shadowWidth=data.presentation.shadowTexture.widthPoints*POINT,shadowHeight=data.presentation.shadowTexture.heightPoints*POINT,
 warningWidth=data.presentation.warningTexture.widthPoints*data.presentation.warning.scale.values[1]*POINT,
 warningHeight=data.presentation.warningTexture.heightPoints*data.presentation.warning.scale.values[2]*POINT}
data.controller={family='Carnotaurus',shooting={frameRate=clock.frameRate,minimumCooldownFrames=clock.minimumCooldownFrames,
 fireAt=clock.animationFireAt,animationSeconds=clock.animationSeconds,
 profiles={{cooldown=a.cooldown,randomization=a.max_cd_randomization,initial=a.initial_cooldown,
 longEvery=a.long_cooldown_every_x_shoots,longFrames=a.long_cooldown,animationSpeed=a.attack_anim_speed,
 minRange=a.min_range*POINT,maxRange=a.max_range*POINT,moveLocked=a.move_locked,recoveryFrames=a.recovery_cooldown}}},
 phases=C.actors.Carnotaurus,init=data.bossInit,projectileDamage=a.damage,
 projectileRange=J.shootingRules.projectileRangeStuds,projectileRadius=data.bullet.radiusPoints*POINT,
 customJump={landing={speed=land.projectile_speed*POINT,projectileRange=J.shootingRules.projectileRangeStuds,
 projectileRadius=data.bullet.radiusPoints*POINT,
 volley={count=land.number_projectiles,spread=land.projectile_spread,constantSpread=land.constant_spread,
 offsetX=0,offsetZ=0,speedStep=land.speed_change_after_each_projectile*POINT,
 spawnRing={radius=land.projectile_spawn_spread/2*POINT,away=land.shoot_away_from_unit}}}},
 attacks={{kind='Bullet',speed=a.projectile_speed*POINT,deleteWithSource=a.delete_projectile_on_death,
 volley={count=a.number_projectiles,spread=a.projectile_spread,constantSpread=a.constant_spread,
 offsetX=a.position.values[1]*POINT,offsetZ=a.position.values[2]*POINT,speedStep=a.speed_change_after_each_projectile*POINT,
 spawnSquare=a.projectile_spawn_spread*POINT,baseAimFromSpawn=true}}}}
data.kind={
 id='Carnotaurus',typeId=76,displayName='Carnotaurus',look='Brute',nativeArtPending=true,
 nativeZoneId=J.zoneId,nativeScene=data.source,specialSpawn=true,nativeBoss=data.controller,nativeJump=data.jumpRule,nativeJumpPresentation=data.presentationRule,
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
        p=Path(folder)/'NativeCarnotaurus.luau';p.write_text(text,encoding='utf-8');subprocess.run(['stylua',str(p)],check=True);subprocess.run(['stylua',str(p)],check=True);text=p.read_text(encoding='utf-8')
    for p,v in {ROOT/'docs/characters/carnotaurus-source.json':json.dumps(data,indent=2)+'\n',ROOT/'src/shared/Config/NativeCarnotaurus.luau':text}.items():
        if args.check:assert p.read_text(encoding='utf-8')==v,'Stale Carnotaurus source: '+str(p)
        else:p.write_text(v,encoding='utf-8',newline='\n')
    print('Normal Carnotaurus elite compiled; evolution and complete area acceptance remain open')
if __name__=='__main__':main()
