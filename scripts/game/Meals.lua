local Move = require "game.Movement"
local Farm = require "game.FarmCycle"
local BuildingPose = require "game.BuildingPose"
local Routine=require 'game.WorkRoutine'
local Ranch=require 'game.RanchCycle'
local Economy=require 'game.Economy'
local Deposits=require 'game.Deposits'
local Meals = { seats = 4, pantryCapacity = 8, doorwaySeconds = 2.8, seatTransitionSeconds = .7, workDoorSeconds = 2.8, eatSeconds = 11.5 }
local function floorFood(sim) return sim.mode == "finite" and not sim.skipped and 8 or 0 end
local function visitors(sim,visit)
    for _,a in ipairs(sim.carriers) do visit(a) end
    for _,a in pairs(sim.workers) do visit(a) end
    for _,a in ipairs(sim.builders) do visit(a) end
    for _,a in ipairs(sim.guards or {}) do visit(a) end
end
local function inside(m,id)
    return m and m.target==id and (m.phase=="enter" or m.phase=="eat" or m.phase=="exit")
end
local function occupancy(sim,id)
    local count=0
    visitors(sim,function(a) if inside(a.meal,id) then count=count+1 end end)
    return count
end
Meals.occupancy=occupancy
-- Count ready meals where villagers can actually reach them, including
-- reserved deliveries already removed from warehouse stock.
function Meals.availableFood(sim)
    local total=sim.stock.food or 0
    for _,b in ipairs(sim.buildings) do
        if b.complete and b.kind=='kitchen' and sim:connected(b) then total=total+(b.mealStock or 0)+(b.buffer or 0) end
    end
    local function delivery(job)
        if not job or job.resource~='food' then return end
        if job.service then
            local hall=job.b
            if hall and hall.complete and sim:connected(hall) then total=total+(job.amount or 0) end
        elseif job.pickedUp then total=total+(job.amount or 0) end
    end
    for _,job in ipairs(sim.jobs) do delivery(job) end
    for _,a in ipairs(sim.carriers) do if not a.handedOff then delivery(a.job) end end
    return total
end
-- The painted porch is aligned to the fixed camera, independent of the
-- retained construction-frame rotation. All four seats share its front edge.
function Meals.porchPoint(b,x,y)
    return b.x-((b.footprintW or 1)-1)*.5+x*(b.footprintW or 1)/3,
        b.y-((b.footprintH or 1)-1)*.5+y*(b.footprintH or 1)/2
end
function Meals.occupant(sim,id,seat)
    local result
    visitors(sim,function(a) if inside(a.meal,id) and a.meal.seat==seat then result=a end end)
    return result
end
function Meals.seatPosition(b,seat,side)
    return Meals.porchPoint(b,({-.54,-.28,.87,1.12})[seat] or 0,.18)
end
function Meals.queuePosition(sim,b,actor)
    local index,slot=0,0
    visitors(sim,function(a)
        if a.meal and a.meal.target==b.id and a.meal.phase=="queue" then
            if a==actor then slot=index end
            index=index+1
        end
    end)
    return b.x+.20+slot*.36,b.y+1.18
end
function Meals.diningPosition(b,seat,phase,timer,meal)
    local seatX,seatY=Meals.seatPosition(b,seat)
    local progress=phase=="enter" and 1-timer/Meals.doorwaySeconds or
        phase=="exit" and timer/Meals.doorwaySeconds or 1
    progress=math.max(0,math.min(1,progress))
    local doorX,doorY=b.x,b.y+1
    if phase=="enter" and meal and meal.queueX then doorX,doorY=meal.queueX,meal.queueY end
    local thresholdX,thresholdY=Meals.porchPoint(b,.20,.91)
    local aisleX,aisleY=seatX,select(2,Meals.porchPoint(b,0,.40))
    local function between(a,z,p) return a+(z-a)*p end
    if progress<0.30 then
        local p=progress/0.30
        return between(doorX,thresholdX,p),between(doorY,thresholdY,p)
    elseif progress<0.55 then
        local p=(progress-0.30)/0.25
        return between(thresholdX,aisleX,p),between(thresholdY,aisleY,p)
    end
    local p=math.min(1,(progress-0.55)/0.45)
    return between(aisleX,seatX,p),between(aisleY,seatY,p)
