-- Fixed point work with material allocations supplied by shared stage batches.
local D=require "game.Definitions"
local Parts=require "game.ConstructionParts"
local Sites={totalWork=36}
local sides={"south","west","north","east"}
function Sites.blueprint(b)
    local points={}
    local phases=b.kind=="farm" and 1 or 4
    local cost=D.buildings[b.kind].cost
    for phase=1,phases do for side=1,4 do
        local part=(phase-1)*4+side
        if D.buildings[b.kind].expanded or b.kind=="farm" or b.kind=="sawmill" or b.kind=="bakery" or (Parts.blueprintModels or Parts.models)[b.kind .. "_site_" .. part] or (Parts.blueprintModels or Parts.models)[b.kind .. "_main_site_" .. part] then
        local stone=phase==1 and (cost.stone or 0)>0
        local resource=stone and "stone" or "wood"
        points[#points+1]={id=#points+1,part=part,phase=phase,side=sides[side],resource=resource}
        end
    end end
    local counts={wood=0,stone=0}
    for _,p in ipairs(points) do counts[p.resource]=counts[p.resource]+1 end
    for _,p in ipairs(points) do
        p.amount=(cost[p.resource] or 0)/math.max(1,counts[p.resource])
        p.required=Sites.totalWork/#points
    end
    return points
end
function Sites.ensure(b)
    if b.buildPoints then return b.buildPoints end
    local points=Sites.blueprint(b)
    local remaining=(b.progress or 0)*Sites.totalWork
    for _,p in ipairs(points) do
        p.work=math.min(p.required,remaining);remaining=math.max(0,remaining-p.work)
        p.delivered=p.work>0
    end
    b.buildPoints=points
    return points
end
function Sites.phase(b)
    for _,p in ipairs(Sites.ensure(b)) do if p.work<p.required-.000001 then return p.phase end end
    return 5
end
function Sites.deliveryAmount(b,phase,resource)
    local amount=0
    for _,p in ipairs(Sites.ensure(b)) do
        if p.phase==phase and p.resource==resource and not p.delivered then amount=amount+p.amount end
    end
    return amount
end
function Sites.supplied(b,phase,resource)
    if b.stageSupplies and b.stageSupplies[phase .. resource] then return true end
    for _,p in ipairs(Sites.ensure(b)) do
        if p.phase==phase and p.resource==resource and p.delivered then return true end
    end
    return false
end
function Sites.activate(b)
    local phase=Sites.phase(b)
    for _,p in ipairs(Sites.ensure(b)) do
        if p.phase<=phase and b.stageSupplies and b.stageSupplies[p.phase .. p.resource] then p.delivered=true end
    end
end
function Sites.deliver(b,phase,resource)
    b.stageSupplies=b.stageSupplies or {}
    b.stageSupplies[phase .. resource]=true
    if phase>Sites.phase(b) then return end
    for _,p in ipairs(Sites.ensure(b)) do
        if p.phase==phase and p.resource==resource then p.delivered=true end
    end
end
-- Carriers and builders are the same ordinary-worker profession. Logistics
-- prepositions stage batches while builders remain on the perimeter.
function Sites.requested(sim,b,phase,resource)
    if Sites.supplied(b,phase,resource) then return true end
    for _,a in ipairs(sim.builders) do
        local j=a.job
        if j and j.building==b.id and j.pointPhase==phase and j.resource==resource and j.delivery then return true end
    end
    local function matches(j)
        return j and j.construction and j.b==b and j.supplyPhase==phase and j.resource==resource
    end
    for _,j in ipairs(sim.jobs) do if matches(j) then return true end end
    for _,a in ipairs(sim.carriers) do if matches(a.job) then return true end end
    return false
end
function Sites.queueSupplies(sim,b)
    if b.complete or not sim:connected(b) then return end
    local seen={}
    for _,p in ipairs(Sites.ensure(b)) do
        local key=p.phase..p.resource
        if not seen[key] and not Sites.requested(sim,b,p.phase,p.resource) then
            seen[key]=true
            local amount=Sites.deliveryAmount(b,p.phase,p.resource)
            if amount>0 then
                sim.jobs[#sim.jobs+1]={b=b,inbound=true,resource=p.resource,amount=amount,construction=true,supplyPhase=p.phase}
            else Sites.deliver(b,p.phase,p.resource) end
        end
    end
end
function Sites.signature(b)
    local bits={}
    for _,p in ipairs(Sites.ensure(b)) do
        bits[#bits+1]=(p.work>=p.required-.000001 and "2" or p.delivered and "1" or "0")
    end
    for phase=1,4 do for _,resource in ipairs({"wood","stone"}) do
        bits[#bits+1]=b.stageSupplies and b.stageSupplies[phase..resource] and "s" or "-"
    end end
    return table.concat(bits)
end
function Sites.apply(b,id,work)
    local p=Sites.ensure(b)[id]
    if not p or not p.delivered then return false end
    p.work=math.min(p.required,p.work+math.max(0,work))
    local total,complete=0,true
    for _,point in ipairs(b.buildPoints) do
        total=total+point.work
        if point.work<point.required-.000001 then complete=false end
    end
    b.progress=math.min(1,total/Sites.totalWork)
    Sites.activate(b)
    return complete
end
return Sites
