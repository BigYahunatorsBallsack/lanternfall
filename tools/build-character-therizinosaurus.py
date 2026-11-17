"""Compile the concrete normal Therizinosaurus elite and its already audited two shooting profiles."""
from __future__ import annotations
import argparse,importlib.util,json,subprocess,sys,tempfile
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,ROOT/path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def generate():
    source=module('theri_source','tools/character-source.py');scene=module('theri_scene','tools/build-character-pets.py');art=module('theri_art','tools/prepare-character-jungle-art.py')
    pck=source.Pck();reference=source.verify_reference(pck)
    facts=json.loads((ROOT/'docs/characters/boss-phases-source.json').read_text(encoding='utf-8'));actor=facts['actors']['Therizinosaurus'];path=actor['source']
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
    assert root['scriptSource']=='res://entities/units/enemies/jungle/elites/therizinosaurus/therizinosaurus.gd'
    assert root['properties']['can_be_boosted'] is False
    movement=nodes[('.','MovementBehavior')]
    assert movement['scriptSource']=='res://entities/units/movement_behaviors/follow_target_movement_behavior.gd'
    assert not movement['properties'].get('should_target_vertically',False) and not movement['properties'].get('stop_close_to_target',False),'Re-audit root shoot_in_unit_direction target'
    attacks=actor['shooting'];base=attacks['root']['properties'];child=attacks['phaseOne']['properties']
    assert base['damage']==child.get('damage',1) and base['damage_increase_each_wave']==child['damage_increase_each_wave'],'Independent shot damage bases need separate columns'
    assert base['shoot_in_unit_direction'] and not base['parallel_slashes'] and not base['spawn_projectiles_on_target'] and not base['projectile_spawn_only_on_borders']
    assert not base['shoot_away_from_unit'] and not base['shoot_towards_unit'] and not base['shoot_from_proj_pos_towards_player'],'Root random_rotation needs its source target branch'
    assert not base.get('move_locked',False) and not child.get('move_locked',False),'Movement-lock attacks require a separate controller'
    assert base.get('recovery_cooldown',0)==child.get('recovery_cooldown',0)==0,'Recovery behavior requires its source callback binding'
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
    projectile=actor['shooting']['phaseOne']['projectileSource'];bullet=circle(resolve(projectile),'Hitbox')
    return {'version':reference['version'],'steamBuild':int(reference['steamBuildId']),'source':path,'sourceMd5':actor['sourceMd5'],
        'sceneChain':[{'source':p,'sourceMd5':pck.entries[p]['md5']} for p in chain],
        'statsSource':statsPath,'statsMd5':pck.entries[statsPath]['md5'],'stats':stats,'body':body,'hurt':hurt,'hit':hit,
        'mass':root['properties'].get('mass',1),'bodyLayer':root['properties']['collision_layer'],'bodyMask':root['properties']['collision_mask'],'bodyBorders':root['properties'].get('should_collide_with_borders',True),
        'sprite':art.texture_metadata(pck,art.body_texture(pck,path)),
        'bullet':{'source':projectile,'sourceMd5':pck.entries[projectile]['md5'],**bullet},
        'bossInit':{'earlyWave':8,'middleWave':12,'endWave':20,'firstHpShare':0.5,'middleHpShare':0.75,'middleDamageShare':0.75,'easyZoneHpShare':0.9,'timerSeconds':1},
        'normalActorRegistered':True,'evolutionProfilesImplemented':False,'nativeFullParityAccepted':False}
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args();data=generate();catalog=module('theri_catalog','tools/build-character-catalog.py')
    text='--!strict\n-- Concrete normal Therizinosaurus elite; EnemySim owns its native shared-animation controller and source phase transitions.\nlocal POINT=require(script.Parent.Stats).range.studsPerPoint\nlocal C=require(script.Parent.NativeBossPhases)\nlocal J=require(script.Parent.JungleWalkers)\nlocal data='+catalog.luau(data)+'''
local s=data.stats
local root=C.actors.Therizinosaurus.shooting.root.properties
data.controller={
 family='Therizinosaurus',
 shooting=C.therizinosaurusShooting,phases=C.actors.Therizinosaurus,init=data.bossInit,
 projectileDamage=root.damage,
 projectileRange=J.shootingRules.projectileRangeStuds,projectileRadius=data.bullet.radiusPoints*POINT,
 attacks={{kind='NormalSlash',speed=root.projectile_speed*POINT,volley={count=root.number_projectiles,spread=root.projectile_spread,constantSpread=root.constant_spread,
 offsetX=0,offsetZ=0,speedStep=root.speed_change_after_each_projectile*POINT,
 spawnSquare=root.projectile_spawn_spread*POINT,aimFromSpawn={targetRotation=0}}},
 {kind='Bullet',speed=C.actors.Therizinosaurus.shooting.phaseOne.properties.projectile_speed*POINT,volley=C.therizinosaurusPhaseOneVolley}},
}
data.kind={
 id='Therizinosaurus',typeId=72,displayName='Therizinosaurus',look='Brute',nativeArtPending=true,
 nativeZoneId=J.zoneId,nativeScene=data.source,specialSpawn=true,nativeBoss=data.controller,
 hp=s.health,hpPerWave=s.health_increase_each_wave,contactDamage=s.damage,damagePerWave=s.damage_increase_each_wave,
 speed=s.speed*POINT,nativeSpeedPoints={base=s.speed,randomization=s.speed_randomization},xp=s.value,
 shotDamagePerWave=root.damage_increase_each_wave,
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
        p=Path(folder)/'NativeTherizinosaurus.luau';p.write_text(text,encoding='utf-8');subprocess.run(['stylua',str(p)],check=True);text=p.read_text(encoding='utf-8')
    for p,v in {ROOT/'docs/characters/therizinosaurus-source.json':json.dumps(data,indent=2)+'\n',ROOT/'src/shared/Config/NativeTherizinosaurus.luau':text}.items():
        if args.check:assert p.read_text(encoding='utf-8')==v,'Stale Therizinosaurus source: '+str(p)
        else:p.write_text(v,encoding='utf-8',newline='\n')
    print('Normal Therizinosaurus elite compiled; evolution and complete area acceptance remain open')
if __name__=='__main__':main()