end
local function freeSeat(sim,id,actor)
    local taken={}
    visitors(sim,function(a)
        local m=a.meal
        if a~=actor and inside(m,id) and m.seat then taken[m.seat]=true end
    end)
    for seat=1,Meals.seats do if not taken[seat] then return seat end end
end
local function queueOrder(sim,a)
    if a.trafficId then return a.trafficId end
    if a.building and a.slot then return 10000+a.building*4+a.slot end
    for i,other in ipairs(sim.carriers)do if other==a then return i end end
    for i,other in ipairs(sim.builders)do if other==a then return 100+i end end
    for i,other in ipairs(sim.guards or {})do if other==a then return 100000+i end end
    return math.huge
end
local function queueFirst(sim,id,a)
    local first,arrived,order=nil,math.huge,math.huge
    visitors(sim,function(other)
        local m=other.meal
        if m and m.target==id and m.phase=='queue' then
            -- Old snapshots have only accumulated waiting time. Initialize all
            -- missing arrivals before comparing, independent of actor update order.
            m.queueArrivedAt=m.queueArrivedAt or math.max(0,sim.elapsed-(m.waitTime or 0))
            local tie=queueOrder(sim,other)
            if m.queueArrivedAt<arrived or m.queueArrivedAt==arrived and tie<order then
                first,arrived,order=other,m.queueArrivedAt,tie
            end
        end
    end)
    return first==a
end
local function ownKitchen(sim,a)
    local b=a.building and sim.buildings[a.building]
    if b and b.complete and b.kind=='kitchen' and a.slot and a.slot>=1 and a.slot<=b.workers and
        sim.workers[b.id..':'..a.slot]==a then return b end
end
local function canCook(sim,b)
    return b and b.complete and sim:connected(b) and not b.stopped and Economy.canWork(b) and Economy.hasInputs(b) and
        Economy.canProduce(b) and Economy.resourceAvailable(sim,b)
end
local function stoveReady(sim,b)
    if not canCook(sim,b) then return false end
    for slot=1,b.workers do
        local cook=sim.workers[b.id..':'..slot]
        -- The actor's actual workplace state survives prepareWorkers clearing
        -- its aggregate rate; a dining or returning cook cannot advance a pot.
        if cook and cook.building==b.id and cook.slot==slot and not cook.meal and
            Routine.atWork(cook,'kitchen') then return true end
    end
    return false
end
local function destination(sim,a)
    local own=ownKitchen(sim,a)
    if own and sim:connected(own) and (own.mealStock or 0)>0 and
        sim:path(math.floor(a.x+.5),math.floor(a.y+.5),own.x,own.y+1) then return own end
    local demand={}
    visitors(sim,function(other)
        local m=other~=a and other.meal
        if m and not m.paid and (m.phase=='leaveWork' or m.phase=='walk' or m.phase=='queue') then
            demand[m.target]=(demand[m.target] or 0)+1
        end
    end)
    local best,rank,distance=nil,math.huge,math.huge
    for _,b in ipairs(sim.buildings) do
        if b.complete and b.kind == "kitchen" and sim:connected(b) then
            local path=sim:path(math.floor(a.x+0.5),math.floor(a.y+0.5),b.x,b.y+1)
            if path then
                local stock,waiting=b.mealStock or 0,demand[b.id] or 0
                -- Prefer food that exists now. Walking/queued villagers retain
                -- their claim for ranking only; food is still charged at a seat.
                local ready=stock>waiting and 0 or stock>0 and 1 or
                    (b.mealIncoming or sim.stock.food>floorFood(sim)) and 2 or 3
                local cost=#path+waiting*2+occupancy(sim,b.id)
                if ready<rank or ready==rank and cost<distance then best,rank,distance=b,ready,cost end
            end
        end
    end
    return best
