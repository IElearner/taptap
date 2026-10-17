local D = require "game.Definitions"
local Move = require "game.Movement"
local C = {}
local directions = { {1,0}, {-1,0}, {0,1}, {0,-1} }
function C.busy(sim)
    local count = 0
    for _, a in ipairs(sim.builders) do if a.active then count = count+1 end end
    return count
end
local function claimed(sim, kind, x, y, id)
    for _, a in ipairs(sim.builders) do
        local j = a.job
        if j and j.kind == kind and (kind == "road" and j.x == x and j.y == y or kind == "building" and j.building == id) then return true end
    end
    return false
end
local function siteFor(sim, job)
    if job.kind == "road" then return sim:roadSiteAt(job.x,job.y) end
    return sim.buildings[job.building]
end
local function nextJob(sim)
    for _, p in ipairs(sim.pendingRoads) do
        if not claimed(sim,"road",p.x,p.y) then
            for _, d in ipairs(directions) do
                local x,y = p.x+d[1],p.y+d[2]
                if sim:path(10,9,x,y) then return {kind="road",x=p.x,y=p.y,doorX=x,doorY=y} end
            end
        end
    end
    for _, b in ipairs(sim.buildings) do
        if not b.complete and not claimed(sim,"building",0,0,b.id) and sim:connected(b) then
            return {kind="building",building=b.id,doorX=b.x,doorY=b.y+1}
        end
    end
end
local function finishBuilding(sim,b)
    b.complete,b.progress = true,1
    if b.kind == "house" then sim.population = sim.population+4 end
    if b.kind == "courier" then
        sim.carriers[#sim.carriers+1] = {x=10,y=9,path={},index=1,job=false,carrying=false}
    end
    local def = D.buildings[b.kind]
    if def.workers > 0 and sim:availableWorkers() > 0 then b.workers = def.workers end
    sim:notify(def.name .. "已竣工。")
end
function C.update(sim,dt)
    -- Construction uses up to two genuinely idle villagers, never extra population.
    for index = 1,2 do
        local a = sim.builders[index]
        if not a then a={x=10,y=9,path={},index=1,active=false,job=false,phase="idle",timer=0,carrying=false}; sim.builders[index]=a end
        if not a.active and sim:availableWorkers() > 0 then
            local job = nextJob(sim)
            if job and Move.route(sim,a,10,9) then
                a.active,a.job,a.phase,a.timer = true,job,"collect",0
            end
        end
        if a.active then
            if a.phase == "collect" then
                if Move.step(a,dt) then a.phase,a.timer="packing",0.5 end
            elseif a.phase == "packing" then
                a.timer = math.max(0,a.timer-dt)
                if a.timer == 0 and Move.route(sim,a,a.job.doorX,a.job.doorY) then a.phase,a.carrying="toSite",true end
            elseif a.phase == "toSite" then
                if Move.step(a,dt) then a.phase,a.timer,a.carrying="hammer",0,false end
            elseif a.phase == "hammer" then
                local p = siteFor(sim,a.job)
                if p then
                    a.timer = a.timer+dt
                    p.progress = math.min(1,p.progress+dt/(a.job.kind == "road" and 2.5 or 5))
                end
                if not p or p.progress >= 1 then
                    if p and a.job.kind == "road" then
                        sim.roads[p.x .. ":" .. p.y],sim.roadCount=true,sim.roadCount+1
                        sim.roadPlanIndex[p.x .. ":" .. p.y]=nil
                        for i,item in ipairs(sim.pendingRoads) do if item == p then table.remove(sim.pendingRoads,i);break end end
                    elseif p then finishBuilding(sim,p) end
                    a.job,a.phase,a.carrying = false,"return",false
                    Move.route(sim,a,10,9)
                end
            elseif a.phase == "return" then
                if Move.step(a,dt) then a.active,a.phase=false,"idle" end
            end
        end
    end
end
return C
