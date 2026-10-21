-- Visual projections of actual simulation agents; no invented production.
local Meals=require 'game.Meals'
local Farm=require 'game.FarmCycle'
local D=require 'game.Definitions'
local Cargo=require 'game.Cargo'
local Layout=require 'game.PixelLayout'
local Routine=require 'game.WorkRoutine'
local Ranch=require 'game.RanchCycle'
local A=require 'game.PixelAssets'
local Economy=require 'game.Economy'
local Life=require 'game.WorkLife'
local Actors={}
function Actors.collect(sim,history)
    local result={}
    local function add(key,a,action,b)
        if Meals.hidden(sim,a) then return end
        local x,y=a.x,a.y
        local meal=a.meal
        if a.life and a.life.phase=='mine'and not meal then history[key]=nil;return end
        if meal then action=nil end
        if meal and (meal.phase=='enter' or meal.phase=='eat' or meal.phase=='exit') then
            local hall=sim.buildings[meal.target]
            if hall and Layout.diningHidden(hall,meal) then history[key]=nil;return end
            if hall then x,y=Layout.dining(hall,meal) end
            if meal.phase=='eat' then action='eat' end
        elseif meal and meal.phase=='queue' then
            local hall=sim.buildings[meal.target]
            if hall then x,y=Meals.queuePosition(sim,hall,a) end
        elseif b and b.kind=='farm' and (a.farmPresence or 0)>0 then
            local px=b.x-((b.footprintW or 1)-1)/2
            local py=b.y-((b.footprintH or 1)-1)/2
            x,y=x+(px-x)*a.farmPresence,y+(py-y)*a.farmPresence
        end
        -- The mature simulation already models door packing and unloading.
        local hidden,interior=false,b and not meal and b.kind=='farm' and (a.farmPresence or 0)>.05 or false
        if not meal and key:match('^carrier')and not a.sitePickup then
            x,y,hidden=Layout.cargoDoor(sim,a,x,y)
        elseif not meal and key:match('^builder') and a.phase=='packing' then
            x,y,hidden=Layout.cargoDoor(sim,{phase=a.phase,timer=a.timer,job={inbound=true}},x,y)
        elseif b and not a.life and not a.lean and not a.breaks and not a.workshopOutdoor and not meal and Routine.indoor(b.kind) then
            local indoorHidden
            x,y,interior,indoorHidden=Layout.workDoor(b,a.workPresence or 0,a.slot)
            local open=b.kind=='kitchen' or Routine.visibleWorkplace(b.kind)
            hidden=open and indoorHidden or not open and (a.workPresence or 0)<.15
            if Routine.visibleWorkplace(b.kind) and (a.workPresence or 0)<.02 and sim:connected(b) and (b.workRate or 0)>0 and Economy.canWork(b) and Economy.hasInputs(b) and Economy.canProduce(b) and Economy.resourceAvailable(sim,b) then action='work' end
            if not b.stopped and b.kind=='kitchen' and (a.workPresence or 0)<.1 and (b.activeWorkers or 0)>0 and b.inputs>0 and b.buffer<=4 then action='cook' end
        elseif b and not meal and b.kind=='ranch' then
            local presence=Ranch.presence(b)
            x,y=Layout.ranch(b,presence)
            hidden=presence<.15;interior=not hidden
        end
        if b and not a.life and not a.lean and not a.breaks and not a.workshopOutdoor and meal and (meal.phase=='leaveWork' or meal.phase=='returnWork') then
            local presence=meal.phase=='leaveWork' and 1-meal.timer/2.8 or meal.timer/2.8
            local indoorHidden
            x,y,interior,indoorHidden=Layout.workDoor(b,presence,a.slot)
            local open=b.kind=='kitchen' or Routine.visibleWorkplace(b.kind)
            hidden=open and indoorHidden or not open and Routine.indoor(b.kind) and presence<.15
        end
        if key:match('^guard') and not meal then
            local number=tonumber(key:match('(%d+)$')) or 1
            local count=#(sim.guards or {})
            local columns=math.min(3,count)
            local row=math.floor((number-1)/columns)
            local rowCount=math.min(columns,count-row*columns)
            local column=(number-1)%columns
            -- Display only: a bounded formation keeps the actual guard
            -- positions, paths, attack range and simulation damage intact.
            x,y=x+(column-(rowCount-1)/2)*.65,y+.10+row*.55
        end
        if a.lean and not meal and y<b.y+.8 then interior=true end
        if a.life and not meal then action=Life.action(a)end
        if b and not meal and not b.stopped and(a.workFinishLeft or 0)>0 then action='workshopFinish'end
        if a.breaks and not meal then
            local phase=a.breaks.phase
            action=phase=='idle'and 'workshopIdle'or phase=='stow'and a.workLoad and 'stow'or phase=='finish'and a.workLoad and 'workshopFinish'or
                phase=='work'and b and not b.stopped and sim:connected(b)and Economy.canWork(b)and Economy.hasInputs(b)and Economy.canProduce(b)and 'work'or nil
        end
        if a.lean and not meal then action=a.lean.phase=='lean'and 'lean'or nil end
        if a.sitePickup and not meal and a.sitePickup.phase=='loading'then action='pickup'end
        if hidden then history[key]=nil;return end
        local old=history[key] or {x=x,y=y,distance=0,direction=0,clock=sim.elapsed}
        if key:match('^builder') then x,y=Layout.construction(sim,a,old,x,y) end
        if b and b.kind=='woodcutter' and not meal then x,y=Layout.logging(a,x,y) end
        -- Phase changes can replace the path in one simulation tick. Follow
        -- the registered approach at walking speed instead of teleporting.
        local elapsed=math.max(0,math.min(.25,sim.elapsed-(old.clock or sim.elapsed)))
        local remaining=math.sqrt(((x-old.x)*64)^2+((y-old.y)*48)^2)
        local step=72*elapsed
        if old.seen and elapsed==0 then
            x,y=old.x,old.y
        elseif old.seen and remaining>step and remaining>0 then
            local factor=step/remaining
            x,y=old.x+(x-old.x)*factor,old.y+(y-old.y)*factor
            if action=='hammer' and remaining-step>3 then action=nil end
        end
        local dx,dy=(x-old.x)*64,(y-old.y)*48
        local distance=math.sqrt(dx*dx+dy*dy)
        local walking=distance>.01 and distance<100
        if walking then
            old.distance=old.distance+distance
            if math.abs(dx)>math.abs(dy) then old.direction=dx>0 and 2 or 1 else old.direction=dy>0 and 0 or 3 end
        end
        if not walking then
            if a.workshopOutdoor and(action=='work'or action=='workshopFinish')then old.direction=a.slot==2 and 1 or 2
            elseif action=='pickup'or a.workshopOutdoor and action=='stow'or a.rackVisit and action=='stow'then old.direction=2 end
        end
        local frame=walking and math.floor(old.distance/(A.walkCycle/4))%4 or 0
        if walking and action~='eat'and action~='ride'then action=nil end
        if old.seen and elapsed==0 then walking,frame,action=old.walking or false,old.frame or 0,old.action end
        if action~=old.action then old.actionSince=sim.elapsed end
        local actionClock=sim.elapsed-(old.actionSince or sim.elapsed)
        if action=='hammer' then actionClock=a.timer or 0
        elseif action=='chop'or a.rackVisit and action=='stow' then actionClock=a.woodClock or 0
        elseif action=='eat' and meal then actionClock=Meals.eatSeconds-meal.timer end
        if a.life and not meal then actionClock=a.life.clock or 0 end
        if a.breaks and not meal then actionClock=a.breaks.clock or 0 end
        if a.lean and not meal then actionClock=a.lean.clock or 0 end
        if a.sitePickup and not meal then actionClock=a.sitePickup.clock or 0 end
        old.x,old.y,old.clock,old.seen=x,y,sim.elapsed,true;history[key]=old
        old.walking,old.frame,old.action=walking,frame,action
        result[#result+1]={key=key,actor=a,x=x,y=y,walking=walking,direction=old.direction,
            frame=frame,action=action,actionClock=actionClock,simTime=sim.elapsed,
            look=(a.workerLook or 1)-1,cargo=a.carrying and (b and b.kind=="woodcutter" and sim:outputResource(b) or Cargo.resource(a)) or nil,building=b,
            faction=key:match('^guard') and 'guard' or key:match('^enemy') and 'enemy' or nil,
            leaning=a.lean~=nil,
            layerBuilding=interior and b or meal and (meal.phase=='enter' or meal.phase=='eat' or meal.phase=='exit') and sim.buildings[meal.target] or nil}
    end
    for i,a in ipairs(sim.carriers) do add('carrier'..i,a) end
    for i,a in ipairs(sim.builders) do if a.active or a.meal or a.restRequested then add('builder'..i,a,a.phase=='hammer' and 'hammer' or nil) end end
    for key,a in pairs(sim.workers) do
        local b=sim.buildings[a.building]
        if b and b.complete and a.slot<=b.workers then
            local action=not a.meal and (b.kind=='woodcutter' and a.woodPhase=='chop' and 'chop' or
                b.kind=='woodcutter'and a.rackVisit and a.woodPhase=='stack'and 'stow'or
                b.kind=='forester' and a.forestryPhase=='tend' and 'plant' or
                b.kind=='farm' and (a.farmPresence or 0)>.9 and Farm.needsWork(b,D.buildings.farm.period) and Farm.action(b)) or nil
            add('worker'..key,a,action,b)
        end
    end
    local fighting=false
    if sim.raid then for _,e in ipairs(sim.enemies or {})do
        if e.hp>0 and (e.x-10)^2+(e.y-9)^2<14 then fighting=true;break end
    end end
    for i,a in ipairs(sim.guards or {}) do add('guard'..i,a,fighting and 'attack' or nil) end
    for i,a in ipairs(sim.enemies or {}) do if a.hp>0 then add('enemy'..i,a,fighting and (a.x-10)^2+(a.y-9)^2<14 and 'attack' or nil) end end
    return result
end
return Actors
