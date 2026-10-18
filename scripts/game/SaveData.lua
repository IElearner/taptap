-- Explicit versioned save format. Jobs reference building IDs instead of table identity.
local Sim = require "game.Simulation"
local D = require "game.Definitions"
local Data = { VERSION = 2 }
local fields = { "population", "militia", "lesson", "elapsed", "foodClock", "speed", "paused", "started", "skipped",
    "raid", "victory", "defeat", "health", "combatClock", "roadCount", "wave", "wavesDefeated", "nextRaid", "defended", "timber", "rock", "score" }
local function clone(value)
    if type(value) ~= "table" then return value end
    local result = {}; for k, v in pairs(value) do result[k] = clone(v) end; return result
end
local function number(value, low, high)
    return type(value) == "number" and value == value and value >= low and value <= high
end
local function jobData(job)
    if not job then return false end
    return { building = job.b.id, destination=job.destination and job.destination.id or nil, inbound = job.inbound, resource = job.resource, amount = job.amount,service=job.service or false }
end
function Data.capture(s, savedAt, revision, idleEnabled)
    local world = { stock = clone(s.stock), produced = clone(s.produced), roads = clone(s.roads),
        buildings = {}, jobs = {}, carriers = {}, enemies = clone(s.enemies),
        pendingRoads=clone(s.pendingRoads), builders=clone(s.builders), workers=clone(s.workers),
        guards=clone(s.guards), mealsServed=s.mealsServed, felledTrees=clone(s.felledTrees) }
    for _, name in ipairs(fields) do world[name] = s[name] end
    for _, b in ipairs(s.buildings) do
        local entry = clone(b); entry.cachedConnected, entry.networkRevision, entry.activeWorkers = nil, nil, nil
        world.buildings[#world.buildings + 1] = entry
    end
    for _, job in ipairs(s.jobs) do world.jobs[#world.jobs + 1] = jobData(job) end
    for _, c in ipairs(s.carriers) do
        world.carriers[#world.carriers + 1] = { x = c.x, y = c.y, path = clone(c.path), index = c.index,
            job = jobData(c.job), carrying = c.carrying, hunger=c.hunger or 0, energy=c.energy or 100,
            meal=clone(c.meal or false), facing=c.facing }
    end
    return { version = Data.VERSION, mode = s.mode, seed = s.map.seed, expansion = s.map.expansion,
        savedAt = savedAt, revision = revision or 1, idleEnabled = idleEnabled ~= false, world = world }
end
local function restoreUnsafe(data, mode)
    assert(type(data) == "table" and (data.version == 1 or data.version == Data.VERSION), "version")
    assert(data.mode == mode and (mode == "finite" or mode == "infinite"), "mode")
    assert(number(data.savedAt, 0, 4102444800) and number(data.revision, 1, 1e12), "timestamp")
    assert(number(data.seed, -1e9, 1e9) and number(data.expansion, 0, 1e6) and data.expansion % 1 == 0, "map")
    assert(type(data.idleEnabled) == "boolean" and (mode == "infinite" or data.expansion == 0), "options")
    local w = data.world
    assert(type(w) == "table" and type(w.stock) == "table" and type(w.produced) == "table", "world")
    for _, r in ipairs(D.goods) do
        local value=w.stock[r]
        if value==nil and (r=="livestock" or r=="meat") then value=0 end
        assert(number(value, 0, 1e12), "stock")
    end
    assert(number(w.produced.food, 0, 1e12), "production")
    for _, name in ipairs(fields) do
        local value = w[name]
        if name == "paused" or name == "started" or name == "skipped" or name == "raid" or name == "victory"
            or name == "defeat" or name == "defended" then assert(type(value) == "boolean", name)
        else assert(number(value, 0, 1e12), name) end
    end
    assert(w.health <= 100 and (w.speed == 1 or w.speed == 2) and w.lesson >= 1 and w.lesson <= #D.lessons + 1, "state")
    assert(type(w.roads) == "table" and type(w.buildings) == "table" and #w.buildings >= 1 and #w.buildings <= 10000, "buildings")
    local roads = 0
    for k, value in pairs(w.roads) do
        assert(type(k) == "string" and k:match("^%-?%d+:%-?%d+$") and value == true, "roads")
        roads = roads + 1; assert(roads <= 100000, "road limit")
    end
    assert(type(w.jobs) == "table" and #w.jobs <= 20000 and type(w.carriers) == "table" and #w.carriers >= 3 and #w.carriers <= 10000, "logistics")
    local s = Sim.new(mode, data.seed)
    s.map.expansion = data.expansion
    for _, name in ipairs(fields) do s[name] = w[name] end
    s.stock, s.produced, s.roads = clone(w.stock), clone(w.produced), clone(w.roads)
    s.felledTrees={}
    for k,value in pairs(w.felledTrees or {}) do
        assert(type(k)=="string" and k:match("^%-?%d+:%-?%d+$") and value==true,"felled tree")
        s.felledTrees[k]=true
    end
    s.stock.livestock,s.stock.meat=s.stock.livestock or 0,s.stock.meat or 0
    s.buildings, s.buildingIndex, s.jobs, s.carriers = {}, {}, {}, {}
    for i, b in ipairs(w.buildings) do
        assert(type(b) == "table" and b.id == i and D.buildings[b.kind] and b.kind ~= "road", "building ID")
        assert(number(b.x, -1e9, 1e9) and b.x % 1 == 0 and number(b.y, -1e9, 1e9) and b.y % 1 == 0, "position")
        assert(type(b.complete) == "boolean" and number(b.progress, 0, 1) and number(b.workers, 0, 2), "building state")
        assert(number(b.timer, 0, 1e12) and number(b.buffer, 0, 1e12) and number(b.inputs, 0, 1e12), "buffer")
        if b.kind=="farm" then
            assert(b.farmStep==nil or (number(b.farmStep,0,3) and b.farmStep%1==0),"farm step")
            assert(b.farmWork==nil or number(b.farmWork,0,1e12),"farm work")
        end
        assert(type(b.incoming) == "boolean" and type(b.outgoing) == "boolean", "transit flags")
        local width, height = b.footprintW or 1, b.footprintH or 1
        local maxW, maxH = D.footprint(b.kind)
        assert(number(width, 1, maxW) and width % 1 == 0 and number(height, 1, maxH) and height % 1 == 0, "building footprint")
        for dx = 1-width, 0 do for dy = 1-height, 0 do
            local tileX, tileY = b.x+dx, b.y+dy
            assert(not s:buildingAt(tileX, tileY) and not s.roads[tileX .. ":" .. tileY], "building overlap")
        end end
        assert(number(b.mealStock or 0,0,100) and (b.mealIncoming==nil or type(b.mealIncoming)=="boolean"),"dining inventory")
        local restored = clone(b); restored.cachedConnected, restored.networkRevision = nil, nil
        restored.mealStock,restored.mealIncoming=b.mealStock or 0,b.mealIncoming or false
        if b.kind=="farm" then
            restored.farmStep=b.farmStep or (b.timer>0 and 1 or 0)
            restored.farmWork=b.farmWork or 0
        end
        restored.footprintW, restored.footprintH = width, height
        s.buildings[i] = restored
        for dx = 1-width, 0 do for dy = 1-height, 0 do
            s.buildingIndex[b.x+dx .. ":" .. b.y+dy] = restored
        end end
    end
    assert(s.buildings[1].kind == "store" and s.buildings[1].x == 10 and s.buildings[1].y == 8, "warehouse")
    local function restoreJob(job)
        if job == false then return false end
        assert(type(job) == "table" and s.buildings[job.building], "job building")
        assert(type(job.inbound) == "boolean" and D.names[job.resource] and number(job.amount, 1, 1e12), "job")
        assert(job.service==nil or type(job.service)=="boolean","service job")
        if job.service then assert(job.inbound and job.resource=="food" and job.amount<=2 and s.buildings[job.building].kind=="kitchen","meal delivery") end
        local destination=job.destination and s.buildings[job.destination] or nil
        if job.destination then
            assert(destination and not job.inbound and destination.complete and job.amount<=4,"delivery destination")
            local def=D.buildings[destination.kind]
            assert(def.input==job.resource or def.alternateInput==job.resource,"delivery resource")
        end
        return { b = s.buildings[job.building], destination=destination, inbound = job.inbound, resource = job.resource, amount = job.amount,service=job.service or false }
    end
    for _, job in ipairs(w.jobs) do s.jobs[#s.jobs + 1] = restoreJob(job) end
    for _, c in ipairs(w.carriers) do
        assert(number(c.x, -1e9, 1e9) and number(c.y, -1e9, 1e9) and number(c.index, 1, 100001), "carrier")
        assert(type(c.carrying) == "boolean" and type(c.path) == "table" and #c.path <= 100000, "route")
        for _, p in ipairs(c.path) do assert(type(p) == "table" and number(p.x, -1e9, 1e9) and number(p.y, -1e9, 1e9), "path point") end
        local restored = clone(c); restored.job = restoreJob(c.job)
        restored.energy=restored.energy or 100
        s.carriers[#s.carriers + 1] = restored
    end
    assert(type(w.enemies) == "table" and #w.enemies <= 10000, "enemies")
    for _, e in ipairs(w.enemies) do assert(number(e.x, -1e9, 1e9) and number(e.y, -1e9, 1e9) and number(e.hp, -1e12, 1e12), "enemy state") end
    s.enemies = clone(w.enemies)
    local function validatePath(a)
        assert(type(a.path) == "table" and #a.path <= 100000 and number(a.index,1,100001), "activity path")
        assert(number(a.x,-1e9,1e9) and number(a.y,-1e9,1e9), "activity position")
        for _,p in ipairs(a.path) do
            assert(type(p)=="table" and number(p.x,-1e9,1e9) and number(p.y,-1e9,1e9), "activity path point")
        end
        if a.facing ~= nil then assert(a.facing=="se" or a.facing=="sw" or a.facing=="ne" or a.facing=="nw", "facing") end
    end
    local function validateMeal(a)
        assert(number(a.hunger or 0,0,600), "hunger")
        assert(number(a.energy or 100,0,100), "energy")
        if not a.meal then return end
        local m=a.meal
        assert(type(m)=="table" and number(m.target,1,#s.buildings) and s.buildings[m.target], "dining target")
        local target=s.buildings[m.target]
        assert(target.complete and (target.kind=="kitchen" or target.kind=="store"), "dining building")
        assert(m.phase=="leaveWork" or m.phase=="walk" or m.phase=="queue" or m.phase=="enter" or
            m.phase=="eat" or m.phase=="exit" or m.phase=="return" or m.phase=="returnWork", "meal phase")
        assert(number(m.timer,0,6) and number(m.resumeX,-1e9,1e9) and number(m.resumeY,-1e9,1e9) and type(m.paid)=="boolean", "meal state")
        assert(m.seat==nil or (number(m.seat,1,4) and m.seat%1==0),"dining seat")
        if m.phase=="enter" or m.phase=="eat" or m.phase=="exit" then assert(m.paid,"reserved meal") end
    end
    if data.version >= 2 then
        assert(type(w.pendingRoads)=="table" and #w.pendingRoads<=100000 and type(w.builders)=="table" and #w.builders<=2, "construction")
        s.pendingRoads,s.roadPlanIndex,s.builders={}, {},clone(w.builders)
        for _,p in ipairs(w.pendingRoads) do
            assert(type(p)=="table" and number(p.x,-1e9,1e9) and p.x%1==0 and number(p.y,-1e9,1e9) and p.y%1==0 and number(p.progress,0,1), "road site")
            local k=p.x .. ":" .. p.y
            assert(not s.roads[k] and not s:buildingAt(p.x,p.y) and not s.roadPlanIndex[k], "road overlap")
            local entry=clone(p);s.pendingRoads[#s.pendingRoads+1]=entry;s.roadPlanIndex[k]=entry
        end
        local claims={}
        for _,a in ipairs(s.builders) do
            validatePath(a)
            validateMeal(a)
            a.energy=a.energy or 100
            assert(type(a.active)=="boolean" and type(a.carrying)=="boolean" and number(a.timer,0,1e12), "builder state")
            assert(a.phase=="idle" or a.phase=="collect" or a.phase=="packing" or a.phase=="toSite" or a.phase=="hammer" or a.phase=="return", "builder phase")
            assert(a.active == (a.phase~="idle"), "builder occupancy")
            if a.job then
                local j=a.job
                assert(type(j)=="table" and (j.kind=="road" or j.kind=="building") and a.active and a.phase~="return", "builder job")
                assert(number(j.doorX,-1e9,1e9) and number(j.doorY,-1e9,1e9), "construction door")
                local claim
                if j.kind=="road" then
                    assert(number(j.x,-1e9,1e9) and number(j.y,-1e9,1e9) and s:roadSiteAt(j.x,j.y), "road job")
                    claim="r" .. j.x .. ":" .. j.y
                else
                    assert(number(j.building,1,#s.buildings) and s.buildings[j.building] and not s.buildings[j.building].complete, "building job")
                    claim="b" .. j.building
                end
                assert(not claims[claim], "duplicate construction worker");claims[claim]=true
            else assert(a.phase=="idle" or a.phase=="return", "builder missing job") end
        end
        assert(type(w.workers)=="table" and number(w.mealsServed,0,1e12), "worker activities")
        s.workers,s.mealsServed={},w.mealsServed
        local count=0
        for k,a in pairs(w.workers) do
            count=count+1;assert(count<=20000 and type(k)=="string" and type(a)=="table", "worker limit")
            local b=s.buildings[a.building]
            assert(b and b.complete and number(a.slot,1,b.workers) and a.slot%1==0 and k==a.building .. ":" .. a.slot, "worker slot")
            validatePath(a);validateMeal(a)
            if a.woodPhase then
                assert(b.kind=="woodcutter" and (a.woodPhase=="toTree" or a.woodPhase=="chop" or a.woodPhase=="toCamp"),"woodcutting phase")
                assert(number(a.treeX,-1e9,1e9) and number(a.treeY,-1e9,1e9) and number(a.woodClock or 0,0,1e12),"woodcutting target")
            end
            s.workers[k]=clone(a);s.workers[k].energy=a.energy or 100
        end
        for _,a in ipairs(s.carriers) do validatePath(a);validateMeal(a) end
    else
        -- V1 roads remain completed; actors start at their existing jobs without eating twice.
        for _,a in ipairs(s.carriers) do a.hunger,a.meal=0,false end
    end
    assert(w.guards==nil or (type(w.guards)=="table" and #w.guards==s.militia),"guards")
    s.guards={}
    if w.guards then
        for _,a in ipairs(w.guards) do
            validatePath(a);validateMeal(a)
            local guard=clone(a);guard.energy=guard.energy or 100
            s.guards[#s.guards+1]=guard
        end
    else
        for _=1,s.militia do s.guards[#s.guards+1]={x=10,y=9,path={},index=1,meal=false,hunger=0,energy=100} end
    end
    -- Earlier versions let villagers eat at the warehouse. Keep the save, but
    -- clear that obsolete visit before the first frame can render a fake diner.
    local function clearWarehouseMeal(actor)
        local meal=actor.meal
        if meal and s.buildings[meal.target].kind=="store" then
            actor.meal=false;actor.path={};actor.index=1
        end
    end
    for _,actor in ipairs(s.carriers) do clearWarehouseMeal(actor) end
    for _,actor in pairs(s.workers) do clearWarehouseMeal(actor) end
    for _,actor in ipairs(s.builders) do clearWarehouseMeal(actor) end
    for _,actor in ipairs(s.guards) do clearWarehouseMeal(actor) end
    assert(s:availableWorkers() >= 0, "workforce")
    return s
end
function Data.restore(data, mode)
    local ok, result = pcall(restoreUnsafe, data, mode)
    if ok then return result end
    return nil
end
return Data
