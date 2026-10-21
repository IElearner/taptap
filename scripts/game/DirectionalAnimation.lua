-- Directional frame selection is independent of art and of simulation jobs.
local A={frames=8,directions=8,walkStride=.85}
local Motion=require "game.ActorMotion"
-- Atlas rows: S, SW, W, NW, N, NE, E, SE. World yaw 180 faces S.
function A.direction(yaw)
    return (math.floor(((yaw-180)%360)/45+.5)%8)+1
end
function A.turn(previous,target,dt)
    if previous==nil or dt<=0 then return target end
    local difference=(target-previous+180)%360-180
    -- A returning worker must face the new travel direction immediately;
    -- the short pose blend handles the visual turn without back-pedalling.
    if math.abs(difference)>112 then return target end
    local step=540*dt
    return previous+math.max(-step,math.min(step,difference))
end
function A.stableDirection(yaw,previous)
    if previous then
        local center=180+(previous-1)*45
        if math.abs((yaw-center+180)%360-180)<28 then return previous end
    end
    return A.direction(yaw)
end
function A.blendDuration(previous,current)
    if previous~=current then return .18 end
    return .09
end
function A.select(actor,action,walking,distance,clock)
    if actor.woodPhase=="gather" or actor.woodPhase=="stack" then
        local progress=math.max(0,math.min(1,(actor.woodClock or 0)/1.4))
        local frame=math.min(8,math.floor(progress*8)+1)
        return "load",actor.woodPhase=="stack" and 9-frame or frame
    end
    if actor.job and actor.job.b and (actor.phase=="packing" or actor.phase=="unload") then
        local progress=math.max(0,math.min(1,1-(actor.timer or 0)/require("game.Cargo").doorSeconds))
        if progress<.39 or progress>.61 then
            return actor.carrying and "carry" or "walk",walking and math.floor((distance or 0)/A.walkStride*8)%8+1 or 1
        end
        local frame=math.min(8,math.floor(progress*8)+1)
        return "load",actor.phase=="unload" and 9-frame or frame
    end
    if actor.phase=='packing' then
        local progress=math.max(0,math.min(1,1-(actor.timer or 0)/Motion.packingSeconds))
        if progress<.39 or progress>.61 then
            return actor.carrying and 'carry' or 'walk',walking and math.floor((distance or 0)/A.walkStride*8)%8+1 or 1
        end
        return 'load',math.min(8,math.floor(progress*8)+1)
    end
    local meal=actor.meal
    local Meals=require("game.Meals")
    local sitting=Meals.seatTransitionSeconds
    if meal and (meal.phase=="enter" and meal.timer<sitting or meal.phase=="exit" and meal.timer>Meals.doorwaySeconds-sitting) then
        local t=meal.phase=="enter" and 1-meal.timer/sitting or (meal.timer-(Meals.doorwaySeconds-sitting))/sitting
        return "sit",math.min(8,math.max(1,math.floor(t*8)+1))
    end
    if action=="eat" then
        local elapsed=meal and math.max(0,Meals.eatSeconds-(meal.timer or Meals.eatSeconds)) or clock or 0
        return "eat",math.floor((elapsed/3.8)%1*8)+1
    end
    if action=="mill" then return "walk",1 end
    if action=="chop" or action=="cook" or action=="butcher" or action=="feed" then
        return "work",math.floor((((actor.woodClock or actor.workClock or clock or 0)/1.6)%1)*8)+1
    end
    if action=="plow" or action=="tend" or action=="water" or action=="harvest" then
        return action=="tend" and "plow" or action,math.floor((((actor.workClock or clock or 0)/2.4)%1)*8)+1
    end
    if actor.phase=="waitSite" or actor.phase=="awaitStage" then return "transition",math.floor((actor.timer or 0)*1.5)%2==0 and 7 or 8 end
    if actor.phase=="recover" then return "hammer",(actor.timer or 0)>.22 and 7 or 8 end
    if actor.phase=="unload" then
        local t=math.max(0,math.min(1,1-(actor.timer or 0)/Motion.unloadSeconds))
        return "transition",math.min(4,math.floor(t*4)+1)
    end
    if actor.phase=="ready" then
        local t=math.max(0,math.min(1,1-(actor.timer or 0)/Motion.readySeconds))
        local road=actor.job and (actor.job.kind=="road" or actor.job.pointPhase==1)
        if road then return t<.5 and "transition" or "road",t<.5 and 4 or 1 end
        return "transition",math.min(8,5+math.floor(t*4))
    end
    if action=="hammer" then
        local road=actor.job and (actor.job.kind=="road" or actor.job.pointPhase==1)
        return road and "road" or "hammer",math.floor(((actor.timer or actor.workClock or clock or 0)/1.6)%1*8)+1
    end
    if actor.carrying or actor.phase=="packing" or actor.phase=="unload" then
        return "carry",walking and math.floor((distance or 0)/A.walkStride*8)%8+1 or 1
    end
    return "walk",walking and math.floor((distance or 0)/A.walkStride*8)%8+1 or 1
end
return A
