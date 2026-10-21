local Sim=require "game.Simulation"
local Data=require "game.SaveData"
local Meals=require "game.Meals"
local Offline=require "game.Offline"
local Construction=require "game.Construction"
local function advance(s,t,offline) for _=1,math.ceil(t*10) do s:update(0.1,offline) end end
local function foodTotal(s)
    local total=s.stock.food
    for _,b in ipairs(s.buildings) do total=total+(b.mealStock or 0) end
    for _,j in ipairs(s.jobs) do if j.service then total=total+j.amount end end
    for _,c in ipairs(s.carriers) do if c.job and c.job.service and not c.handedOff then total=total+c.job.amount end end
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
    local noHall=fresh()
    local initialFood=noHall.stock.food
    advance(noHall,110)
    V.assert(noHall.mealsServed==0 and noHall.stock.food==initialFood,
        "Villagers cannot sit or consume meals before a kitchen exists")
    for _,a in ipairs(noHall.carriers) do V.assert(not a.meal,"No phantom dining trip to the warehouse") end

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
    V.assert(untilTrue(s,function() return s:count("farm")==1 end,180),"Builders finish queued roads and then the production building")
    V.assert(untilTrue(restored,function() return restored:count('farm')==1 end,180),'Restored staged deliveries finish the same farm')
    V.assert(s:path(10,9,6,9) and s.roadCount==2 and #s.pendingRoads==0,"Only completed roads enter the logistics network")
    V.assert(s.stock.wood==wood,"Construction material escrow is not charged twice")
    V.assert(restored:count("farm")==1 and restored.roadCount==s.roadCount,"Restored construction has the same completed outcome")
    V.assert(s:availableWorkers()>=0,"Builders share the real population budget")

    local crew=fresh()
    V.assert(crew:build("house",8,8),"A house starts as a construction site")
    local house=crew:buildingAt(8,8)
    V.assert(house and not house.complete and house.progress==0,"Foundation starts without a finished building")
    local carried=false
    V.assert(untilTrue(crew,function()
        for _,c in ipairs(crew.carriers) do if c.carrying and c.job and c.job.construction and c.job.b==house then carried=true end end
        local assigned=0
        for _,a in ipairs(crew.builders) do if a.job and a.job.building==house.id then assigned=assigned+1 end end
        return assigned==Construction.maxBuilders
    end,60),"Four real villagers can share one construction site after delivery")
    local crewSave=Data.capture(crew,1000,1,true)
    V.assert(Data.restore(cjson.decode(cjson.encode(crewSave)),"finite")~=nil,"A multi-builder site survives save/load")
    V.assert(untilTrue(crew,function()
        local hammering=0
        for _,a in ipairs(crew.builders) do
            if a.job and a.job.building==house.id and a.carrying then carried=true end
            if a.job and a.job.building==house.id and a.phase=="hammer" then hammering=hammering+1 end
        end
        for _,c in ipairs(crew.carriers) do if c.carrying and c.job and c.job.construction and c.job.b==house then carried=true end end
        return hammering>0
    end,60) and carried,"Physical logistics deliver materials before the assigned builders hammer")
    local start=house.progress
    local cycle=require("game.ActorMotion").strokeSeconds
    advance(crew,cycle)
    V.assert(house.progress>start and house.progress-start<=Construction.maxBuilders*cycle/Construction.buildingWork+.00001,
        "A real hammer cycle advances work without exceeding the four-person effort budget")
    local originalPopulation=crew.population
    V.assert(untilTrue(crew,function() return house.complete end,120),"House visibly passes through the work stages")
    V.assert(house.progress==1 and crew.population==originalPopulation+4,
        "The construction crew completes one house and grants its residents once")

    local busy=fresh();busy.population=3;busy:build("road",7,9);advance(busy,15)
    V.assert(busy.roadCount==0 and busy.pendingRoads[1].progress==0,"No free villager means no invisible builder or progress")
    busy.population=4
    V.assert(untilTrue(busy,function() return busy.roadCount==1 end,15),"An available villager picks up the waiting job")
    local paused=fresh();paused:build("road",7,9);advance(paused,1);paused.paused=true
    local before=cjson.encode(paused.builders);advance(paused,5)
    V.assert(cjson.encode(paused.builders)==before,"Pause freezes builder positions and hammer timers")

    local cargo=fresh();cargo:build("woodcutter",8,8)
    V.assert(untilTrue(cargo,function() return cargo:count("woodcutter")==1 end,180),"Real worker completes the resource producer")
    local carried=false
    for _=1,400 do
        cargo:update(0.1)
        for _,c in ipairs(cargo.carriers) do if c.carrying and c.job and c.job.resource=="wood" then carried=true end end
    end
    V.assert(carried and cargo.stock.wood>66,"Physical carriers pick up and deliver actual wood jobs")

    local meal=fresh();V.assert(meal:build("kitchen",8,8),"Dining fixture can plan the kitchen")
    meal.roads["13:9"]=true;meal.roadCount=meal.roadCount+1
    V.assert(meal:build("farm",13,8),"Dining fixture can plan its worker's farm")
    V.assert(untilTrue(meal,function() return meal:count("kitchen")==1 and meal:count("farm")==1 end,240),"Dining requires a completed kitchen and visiting worker")
    -- Isolate the dining conservation fixture from hunger accumulated while
    -- testing those long construction trips above.
    meal=fresh();meal.population=20
    local completedHall=meal:addBuilding('kitchen',8,8,true);completedHall.workers=1;completedHall.mealStock=8
    meal.roads['13:9']=true;meal.roadCount=meal.roadCount+1
    local completedFarm=meal:addBuilding('farm',13,8,true);completedFarm.workers=1
    meal:update(.1)
    local kitchen=meal:buildingAt(8,8)
    V.assert(untilTrue(meal,function()
        for _,c in ipairs(meal.carriers) do if c.job then return false end end
        return #meal.jobs==0
    end,12),"Existing delivery jobs settle before the dining visit")
    meal.stock.food=10;kitchen.mealStock=8
    for _,c in ipairs(meal.carriers) do c.hunger=90 end
    meal:update(0.1)
    local farm=meal:buildingAt(13,8)
    local farmWorker=meal.workers[farm.id .. ":1"]
    V.assert(farmWorker~=nil,"A staffed building supplies a real worker visitor")
    farmWorker.hunger=90
    local kitchenWorker=meal.workers[kitchen.id .. ":1"]
    V.assert(kitchenWorker~=nil,"Cook can also visit the dining room")
    kitchenWorker.hunger=90
    local queued=untilTrue(meal,function()
        local occupied,waiting,seats=0,0,{}
        for _,a in ipairs({meal.carriers[1],meal.carriers[2],meal.carriers[3],farmWorker,kitchenWorker}) do
            local m=a.meal
            if m then
                if m.phase=="queue" then waiting=waiting+1 end
                if m.phase=="enter" or m.phase=="eat" or m.phase=="exit" then
                    occupied=occupied+1
                    if not m.seat or seats[m.seat] then return false end
                    seats[m.seat]=true
                end
            end
        end
        return occupied==4 and waiting==1
    end,18)
    local diningState={}
    for i,c in ipairs(meal.carriers) do diningState[#diningState+1]=i .. ":" .. (c.meal and c.meal.phase or "none") .. "/" .. (c.job and c.job.resource or "idle") end
    diningState[#diningState+1]="w:" .. (farmWorker.meal and farmWorker.meal.phase or "none")
    V.assert(queued,"Four diners occupy distinct seats while the fifth queues " .. table.concat(diningState,",") .. " served=" .. meal.mealsServed .. " food=" .. foodTotal(meal))
    V.assert(foodTotal(meal)==14 and meal.mealsServed==4,"Four visible seats admit four diners and charge four meals")
    local saved=Data.capture(meal,1000,1,true)
    local resumed=Data.restore(cjson.decode(cjson.encode(saved)),"finite")
    V.assert(resumed and resumed.mealsServed==4,"Paid four-seat dining state survives a save inside the kitchen")
    local oldFootprint=cjson.decode(cjson.encode(saved))
    oldFootprint.world.buildings[kitchen.id].footprintCells=nil
    oldFootprint.world.buildings[kitchen.id].footprintW=1
    oldFootprint.world.buildings[kitchen.id].footprintH=1
    V.assert(Data.restore(oldFootprint,"finite")~=nil,"Legacy one-tile canteens remain loadable")
    advance(meal,20);advance(resumed,20)
    V.assert(foodTotal(meal)==13 and foodTotal(resumed)==13 and resumed.mealsServed==5,"Resume does not charge diners a second time: live="..foodTotal(meal).." restored="..foodTotal(resumed).." served="..resumed.mealsServed)
    V.assert(not resumed.carriers[1].meal and resumed.carriers[1].hunger<60,"Diners leave the kitchen and resume their normal activity")
    local idle=Data.restore(saved,"finite");local task=Offline.new(idle,1000,1030,true)
    while not task:step(1024) do end
    V.assert(foodTotal(idle)==14 and idle.mealsServed==4,"Offline completes already-paid meals without consuming new rations")
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
