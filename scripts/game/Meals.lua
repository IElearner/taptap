local Move = require "game.Movement"
local Meals = {}
local function floorFood(sim) return sim.mode == "finite" and not sim.skipped and 8 or 0 end
local function occupancy(sim,id)
    local count=0
    local function visit(a)
        local m=a.meal
        if m and m.target == id and (m.phase == "enter" or m.phase == "eat" or m.phase == "exit") then count=count+1 end
    end
    for _,a in ipairs(sim.carriers) do visit(a) end
    for _,a in pairs(sim.workers) do visit(a) end
    return count
end
local function destination(sim,a)
    local best,distance=nil,math.huge
    for _,b in ipairs(sim.buildings) do
        if b.complete and b.kind == "kitchen" and sim:connected(b) then
            local path=sim:path(math.floor(a.x+0.5),math.floor(a.y+0.5),b.x,b.y+1)
            if path and #path < distance then best,distance=b,#path end
        end
    end
    return best or sim.buildings[1]
end
function Meals.tick(sim,a,dt,offline,busy)
    a.hunger=a.hunger or 0
    if not offline then a.hunger=math.min(600,a.hunger+dt) end
    local m=a.meal
    if not m and not offline and not busy and a.hunger >= 90 then
        local target=destination(sim,a)
        local freeCarriers=0
        for _,c in ipairs(sim.carriers) do if not c.meal then freeCarriers=freeCarriers+1 end end
        local carrier=false
        for _,c in ipairs(sim.carriers) do if c==a then carrier=true;break end end
        local stocked=target.kind=="kitchen" and (target.mealStock or 0)>0
        local supply=stocked or sim.stock.food>floorFood(sim)
        -- The final available carrier keeps transporting until the dining room has food.
        if supply and (not carrier or freeCarriers>1 or stocked or target.kind=="store") then
            local resumeX,resumeY=math.floor(a.x+0.5),math.floor(a.y+0.5)
            if Move.route(sim,a,target.x,target.y+1) then
                m={target=target.id,phase="walk",timer=0,resumeX=resumeX,resumeY=resumeY,paid=false}
                a.meal=m
            end
        end
    end
    if not m then return false end
    if m.phase == "walk" then
        if Move.step(a,dt) then m.phase="queue" end
    elseif m.phase == "queue" then
        local target=sim.buildings[m.target]
        local available=target.kind=="kitchen" and (target.mealStock or 0) or math.max(0,sim.stock.food-floorFood(sim))
        if offline then
            m.phase="return";Move.route(sim,a,m.resumeX,m.resumeY)
        elseif available>0 and occupancy(sim,m.target)<2 then
            if target.kind=="kitchen" then target.mealStock=target.mealStock-1
            else sim.stock.food=sim.stock.food-1 end
            sim.mealsServed=sim.mealsServed+1
            m.phase,m.timer,m.paid="enter",0.5,true
        elseif target.kind=="kitchen" and available==0 and not target.mealIncoming and sim.stock.food>floorFood(sim) then
            local amount=math.min(2,sim.stock.food-floorFood(sim))
            sim.stock.food,target.mealIncoming=sim.stock.food-amount,true
            sim.jobs[#sim.jobs+1]={b=target,inbound=true,resource="food",amount=amount,service=true}
        elseif available==0 and not target.mealIncoming and sim.stock.food<=floorFood(sim) then
            m.phase="return";Move.route(sim,a,m.resumeX,m.resumeY)
        end
    elseif m.phase == "enter" or m.phase == "eat" or m.phase == "exit" then
        m.timer=math.max(0,m.timer-dt)
        if m.timer == 0 then
            if m.phase == "enter" then m.phase,m.timer="eat",3.5
            elseif m.phase == "eat" then m.phase,m.timer,a.hunger="exit",0.5,0
            else m.phase="return"; Move.route(sim,a,m.resumeX,m.resumeY) end
        end
    elseif m.phase == "return" then
        if Move.step(a,dt) then a.meal=false;a.path={};a.index=1 end
    end
    return true
end
function Meals.prepareWorkers(sim,dt,offline)
    local alive={}
    for _,b in ipairs(sim.buildings) do
        b.activeWorkers=0
        if b.complete then
            for slot=1,b.workers do
                local key=b.id .. ":" .. slot
                local a=sim.workers[key]
                if not a then
                    a={x=b.x,y=b.y+1,path={},index=1,hunger=(b.id+slot)%5*3,meal=false,building=b.id,slot=slot}
                    sim.workers[key]=a
                end
                alive[key]=true
                if not Meals.tick(sim,a,dt,offline,false) then b.activeWorkers=b.activeWorkers+1 end
            end
        end
    end
    for key in pairs(sim.workers) do if not alive[key] then sim.workers[key]=nil end end
end
function Meals.hidden(sim,a)
    local m=a.meal
    return m and sim.buildings[m.target].kind == "kitchen" and (m.phase == "enter" or m.phase == "eat")
end
return Meals