end
function Meals.canEat(sim)
    for _,b in ipairs(sim.buildings) do
        if b.complete and b.kind=="kitchen" and sim:connected(b) and ((b.mealStock or 0)>0 or sim.stock.food>floorFood(sim)) then return true end
    end
    return false
end
function Meals.restock(sim,b)
    local reserved,incoming=0,0
    local function reservation(job)
        if not job or job.b~=b or job.resource~='food' then return end
        if job.service then incoming=incoming+(job.amount or 0)
        elseif not job.inbound and not job.pickedUp then reserved=reserved+(job.amount or 0) end
    end
    for _,job in ipairs(sim.jobs)do reservation(job)end
    for _,carrier in ipairs(sim.carriers)do if not carrier.handedOff then reservation(carrier.job)end end
    -- Food on this hall's own shelf can refill its counter without a trip to
    -- the warehouse. Preserve unpicked loads and space for incoming food.
    local available=Economy.outputAmount(b,'food')-reserved
    local localFood=math.max(0,math.min(Meals.pantryCapacity-(b.mealStock or 0)-incoming,available))
    if localFood>0 then
        Economy.take(b,'food',localFood)
        b.mealStock=(b.mealStock or 0)+localFood
        sim.produced.food=(sim.produced.food or 0)+localFood
    end
    if (b.mealStock or 0)>=4 or b.mealIncoming then return end
    local amount=math.min(2,Meals.pantryCapacity-(b.mealStock or 0),sim.stock.food-floorFood(sim))
    if amount>0 then
        sim.stock.food,b.mealIncoming=sim.stock.food-amount,true
        sim.jobs[#sim.jobs+1]={b=b,inbound=true,resource="food",amount=amount,service=true}
    end
end
function Meals.tick(sim,a,dt,offline,busy,working)
    a.hunger=a.hunger or 0
    a.energy=a.energy or 100
    if not offline then
        a.hunger=math.min(600,a.hunger+dt)
        if not a.meal then
            if busy or working then a.energy=math.max(0,a.energy-dt*.8)
            else a.energy=math.min(100,a.energy+dt*.8) end
        end
    end
    local m=a.meal
    local own=ownKitchen(sim,a)
    local cooking=own and (own.mealStock or 0)==0 and canCook(sim,own)
    if cooking and m and not m.paid and (m.phase=='leaveWork' or m.phase=='walk' or m.phase=='queue') then
        if Move.route(sim,a,m.resumeX,m.resumeY) then m.phase,m.timer,m.queueArrivedAt,m.stoveWaitSeconds="return",0,nil,nil end
    elseif own and not cooking and m and not m.paid and m.phase=='return' then
        local target=destination(sim,a)
        if target and (target.mealStock or 0)>0 and Move.route(sim,a,target.x,target.y+1) then
            m.target,m.phase,m.waitTime,m.queueArrivedAt,m.stoveWaitSeconds=target.id,"walk",0,nil,nil
        end
    end
    -- The cook can prepare actual ingredients instead of chasing another hall's
    -- last portion. Normal work/door timing still controls the next batch.
    if not m and not offline and not busy and not cooking and (a.hunger >= 90 or a.energy <= 25) then
        local target=destination(sim,a)
        local freeCarriers=0
        for _,c in ipairs(sim.carriers) do if not c.meal then freeCarriers=freeCarriers+1 end end
        local carrier=false
        for _,c in ipairs(sim.carriers) do if c==a then carrier=true;break end end
        local stocked=target and (target.mealStock or 0)>0
        local supply=stocked or sim.stock.food>floorFood(sim)
        -- The final available carrier keeps transporting until the dining room has food.
        if target and supply and (not carrier or freeCarriers>1 or
            stocked and #sim.jobs==0 and not target.mealIncoming) then
            local resumeX,resumeY=math.floor(a.x+0.5),math.floor(a.y+0.5)
            if Move.route(sim,a,target.x,target.y+1) then
                m={target=target.id,phase=a.building and "leaveWork" or "walk",
                    timer=a.building and Meals.workDoorSeconds or 0,
                    resumeX=resumeX,resumeY=resumeY,paid=false}
                a.meal=m
            end
        end
    end
    if not m then return false end
    local target=sim.buildings[m.target]
    if not target or target.kind~="kitchen" or not target.complete then
        a.meal=false;a.path={};a.index=1
        return false
    end
    if m.phase == "leaveWork" then
        m.timer=math.max(0,m.timer-dt)
        if m.timer==0 then
            if Move.route(sim,a,target.x,target.y+1) then m.phase="walk"
            else a.meal=false;a.path={};a.index=1;return false end
        end
    elseif m.phase == "walk" then
        if Move.step(a,dt,nil,sim) then m.phase,m.queueArrivedAt,m.waitTime,m.stoveWaitSeconds="queue",sim.elapsed,0,nil end
    elseif m.phase == "queue" then
        m.queueArrivedAt=m.queueArrivedAt or math.max(0,sim.elapsed-(m.waitTime or 0))
        m.waitTime=(m.waitTime or 0)+dt
        local available=target.mealStock or 0
        if offline then
            m.phase,m.queueArrivedAt,m.stoveWaitSeconds="return",nil,nil;Move.route(sim,a,m.resumeX,m.resumeY)
        elseif available>0 and occupancy(sim,m.target)<Meals.seats and queueFirst(sim,m.target,a) then
            local seat=freeSeat(sim,m.target,a)
            if not seat then return true end
            target.mealStock=target.mealStock-1
            sim.mealsServed=sim.mealsServed+1
            if m.waitTime>.6 then m.queueX,m.queueY=Meals.queuePosition(sim,target,a) end
            m.phase,m.timer,m.paid,m.seat,m.queueArrivedAt,m.stoveWaitSeconds="enter",Meals.doorwaySeconds,true,seat,nil,nil
        elseif available==0 then
            local waited=m.stoveWaitSeconds or 0
            local leaveStove=false
            if stoveReady(sim,target) and waited<30-.000001 then
                m.stoveWaitSeconds=math.min(30,waited+dt)
                if m.stoveWaitSeconds<30-.000001 then return true end
                leaveStove=true
            elseif waited>0 then leaveStove=true end
            -- An unpaid guest can leave an empty hall for actual cooked food.
            -- Preserve the original workplace return and all paid meal phases.
            local alternate=not m.paid and destination(sim,a)
            if alternate and alternate~=target and (alternate.mealStock or 0)>0 and
                Move.route(sim,a,alternate.x,alternate.y+1) then
                m.target,m.phase,m.waitTime,m.queueArrivedAt,m.stoveWaitSeconds=alternate.id,"walk",0,nil,nil
            elseif leaveStove then
                m.phase,m.queueArrivedAt,m.stoveWaitSeconds="return",nil,nil;Move.route(sim,a,m.resumeX,m.resumeY)
            elseif not target.mealIncoming and sim.stock.food>floorFood(sim) then
                local amount=math.min(2,Meals.pantryCapacity-(target.mealStock or 0),sim.stock.food-floorFood(sim))
                if amount<=0 then return true end
                sim.stock.food,target.mealIncoming=sim.stock.food-amount,true
                sim.jobs[#sim.jobs+1]={b=target,inbound=true,resource="food",amount=amount,service=true}
            elseif not target.mealIncoming then
                m.phase,m.queueArrivedAt,m.stoveWaitSeconds="return",nil,nil;Move.route(sim,a,m.resumeX,m.resumeY)
            end
        end
    elseif m.phase == "enter" or m.phase == "eat" or m.phase == "exit" then
        -- Saves from the earlier two-seat version have no seat index.
        if not m.seat then m.seat=freeSeat(sim,m.target,a) end
        m.timer=math.max(0,m.timer-dt)
        if m.timer == 0 then
            if m.phase == "enter" then m.phase,m.timer="eat",Meals.eatSeconds
            elseif m.phase == "eat" then m.phase,m.timer,a.hunger,a.energy="exit",Meals.doorwaySeconds,0,100
            else m.phase,m.seat="return",nil; Move.route(sim,a,m.resumeX,m.resumeY) end
        end
    elseif m.phase == "return" then
        if Move.step(a,dt,nil,sim) then
            a.path={};a.index=1
            if a.building then m.phase,m.timer="returnWork",Meals.workDoorSeconds
            else a.meal=false end
        end
    elseif m.phase == "returnWork" then
        m.timer=math.max(0,m.timer-dt)
        if m.timer==0 then a.meal=false end
    end
    return true
end
function Meals.prepareWorkers(sim,dt,offline)
    local alive={}
    for _,b in ipairs(sim.buildings) do
        b.activeWorkers,b.workRate=0,0
        if b.complete then
            for slot=1,b.workers do
                local key=b.id .. ":" .. slot
                local a=sim.workers[key]
                if not a then
                    a={x=b.x,y=b.y+1,path={},index=1,hunger=(b.id+slot)%5*3,energy=100,meal=false,building=b.id,slot=slot,workerLook=math.random(2)}
                    sim.workers[key]=a
                end
                alive[key]=true
                if not a.workshopOutdoor then a.workFinishLeft=math.max(0,(a.workFinishLeft or 0)-dt)end
                local finishing=a.workFinishLeft>0 and not b.stopped and sim:connected(b)
                local def=require("game.Definitions").buildings[b.kind]
                local working=sim:connected(b) and not b.stopped and (b.kind=="farm" and Farm.needsWork(b,def.period) or
                    b.kind=="ranch" and Ranch.busy(b) or
                    b.kind=="woodcutter" and (a.woodPhase~=nil or b.buffer<6) or
                    b.kind~="farm" and b.kind~="ranch" and b.kind~="woodcutter" and
                    (not def.input or b.inputs>0) and Economy.canProduce(b) and Economy.hasInputs(b) and Economy.resourceAvailable(sim,b))
                a.profession=def.profession
                local life=require('game.WorkLife')
                life.step(sim,a,b,dt,offline)
                local breaks=require('game.WorkBreaks');breaks.update(sim,a,b,dt,offline)
                if a.life then working=life.working(a)or false end
                local eating=Meals.tick(sim,a,dt,offline,(b.kind=="woodcutter" and a.woodPhase~=nil or b.kind=="forester" and a.forestryPhase~=nil or b.kind=="ranch" and Ranch.busy(b)or life.busy(a)or a.lean~=nil or breaks.busy(a)or finishing),working)
                Routine.update(a,b.kind,working or finishing,dt)
                if b.kind=="farm" and not offline then
                    local target=working and (not eating or a.meal and a.meal.phase=="returnWork") and 1 or 0
                    local presence=a.farmPresence or 0
                    a.farmPresence=math.max(0,math.min(1,presence+(target==1 and 1 or -1)*dt*0.85))
                end
                if not eating then
                    b.activeWorkers=b.activeWorkers+1
                    local atWork=(b.kind~="farm" or offline or (a.farmPresence or 0)>=0.95) and Routine.atWork(a,b.kind)
                    if atWork then b.workRate=b.workRate+(a.energy<25 and 0.6 or 1) end
                    if working and atWork then a.workClock=(a.workClock or 0)+dt end
                end
            end
        end
    end
    for key in pairs(sim.workers) do if not alive[key] then sim.workers[key]=nil end end
end
function Meals.hidden(sim,a)
    return false
end
return Meals
