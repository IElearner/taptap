local Sim=require "game.Simulation"
local Data=require "game.SaveData"
local Meals=require "game.Meals"
local Offline=require "game.Offline"
local function advance(s,t,offline) for _=1,math.ceil(t*10) do s:update(0.1,offline) end end
local function foodTotal(s)
    local total=s.stock.food
    for _,b in ipairs(s.buildings) do total=total+(b.mealStock or 0) end
    for _,j in ipairs(s.jobs) do if j.service then total=total+j.amount end end
    for _,c in ipairs(s.carriers) do if c.job and c.job.service then total=total+c.job.amount end end
    return total
end
local function fresh()
    local s=Sim.new();s.started,s.skipped=true,true;s.stock.food=200;return s
end
local function untilTrue(s,predicate,seconds)
    for _=1,seconds*10 do if predicate() then return true end;s:update(0.1) end
    return predicate()
end
V.atFrame(8,function()
    local s=fresh()
    V.assert(s:build("road",7,9) and s:build("road",6,9),"Connected road plans can be queued")
    V.assert(s:build("farm",6,8),"Foundation can wait beside a planned access road")
    V.assert(not s:path(10,9,6,9) and s.roadCount==0,"Planned roads do not teleport into usable logistics")
    V.assert(not s:build("road",7,9),"Duplicate plans cannot create duplicate construction")
    local wood=s.stock.wood
    advance(s,0.5)
    V.assert(#s.builders>0 and s.builders[1].active and s.pendingRoads[1].progress==0,"Builder collects materials before progress begins")
    local checkpoint=Data.capture(s,1000,1,true)
    local restored=Data.restore(cjson.decode(cjson.encode(checkpoint)),"finite")
    V.assert(restored and #restored.pendingRoads==2 and restored.builders[1].active,"Construction and routes survive JSON save/load")
    V.assert(untilTrue(s,function() return s:count("farm")==1 end,45),"Builders finish queued roads and then the production building")
    advance(restored,45)
    V.assert(s:path(10,9,6,9) and s.roadCount==2 and #s.pendingRoads==0,"Only completed roads enter the logistics network")
    V.assert(s.stock.wood==wood,"Construction material escrow is not charged twice")
    V.assert(restored:count("farm")==1 and restored.roadCount==s.roadCount,"Restored construction has the same completed outcome")
    V.assert(s:availableWorkers()>=0,"Builders share the real population budget")

    local busy=fresh();busy.population=3;busy:build("road",7,9);advance(busy,15)
    V.assert(busy.roadCount==0 and busy.pendingRoads[1].progress==0,"No free villager means no invisible builder or progress")
    busy.population=4
    V.assert(untilTrue(busy,function() return busy.roadCount==1 end,15),"An available villager picks up the waiting job")
    local paused=fresh();paused:build("road",7,9);advance(paused,1);paused.paused=true
    local before=cjson.encode(paused.builders);advance(paused,5)
    V.assert(cjson.encode(paused.builders)==before,"Pause freezes builder positions and hammer timers")

    local cargo=fresh();cargo:build("woodcutter",8,8)
    V.assert(untilTrue(cargo,function() return cargo:count("woodcutter")==1 end,20),"Real worker completes the resource producer")
    local carried=false
    for _=1,400 do
        cargo:update(0.1)
        for _,c in ipairs(cargo.carriers) do if c.carrying and c.job and c.job.resource=="wood" then carried=true end end
    end
    V.assert(carried and cargo.stock.wood>66,"Physical carriers pick up and deliver actual wood jobs")

    local meal=fresh();meal:build("kitchen",8,8);meal:build("farm",9,8)
    V.assert(untilTrue(meal,function() return meal:count("kitchen")==1 and meal:count("farm")==1 end,25),"Dining requires a completed kitchen and visiting worker")
    local kitchen=meal:buildingAt(8,8);meal:staff(kitchen,-1)
    V.assert(untilTrue(meal,function()
        for _,c in ipairs(meal.carriers) do if c.job then return false end end
        return #meal.jobs==0
    end,12),"Existing delivery jobs settle before the dining visit")
    meal.stock.food=10
    for i,c in ipairs(meal.carriers) do c.hunger=i<=2 and 90 or 0 end
    meal:update(0.1)
    local farm=meal:buildingAt(9,8)
    local farmWorker=meal.workers[farm.id .. ":1"]
    V.assert(farmWorker~=nil,"A staffed building supplies a real worker visitor")
    farmWorker.hunger=90
    local queued=untilTrue(meal,function()
        local occupied,waiting=0,0
        for _,a in ipairs({meal.carriers[1],meal.carriers[2],farmWorker}) do
            local m=a.meal
            if m then
                if m.phase=="queue" then waiting=waiting+1 end
                if m.phase=="enter" or m.phase=="eat" or m.phase=="exit" then occupied=occupied+1 end
            end
        end
        return occupied==2 and waiting==1
    end,15)
    local diningState={}
    for i,c in ipairs(meal.carriers) do diningState[#diningState+1]=i .. ":" .. (c.meal and c.meal.phase or "none") .. "/" .. (c.job and c.job.resource or "idle") end
    diningState[#diningState+1]="w:" .. (farmWorker.meal and farmWorker.meal.phase or "none")
    V.assert(queued,"Two diners enter the kitchen while the third queues outside " .. table.concat(diningState,",") .. " served=" .. meal.mealsServed .. " food=" .. foodTotal(meal))
    V.assert(foodTotal(meal)==8 and meal.mealsServed==2,"Transport reserves rations; only two admitted diners consume two meals")
    local saved=Data.capture(meal,1000,1,true)
    local resumed=Data.restore(cjson.decode(cjson.encode(saved)),"finite")
    V.assert(resumed and resumed.mealsServed==2,"Paid dining state survives a save inside the kitchen")
    advance(meal,20);advance(resumed,20)
    V.assert(foodTotal(meal)==7 and foodTotal(resumed)==7 and resumed.mealsServed==3,"Resume does not charge diners a second time")
    V.assert(not resumed.carriers[1].meal and resumed.carriers[1].hunger<60,"Diners leave the kitchen and resume their normal activity")
    local idle=Data.restore(saved,"finite");local task=Offline.new(idle,1000,1030,true)
    while not task:step(1024) do end
    V.assert(foodTotal(idle)==8 and idle.mealsServed==2,"Offline completes already-paid meals without consuming new rations")
    local legacy=cjson.decode(cjson.encode(saved));legacy.version=1
    legacy.world.builders,legacy.world.pendingRoads,legacy.world.workers,legacy.world.mealsServed=nil,nil,nil,nil
    for _,c in ipairs(legacy.world.carriers) do c.meal,c.hunger=nil,nil end
    V.assert(Data.restore(legacy,"finite")~=nil,"Original V1 saves migrate without losing their village")
    local bad=cjson.decode(cjson.encode(saved));bad.world.workers[farm.id .. ":1"].meal.target=9999
    V.assert(not Data.restore(bad,"finite"),"Corrupt dining references are rejected")
    bad=cjson.decode(cjson.encode(checkpoint));bad.world.pendingRoads[2]=bad.world.pendingRoads[1]
    V.assert(not Data.restore(bad,"finite"),"Overlapping road plans cannot corrupt construction state")
end)
V.atFrame(25,function() V.finish() end)
