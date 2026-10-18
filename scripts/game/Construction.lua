local D = require "game.Definitions"
local Move = require "game.Movement"
local Meals = require "game.Meals"
local C = {}
-- Work is measured in worker-seconds; adding builders shortens elapsed time,
-- without changing the amount of work required by a site.
C.maxBuilders = 4
C.buildingWork = 36
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
local function workSite(sim,b)
    local w,h=b.footprintW or 1,b.footprintH or 1
    local left,right,top,bottom=b.x-w,b.x+1,b.y-h,b.y+1
    local candidates={{x=b.x,y=bottom,side="south"},{x=left,y=b.y,side="west"},
        {x=b.x-w+1,y=top,side="north"},{x=right,y=b.y-h+1,side="east"}}
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
            if j and j.kind=="building" and j.building==b.id and j.workX==p.x and j.workY==p.y then occupied=true;break end
        end
        if not occupied and adjacent[p.x .. ":" .. p.y] and sim:forestPath(b.x,b.y+1,p.x,p.y) then return p end
    end
end
local function nextJob(sim)
    for _, p in ipairs(sim.pendingRoads) do
        if claimed(sim,"road",p.x,p.y)==0 then
            for _, d in ipairs(directions) do
                local x,y = p.x+d[1],p.y+d[2]
                if sim:path(10,9,x,y) then return {kind="road",x=p.x,y=p.y,doorX=x,doorY=y} end
            end
        end
    end
    for _, b in ipairs(sim.buildings) do
        if not b.complete and claimed(sim,"building",0,0,b.id)<C.maxBuilders and sim:connected(b) then
            local p=workSite(sim,b)
            if p then return {kind="building",building=b.id,doorX=b.x,doorY=b.y+1,workX=p.x,workY=p.y,side=p.side} end
        end
    end
end
local function releaseCrew(sim,kind,id,x,y)
    for _,a in ipairs(sim.builders) do
        local j=a.job
        if j and j.kind==kind and (kind=="building" and j.building==id or kind=="road" and j.x==x and j.y==y) then
            local onSite=a.phase=="approach" or a.phase=="hammer"
            a.job,a.phase,a.carrying=false,"return",false
            if kind=="building" and onSite then
                local path=sim:forestPath(math.floor(a.x+0.5),math.floor(a.y+0.5),j.doorX,j.doorY)
                if path then a.path,a.index,a.phase=path,1,"leaveSite"
                else Move.route(sim,a,10,9) end
            else Move.route(sim,a,10,9) end
        end
    end
end
local function finishBuilding(sim,b)
    b.complete,b.progress = true,1
    if b.kind == "house" then sim.population = sim.population+4 end
    if b.kind == "courier" then
        sim.carriers[#sim.carriers+1] = {x=10,y=9,path={},index=1,job=false,carrying=false,hunger=0,energy=100}
    end
    local def = D.buildings[b.kind]
    if def.workers > 0 and sim:availableWorkers() > 0 then b.workers = def.workers end
    sim:notify(def.name .. "已竣工。")
end
function C.update(sim,dt,offline)
    -- Every assigned villager is drawn and charged against the population budget.
    for index = 1,C.maxBuilders do
        local a = sim.builders[index]
        if not a then a={x=10,y=9,path={},index=1,active=false,job=false,phase="idle",timer=0,carrying=false,hunger=0,energy=100}; sim.builders[index]=a end
        local dining=false
        if not a.active then dining=Meals.tick(sim,a,dt,offline,false) end
        if not a.active and not dining and sim:availableWorkers() > 0 then
            local job = nextJob(sim)
            if job and Move.route(sim,a,10,9) then
                a.active,a.job,a.phase,a.timer = true,job,"collect",0
            end
        end
        if a.active then
            -- Old saves put every builder at the front door; reserve real perimeter
            -- positions before resuming those jobs.
            if a.job and a.job.kind=="building" and not a.job.workX then
                local b=sim.buildings[a.job.building]
                local p=b and workSite(sim,b)
                if p then
                    a.job.workX,a.job.workY,a.job.side=p.x,p.y,p.side
                    if a.phase=="hammer" then
                        local path=sim:forestPath(math.floor(a.x+0.5),math.floor(a.y+0.5),p.x,p.y)
                        if path then a.path,a.index,a.phase=path,1,"approach" end
                    end
                end
            end
            if not offline then
                a.hunger=math.min(600,(a.hunger or 0)+dt)
                a.energy=math.max(0,(a.energy or 100)-dt*0.8)
            end
            if a.phase == "collect" then
                if Move.step(a,dt) then a.phase,a.timer="packing",0.5 end
            elseif a.phase == "packing" then
                a.timer = math.max(0,a.timer-dt)
                if a.timer == 0 and Move.route(sim,a,a.job.doorX,a.job.doorY) then a.phase,a.carrying="toSite",true end
            elseif a.phase == "toSite" then
                if Move.step(a,dt) then
                    local j=a.job
                    if j.kind=="building" and j.workX then
                        local path=sim:forestPath(j.doorX,j.doorY,j.workX,j.workY)
                        if path then a.path,a.index,a.phase=path,1,"approach" end
                    else a.phase,a.timer,a.carrying="hammer",0,false end
                end
            elseif a.phase=="approach" then
                if Move.step(a,dt,1.35) then a.phase,a.timer,a.carrying="hammer",0,false end
            elseif a.phase == "hammer" then
                local p = siteFor(sim,a.job)
                if p then
                    a.timer = a.timer+dt
                    p.progress = math.min(1,p.progress+dt/(a.job.kind == "road" and 2.5 or C.buildingWork))
                end
                if not p or p.progress >= 1 then
                    local job=a.job
                    if p and job.kind == "road" then
                        sim.roads[p.x .. ":" .. p.y],sim.roadCount=true,sim.roadCount+1
                        sim.roadPlanIndex[p.x .. ":" .. p.y]=nil
                        for i,item in ipairs(sim.pendingRoads) do if item == p then table.remove(sim.pendingRoads,i);break end end
                    elseif p and not p.complete then finishBuilding(sim,p) end
                    releaseCrew(sim,job.kind,job.building,job.x,job.y)
                end
            elseif a.phase=="leaveSite" then
                if Move.step(a,dt,1.35) then a.phase="return";Move.route(sim,a,10,9) end
            elseif a.phase == "return" then
                if Move.step(a,dt) then a.active,a.phase=false,"idle" end
            end
        end
    end
end
return C
