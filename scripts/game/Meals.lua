local Move = require "game.Movement"
local Farm = require "game.FarmCycle"
local Meals = { seats = 4, pantryCapacity = 8 }
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
function Meals.diningSide(sim,b)
    -- Prefer the door side, but place the open dining bay on the clearer side
    -- when another building crowds it. Compare projected roof centers.
    local function center(building)
        local x=building.x-((building.footprintW or 1)-1)*0.5
        local y=building.y-((building.footprintH or 1)-1)*0.5
        return x*56,y*42
    end
    local hx,hy=center(b)
    local function crowd(side)
        local score=0
        for _,other in ipairs(sim.buildings) do
            if other~=b and other.kind~="farm" then
                local ox,oy=center(other)
                local dx=math.abs(ox-(hx+side*75))
                local dy=math.abs(oy-(hy+18))
                score=score+math.max(0,105-dx)*math.max(0,65-dy)
            end
        end
        return score
    end
    return crowd(1)+500<crowd(-1) and 1 or -1
end
function Meals.seatPosition(b,seat,side)
    local column=(seat-1)%2
    local row=math.floor((seat-1)/2)
    return b.x-((b.footprintW or 1)-1)*0.5+(column-0.5)*0.62,
        b.y-((b.footprintH or 1)-1)*0.5+0.48+row*0.52
end
local function freeSeat(sim,id,actor)
    local taken={}
    visitors(sim,function(a)
        local m=a.meal
        if a~=actor and inside(m,id) and m.seat then taken[m.seat]=true end
    end)
    for seat=1,Meals.seats do if not taken[seat] then return seat end end
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
function Meals.tick(sim,a,dt,offline,busy,working)
    a.hunger=a.hunger or 0
    a.energy=a.energy or 100
    if not offline then
        a.hunger=math.min(600,a.hunger+dt)
        if not a.meal then a.energy=math.max(0,a.energy-dt*((busy or working) and 0.8 or 0.35)) end
    end
    local m=a.meal
    if not m and not offline and not busy and (a.hunger >= 90 or a.energy <= 25) then
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
        elseif available>0 and occupancy(sim,m.target)<Meals.seats then
            local seat=freeSeat(sim,m.target,a)
            if not seat then return true end
            if target.kind=="kitchen" then target.mealStock=target.mealStock-1
            else sim.stock.food=sim.stock.food-1 end
            sim.mealsServed=sim.mealsServed+1
            m.phase,m.timer,m.paid,m.seat="enter",0.7,true,seat
        elseif target.kind=="kitchen" and available==0 and not target.mealIncoming and sim.stock.food>floorFood(sim) then
            local amount=math.min(2,Meals.pantryCapacity-(target.mealStock or 0),sim.stock.food-floorFood(sim))
            if amount<=0 then return true end
            sim.stock.food,target.mealIncoming=sim.stock.food-amount,true
            sim.jobs[#sim.jobs+1]={b=target,inbound=true,resource="food",amount=amount,service=true}
        elseif available==0 and not target.mealIncoming and sim.stock.food<=floorFood(sim) then
            m.phase="return";Move.route(sim,a,m.resumeX,m.resumeY)
        end
    elseif m.phase == "enter" or m.phase == "eat" or m.phase == "exit" then
        -- Saves from the earlier two-seat version have no seat index.
        if not m.seat then m.seat=freeSeat(sim,m.target,a) end
        m.timer=math.max(0,m.timer-dt)
        if m.timer == 0 then
            if m.phase == "enter" then m.phase,m.timer="eat",5
            elseif m.phase == "eat" then m.phase,m.timer,a.hunger,a.energy="exit",0.7,0,100
            else m.phase,m.seat="return",nil; Move.route(sim,a,m.resumeX,m.resumeY) end
        end
    elseif m.phase == "return" then
        if Move.step(a,dt) then a.meal=false;a.path={};a.index=1 end
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
                    a={x=b.x,y=b.y+1,path={},index=1,hunger=(b.id+slot)%5*3,energy=100,meal=false,building=b.id,slot=slot}
                    sim.workers[key]=a
                end
                alive[key]=true
                local working=b.kind~="farm" or Farm.needsWork(b,require("game.Definitions").buildings.farm.period)
                local eating=Meals.tick(sim,a,dt,offline,b.kind=="woodcutter" and a.woodPhase~=nil,working)
                if b.kind=="farm" and not offline then
                    local target=working and not eating and 1 or 0
                    local presence=a.farmPresence or 0
                    a.farmPresence=math.max(0,math.min(1,presence+(target==1 and 1 or -1)*dt*0.85))
                end
                if not eating then
                    b.activeWorkers=b.activeWorkers+1
                    local atWork=b.kind~="farm" or offline or (a.farmPresence or 0)>=0.95
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
