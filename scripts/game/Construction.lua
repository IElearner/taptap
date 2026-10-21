local D = require "game.Definitions"
local Move = require "game.Movement"
local Meals = require "game.Meals"
local Motion = require "game.ActorMotion"
local Sites = require "game.ConstructionSites"
local C = {}
-- Work is measured in worker-seconds; adding builders shortens elapsed time,
-- without changing the amount of work required by a site.
C.maxBuilders = 4
C.buildingWork = Sites.totalWork
local directions = { {1,0}, {-1,0}, {0,1}, {0,-1} }
function C.busy(sim)
    local count = 0
    for _, a in ipairs(sim.builders) do if a.active or a.meal then count = count+1 end end
    return count
end
local function claimed(sim, kind, x, y, id)
    local count = 0
    for _, a in ipairs(sim.builders) do
        local j = a.job
        if j and j.kind == kind and (kind == "road" and j.x == x and j.y == y or kind == "building" and j.building == id) then count=count+1 end
    end
    return count
end
local function siteFor(sim, job)
    if job.kind == "road" then return sim:roadSiteAt(job.x,job.y) end
    return sim.buildings[job.building]
end
local function workSite(sim,b,side,fallback,ignore)
    local w,h=b.footprintW or 1,b.footprintH or 1
    local left,right,top,bottom=b.x-w,b.x+1,b.y-h,b.y+1
    local cx,cy=math.floor(b.x-(w-1)*.5+.5),math.floor(b.y-(h-1)*.5+.5)
    local candidates={{x=cx,y=bottom,side="south"},{x=left,y=cy,side="west"},
        {x=cx,y=top,side="north"},{x=right,y=cy,side="east"}}
    local adjacent={}
    for _,edge in ipairs(D.edges(b)) do
        candidates[#candidates+1]={x=edge.outsideX,y=edge.outsideY,side=edge.side}
        adjacent[edge.outsideX .. ":" .. edge.outsideY]=true
    end
    for x=left+1,right-1 do
        candidates[#candidates+1]={x=x,y=bottom,side="south"}
        candidates[#candidates+1]={x=x,y=top,side="north"}
    end
    for y=top+1,bottom-1 do
        candidates[#candidates+1]={x=left,y=y,side="west"}
        candidates[#candidates+1]={x=right,y=y,side="east"}
    end
    for _,p in ipairs(candidates) do
        local occupied=false
        for _,a in ipairs(sim.builders) do
            local j=a.job
            if a~=ignore and j and j.kind=="building" and j.building==b.id and j.workX==p.x and j.workY==p.y then occupied=true;break end
        end
        if (not side or p.side==side) and not occupied and adjacent[p.x .. ":" .. p.y] and sim:forestPath(b.x,b.y+1,p.x,p.y) then return p end
    end
    -- An adjoining building can block a whole wall. Use another reachable
    -- edge for access instead of leaving that structural point unfinished.
    if side and not fallback then return workSite(sim,b,nil,true,ignore) end
end
-- Dispatch only useful work. Unsupplied points never attract an idle crew.
local function unclaimedCurrentPoint(sim,b,ignore)
    local phase=Sites.phase(b)
    for _,point in ipairs(Sites.ensure(b)) do
        if point.phase==phase and point.work<point.required-.000001 then
            local reserved=false
            for _,other in ipairs(sim.builders) do
                local j=other.job
                if other~=ignore and other.active and j and j.kind=='building' and j.building==b.id and j.pointId==point.id then reserved=true;break end
            end
            if not reserved then return true end
        end
    end
    return false
end
local function buildingJob(sim,b,ignore,prefetch)
    if b.complete or not sim:connected(b) then return end
    Sites.activate(b)
    local phase=Sites.phase(b)
    -- Never let supplied future work occupy the entire crew while the
    -- current material batch is still on its way from the warehouse.
    if prefetch and unclaimedCurrentPoint(sim,b,ignore) then return end
    local desired=prefetch and phase+1 or phase
    for _,point in ipairs(Sites.ensure(b)) do
        if point.phase==desired and point.work<point.required-.000001 then
            local occupied,inTransit=false,false
            for _,other in ipairs(sim.builders) do
                local j=other.job
                if other~=ignore and j and j.building==b.id then
                    if j.pointId==point.id then occupied=true end
                    if j.pointPhase==point.phase and j.resource==point.resource and j.delivery then inTransit=true end
                end
            end
            local stocked=Sites.supplied(b,point.phase,point.resource)
            local delivery=not stocked and not inTransit and not Sites.requested(sim,b,point.phase,point.resource)
            if (prefetch and stocked and not occupied or not prefetch and not occupied and (point.delivered or delivery)) then
                local pos=workSite(sim,b,point.side,nil,ignore)
                if pos then return {delivery=delivery,advance=prefetch or false,supplyOnly=false,
                    deliveryAmount=Sites.deliveryAmount(b,point.phase,point.resource),
                    kind="building",building=b.id,pointId=point.id,resource=point.resource,amount=point.amount,
                    pointPhase=point.phase,pointSide=point.side,doorX=b.x,doorY=b.y+1,
                    workX=pos.x,workY=pos.y,side=pos.side} end
            end
        end
    end
end
local function nextJob(sim)
    for _, p in ipairs(sim.pendingRoads) do
        if claimed(sim,"road",p.x,p.y)==0 then
            for _, d in ipairs(directions) do
                local x,y = p.x+d[1],p.y+d[2]
                if sim:path(10,9,x,y) then return {kind="road",x=p.x,y=p.y,doorX=x,doorY=y,resource="stone"} end
            end
        end
    end
    for _,b in ipairs(sim.buildings) do
        local job=buildingJob(sim,b)
        if job then return job end
    end
    -- While others hammer, a spare worker brings the next stage's batch.
    for _,b in ipairs(sim.buildings) do
        local job=buildingJob(sim,b,nil,true)
        if job then return job end
    end
end

local function releaseOne(sim,a,rest)
    local j=a.job
    local onSite=a.phase=="approach" or a.phase=="unload" or a.phase=="hammer" or a.phase=="ready" or a.phase=="recover" or a.phase=="waitSite" or a.phase=="waitMaterials" or a.phase=="awaitStage"
    a.job,a.phase,a.carrying=false,"return",false
    a.restRequested=rest or false
    if j and j.kind=="building" and onSite then
        local path=sim:forestPath(math.floor(a.x+.5),math.floor(a.y+.5),j.doorX,j.doorY)
        if path then a.path,a.index,a.phase=path,1,"leaveSite";return end
    end
    Move.route(sim,a,10,9)
end
local function releaseCrew(sim,kind,id,x,y)
    for _,a in ipairs(sim.builders) do
        local j=a.job
        if j and j.kind==kind and (kind=="building" and j.building==id or kind=="road" and j.x==x and j.y==y) then releaseOne(sim,a) end
    end
end
local function finishBuilding(sim,b)
    b.complete,b.progress = true,1
    if b.kind == "house" then sim.population = sim.population+4 end
    if b.kind == "courier" then
        sim.carriers[#sim.carriers+1] = {x=10,y=9,path={},index=1,job=false,carrying=false,hunger=0,energy=100,workerLook=math.random(2),courier=b.id,deliveryCount=0}
    end
    local def = D.buildings[b.kind]
    if def.workers > 0 and sim:availableWorkers() > 0 then b.workers = def.workers end
    sim:notify(def.name .. "已竣工。")
end
function C.update(sim,dt,offline)
    for _,b in ipairs(sim.buildings) do Sites.queueSupplies(sim,b) end
    -- Each idle slot tick must represent a distinct currently free resident,
    -- even before it becomes hungry and reserves a dining visit.
    local idleResidents=math.max(0,sim:availableWorkers())
    -- Every assigned villager is drawn and charged against the population budget.
    for index = 1,C.maxBuilders do
        local a = sim.builders[index]
        if not a then a={x=10,y=9,path={},index=1,active=false,job=false,phase="idle",timer=0,carrying=false,hunger=0,energy=100,workerLook=math.random(2)}; sim.builders[index]=a end
        local dining=false
        -- Idle builder slots are reusable proxies, not extra residents. A
        -- newly admitted diner reserves a real free villager; existing meals
        -- retain their reservation until the paid visit has safely finished.
        if not a.active and (a.meal or idleResidents>0 and sim:availableWorkers()>0) then
            if not a.meal then idleResidents=idleResidents-1 end
            dining=Meals.tick(sim,a,dt,offline,false)
            if dining then a.restRequested=false end
        end
        if not a.active and not dining and sim:availableWorkers() > 0 then
            local job = nextJob(sim)
            if job then
                local supply=job.kind=="road" or job.delivery
                if Move.route(sim,a,supply and 10 or job.doorX,supply and 9 or job.doorY) then
                    a.active,a.job,a.phase,a.timer=true,job,supply and "collect" or "toSite",0
                end
            end
        end
        if a.active then
            if a.job and a.job.kind=="building" and not a.job.pointId then
                local b=sim.buildings[a.job.building]
                local chosen
                for _,point in ipairs(Sites.ensure(b)) do
                    local reserved=false
                    for _,other in ipairs(sim.builders) do
                        if other~=a and other.job and other.job.building==b.id and other.job.pointId==point.id then reserved=true end
                    end
                    if point.phase==Sites.phase(b) and point.work<point.required-.000001 and not reserved and
                        (not a.job.side or a.job.side==point.side) then chosen=point;break end
                end
                if chosen then
                    local j=a.job
                    j.pointId,j.resource,j.amount,j.pointPhase=chosen.id,chosen.resource,chosen.amount,chosen.phase
                    if a.phase=="hammer" then chosen.delivered=true end
                    if not j.workX then
                        local p=workSite(sim,b,chosen.side)
                        if p then j.workX,j.workY,j.side=p.x,p.y,p.side end
                    end
                else releaseOne(sim,a) end
            end
            if not offline then
                a.hunger=math.min(600,(a.hunger or 0)+dt)
                a.energy=math.max(0,(a.energy or 100)-dt*0.8)
            end
            if a.phase == "collect" then
                if Move.step(a,dt,nil,sim) then a.phase,a.timer="packing",Motion.packingSeconds end
            elseif a.phase == "packing" then
                a.timer = math.max(0,a.timer-dt)
                if a.timer<=Motion.packingSeconds*.5 then a.carrying=true end
                if a.timer == 0 and Move.route(sim,a,a.job.doorX,a.job.doorY) then a.phase,a.carrying="toSite",true end
            elseif a.phase == "toSite" then
                if Move.step(a,dt,nil,sim) then
                    local j=a.job
                    if j.kind=="building" and j.workX then
                        local path=sim:forestPath(j.doorX,j.doorY,j.workX,j.workY)
                        if path then a.path,a.index,a.phase=path,1,"approach" end
                    else a.phase,a.timer="unload",Motion.unloadSeconds end
                end
            elseif a.phase=="approach" then
                if Move.step(a,dt,1.0,sim) then
                    if a.carrying then a.phase,a.timer="unload",Motion.unloadSeconds
                    else
                        local b=sim.buildings[a.job.building]
                        local supplied=Sites.ensure(b)[a.job.pointId].delivered
                        a.phase,a.timer=supplied and "ready" or a.job.advance and "awaitStage" or "waitMaterials",Motion.readySeconds
                    end
                end
            elseif a.phase=="unload" then
                a.timer=math.max(0,a.timer-dt)
                if a.timer<=Motion.unloadSeconds*.25 and a.carrying then
                    a.carrying=false
                    local site=siteFor(sim,a.job)
                    if site then
                        site.deliveredLoads=(site.deliveredLoads or 0)+1
                        if a.job.kind=="building" then Sites.deliver(site,a.job.pointPhase,a.job.resource) end
                    end
                end
                if a.timer==0 then
                    if a.job.supplyOnly then releaseOne(sim,a)
                    else a.phase,a.timer="ready",Motion.readySeconds+(a.job.pointId or index)%4*.17 end
                end
            elseif a.phase=="waitMaterials" then
                local b=sim.buildings[a.job.building]
                Sites.activate(b)
                if Sites.ensure(b)[a.job.pointId].delivered then
                    a.phase,a.timer="ready",Motion.readySeconds+(a.job.pointId%4)*.17
                else releaseOne(sim,a) end
            elseif a.phase=="awaitStage" then
                local b=sim.buildings[a.job.building]
                Sites.activate(b)
                a.timer=(a.timer or 0)+dt
                if Sites.ensure(b)[a.job.pointId].delivered then a.phase,a.timer="ready",Motion.readySeconds+index*.13
                elseif unclaimedCurrentPoint(sim,b,a) then
                    -- Also repair saves made by the former dispatcher in
                    -- which all four workers waited for a later stage.
                    releaseOne(sim,a)
                end
            elseif a.phase=="ready" then
                a.timer=math.max(0,a.timer-dt)
                if a.timer==0 then a.phase="hammer" end
            elseif a.phase=="waitSite" then
                local b=sim.buildings[a.job.building]
                local rest=((a.hunger or 0)>=90 or (a.energy or 100)<=25) and Meals.canEat(sim)
                local job=not rest and (buildingJob(sim,b,a) or buildingJob(sim,b,a,true)) or nil
                if rest then releaseOne(sim,a,true)
                elseif job then
                    local tx,ty=job.delivery and job.doorX or job.workX,job.delivery and job.doorY or job.workY
                    local path=sim:forestPath(math.floor(a.x+.5),math.floor(a.y+.5),tx,ty)
                    if path then a.job,a.path,a.index,a.phase,a.timer=job,path,1,job.delivery and "refillExit" or "approach",0 end
                else
                    a.timer=(a.timer or 0)+dt
                    -- Briefly inspect tools while a neighbouring structural point
                    -- finishes; never march home for an already-prefetched batch.
                    if a.timer>6 then releaseOne(sim,a) end
                end
            elseif a.phase=="recover" then
                a.timer=math.max(0,a.timer-dt)
                if a.timer==0 then a.phase="waitSite" end
            elseif a.phase=="refillExit" then
                if Move.step(a,dt,1.0,sim) and Move.route(sim,a,10,9) then a.phase="collect" end
            elseif a.phase == "hammer" then
                local p=siteFor(sim,a.job)
                if p then
                    local effort=dt*((a.energy or 100)<25 and .65 or 1)
                    local work=Motion.workBetween(a.timer,a.timer+effort)
                    a.timer=a.timer+effort
                    if a.job.kind=="building" then Sites.apply(p,a.job.pointId,work)
                    else p.progress=math.min(1,p.progress+work/2.5) end
                end
                local job=a.job
                if not p or p.progress>=1-.000001 then
                    if p and job.kind=="road" then
                        sim.roads[p.x .. ":" .. p.y],sim.roadCount=true,sim.roadCount+1
                        sim.roadPlanIndex[p.x .. ":" .. p.y]=nil
                        for i,item in ipairs(sim.pendingRoads) do if item==p then table.remove(sim.pendingRoads,i);break end end
                    elseif p and not p.complete then finishBuilding(sim,p) end
                    releaseCrew(sim,job.kind,job.building,job.x,job.y)
                elseif job.kind=="building" then
                    local point=Sites.ensure(p)[job.pointId]
                    if point.work>=point.required-.000001 then a.phase,a.timer="recover",.45 end
                end
            elseif a.phase=="leaveSite" then
                if Move.step(a,dt,1.0,sim) then
                    if a.restRequested then a.active,a.phase=false,"idle"
                    else a.phase="return";Move.route(sim,a,10,9) end
                end
            elseif a.phase == "return" then
                if Move.step(a,dt,nil,sim) then a.active,a.phase=false,"idle" end
            end
        end
    end
end
return C
