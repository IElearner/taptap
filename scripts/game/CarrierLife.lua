-- Private source-storage excursions; public transport and final delivery
-- remain owned by Simulation. Existing jobs opt in only at creation.
local E=require 'game.Economy'
local Move=require 'game.Movement'
local Sites=require 'game.WorkSites'
local C={loadSeconds=1.2}
function C.storage(b)
    return Sites.pickupPoint(b)
end
local function workerFinishing(sim,b)
    for _,a in pairs(sim.workers)do
        if a.building==b.id and a.workLoad then return true end
        if a.building==b.id and a.rackVisit and(a.woodPhase=='toRack'and not a.rackWaiting or a.woodPhase=='stack'or a.woodPhase=='fromRack')then return true end
        local l=a.building==b.id and a.life
        if l and not a.meal and(l.phase=='toTank'or l.phase=='toStack'or l.phase=='stow')then return true end
    end
    return false
end
function C.eligible(sim,b)
    local site=Sites.ensure(sim,b);local target=site and C.storage(b)
    if not target or not Sites.storageKind(b.kind)then return false end
    local scratch={x=b.x,y=b.y+1,path={},index=1}
    return Sites.route(sim,scratch,b,target)
end
local function speed(a)return(a.energy or 100)<25 and .65 or a.carrying and .85 or 1.05 end
local function start(sim,a,b,state)
    if workerFinishing(sim,b)or E.outputAmount(b,a.job.resource)<a.job.amount then return false end
    if not Sites.route(sim,a,b,state.target)then return false end
    state.phase,state.clock='approach',0
    return true
end
function C.update(sim,a,dt)
    local job=a.job
    if not job or not job.sitePickup or job.inbound then return false end
    local state=a.sitePickup
    if not state then
        if job.pickedUp then return false end
        if a.phase~='packing'then
            if a.path[a.index]then return false end
            local atDoor=math.abs(a.x-job.b.x)<.01 and math.abs(a.y-job.b.y-1)<.01
            if atDoor and sim.roads[job.b.x..':'..(job.b.y+1)]then return false end
        end
        local target=C.storage(job.b)
        if not target then return false end
        state={building=job.b.id,phase=a.phase=='packing'and 'waiting'or 'waitingSource',clock=0,target={x=target.x,y=target.y},door={x=job.b.x,y=job.b.y+1}}
        a.sitePickup=state
    end
    state.clock=state.clock+dt
    if state.phase=='waitingSource'then
        local route=sim:path(math.floor(a.x+.5),math.floor(a.y+.5),job.b.x,job.b.y+1)
        if route then a.path,a.index,a.phase=route,1,'travel';a.sitePickup=nil end
    elseif state.phase=='waitingRoute'then
        local x,y=10,9;if job.destination then x,y=job.destination.x,job.destination.y+1 end
        local route=sim:path(job.b.x,job.b.y+1,x,y)
        if route then a.path,a.index,a.phase=route,1,'travel';a.sitePickup=nil;a.doorDuration=nil;a.timer=0 end
    elseif state.phase=='waiting'then
        -- Waiting at a public door is not an equipment claim. Once approach
        -- begins, never wait on a new worker load: that worker yields to us.
        if start(sim,a,job.b,state)then Move.step(a,dt,speed(a),sim)end
    elseif state.phase=='approach'then
        if Move.step(a,dt,speed(a),sim)then state.phase,state.clock='loading',0 end
    elseif state.phase=='loading'then
        if state.clock>=C.loadSeconds/2 and not job.pickedUp then
            if E.outputAmount(job.b,job.resource)<job.amount then return true end
            E.take(job.b,job.resource,job.amount)
            job.pickedUp,a.carrying=true,true
        end
        if state.clock>=C.loadSeconds and job.pickedUp then
            if Sites.route(sim,a,job.b,state.door)then state.phase,state.clock='return',0 end
        end
    elseif state.phase=='return'then
        if Move.step(a,dt,speed(a),sim)then
            local x,y=10,9
            if job.destination then x,y=job.destination.x,job.destination.y+1 end
            local route=sim:path(job.b.x,job.b.y+1,x,y)
            if route then a.sitePickup=nil;a.path,a.index,a.phase=route,1,'travel';a.doorDuration=nil;a.timer=0
            else state.phase,state.clock='waitingRoute',0;a.path={};a.index=1 end
        end
    end
    return true
end
return C
