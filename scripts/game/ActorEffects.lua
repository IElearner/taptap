-- Small contact effects follow the same strike clock that advances actual
-- construction. They never create production or mutate saved gameplay state.
local Motion=require 'game.ActorMotion'
local Pose=require 'game.BuildingPose'
local Effects={}
function Effects.update(world,p,actor,action,x,y)
    local clock=world.sim.elapsed
    local working=action=='hammer' or action=='chop' or action=='plow' or action=='harvest'
    local stroke=action=='hammer' and (actor.timer or 0) or actor.woodClock or actor.workClock or 0
    local cycle=math.floor(stroke/Motion.strokeSeconds)
    local phase=stroke/Motion.strokeSeconds-cycle
    if working and phase>=.60 and phase<.78 and p.lastImpactCycle~=cycle then
        p.lastImpactCycle,p.impactAt=cycle,clock
        local tx,ty=x,y
        if actor.job and actor.job.kind=='road' then tx,ty=actor.job.x,actor.job.y
        elseif actor.job and actor.job.building and world.sim.buildings[actor.job.building] then
            tx,ty=Pose.workTarget(world.sim.buildings[actor.job.building],actor.job)
        elseif action=='chop' and actor.treeX then tx,ty=actor.treeX,actor.treeY end
        p.impactX,p.impactY=tx,ty
    elseif not working then p.lastImpactCycle=nil end
    local age=p.impactAt and clock-p.impactAt or 1
    if age<.32 and not p.impactDust then
        p.impactDust={}
        for i=1,3 do
            local n=world:part(p.node,'WorkContactDust','Sphere',world:material(193,165,106),0,0,0,.025,.025,.025)
            n:GetComponent('StaticModel').castShadows=false;p.impactDust[i]=n
        end
    end
    for i,n in ipairs(p.impactDust or {}) do
        n.enabled=age>=0 and age<.32
        if n.enabled then
            local t=age/.32;local angle=i*2.4
            n.position=Vector3((p.impactX-x)+math.cos(angle)*t*.13,.025+math.sin(t*math.pi)*.10,y-p.impactY+math.sin(angle)*t*.10)
            local size=.024*(1-t);n.scale=Vector3(size,size*.8,size)
        end
    end
end
return Effects
