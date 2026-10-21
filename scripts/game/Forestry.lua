-- Ecology uses its own persisted phase clocks: offline production deliberately
-- leaves the survival clock unchanged, but seedlings must still grow.
local Move=require 'game.Movement'
local F={stumpSeconds=180,growthSeconds=540,radius=6}
local function key(x,y)return math.floor(x)..':'..math.floor(y) end
function F.ensure(sim)
    sim.treeGrowth=sim.treeGrowth or {}
    for k in pairs(sim.felledTrees) do
        if not sim.treeGrowth[k] then
            local x,y=k:match('^(%-?%d+):(%-?%d+)$')
            sim.treeGrowth[k]={x=tonumber(x),y=tonumber(y),phase='stump',age=0}
        end
    end
end
function F.fell(sim,x,y)
    F.ensure(sim)
    sim.treeGrowth[key(x,y)]={x=x,y=y,phase='stump',age=0}
end
local function valid(sim,t)
    return sim:terrain(t.x,t.y)=='forest' and (t.x*17+t.y*31+t.x*t.y*7)%11<7 and not sim.roads[key(t.x,t.y)] and not sim:buildingAt(t.x,t.y) and not sim:roadSiteAt(t.x,t.y)
end
local function routeHome(sim,a,b)
    a.path=sim:forestPath(math.floor(a.x+.5),math.floor(a.y+.5),b.x,b.y+1) or {}
    a.index,a.forestryPhase=1,'return'
end
local function target(sim,b)
    local best,distance
    for _,t in pairs(sim.treeGrowth) do
        local d=math.abs(t.x-b.x)+math.abs(t.y-b.y)
        if d<=F.radius and valid(sim,t) and (not distance or d<distance) then
            local claimed=false
            for _,a in pairs(sim.workers) do
                if a.forestryTarget==key(t.x,t.y) then claimed=true;break end
            end
            if not claimed and sim:forestPath(b.x,b.y+1,t.x,t.y) then best,distance=t,d end
        end
    end
    return best
end
function F.update(sim,dt,offline)
    F.ensure(sim)
    local tended={}
    for _,b in ipairs(sim.buildings) do if b.kind=='forester' and b.complete then
        for slot=1,b.workers do
            local a=sim.workers[b.id..':'..slot]
            if a and not a.meal then
                local t=a.forestryTarget and sim.treeGrowth[a.forestryTarget]
                if a.forestryPhase=='return' then
                    if Move.step(a,dt,.9,sim) then a.forestryPhase,a.forestryTarget=nil,nil;a.path={};a.index=1 end
                elseif b.stopped or not sim:connected(b) then
                    if a.forestryPhase then routeHome(sim,a,b) end
                elseif not a.forestryPhase then
                    t=target(sim,b)
                    if t then
                        a.forestryTarget=key(t.x,t.y)
                        a.path,a.index,a.forestryPhase=sim:forestPath(b.x,b.y+1,t.x,t.y) or {},1,'walk'
                    end
                elseif a.forestryPhase=='walk' then
                    if not t then routeHome(sim,a,b)
                    elseif Move.step(a,dt,.9,sim) then a.forestryPhase='tend';a.forestryClock=0 end
                elseif a.forestryPhase=='tend' then
                    if not t or not valid(sim,t) then routeHome(sim,a,b)
                    elseif math.abs(a.x-t.x)+math.abs(a.y-t.y)>.2 then
                        a.path,a.index,a.forestryPhase=sim:forestPath(math.floor(a.x+.5),math.floor(a.y+.5),t.x,t.y) or {},1,'walk'
                    elseif not offline and ((a.hunger or 0)>=90 or (a.energy or 100)<=25) and require('game.Meals').canEat(sim) then routeHome(sim,a,b)
                    else
                        tended[a.forestryTarget]=true
                        sim.forestryTendSeconds=(sim.forestryTendSeconds or 0)+dt
                        a.forestryClock=(a.forestryClock or 0)+dt
                    end
                end
            end
        end
    end end
    for k,t in pairs(sim.treeGrowth) do
        if valid(sim,t) then
            t.cancelled=false
            local remaining=dt*(tended[k] and 2 or 1)
            if t.phase=='stump' then
                local used=math.min(remaining,F.stumpSeconds-t.age)
                t.age=t.age+used;remaining=remaining-used
                if t.age>=F.stumpSeconds-.000001 then t.phase,t.age='sapling',0 end
            end
            if t.phase=='sapling' then
                t.age=t.age+remaining
                if t.age>=F.growthSeconds-.000001 then
                    sim.felledTrees[k],sim.treeGrowth[k]=nil,nil
                    sim.regrownTrees=(sim.regrownTrees or 0)+1
                    sim.timber=sim.timber+1
                end
            end
        else
            t.phase,t.age,t.cancelled='stump',0,true
        end
    end
end
function F.count(sim,b)
    local count=0
    for _,t in pairs(sim.treeGrowth or {}) do
        if math.abs(t.x-b.x)+math.abs(t.y-b.y)<=F.radius then count=count+1 end
    end
    return count
end
return F
