-- Explicit versioned save format. Jobs reference building IDs instead of table identity.
local Sim = require "game.Simulation"
local D = require "game.Definitions"
local Sites = require "game.ConstructionSites"
local Cargo = require "game.Cargo"
local Economy=require "game.Economy"
local Forestry=require "game.Forestry"
local Military=require "game.Military"
local Deposits=require "game.Deposits"
local WorkSites=require 'game.WorkSites'
local Data = { VERSION = 12 }
local fields = { "population", "militia", "lesson", "elapsed", "foodClock", "speed", "paused", "started", "skipped",
    "raid", "victory", "defeat", "health", "combatClock", "roadCount", "wave", "wavesDefeated", "nextRaid", "defended", "timber", "rock", "score", "forestryTendSeconds", "fishMealsCooked", "campaignCompleted", "freePlay", "campaignRaid", "milestoneEligible", "campaignMilestoneWave" }
local function clone(value)
    if type(value) ~= "table" then return value end
    local result = {}; for k, v in pairs(value) do result[k] = clone(v) end; return result
end
local function number(value, low, high)
    return type(value) == "number" and value == value and value >= low and value <= high
end
local function jobData(job)
    if not job then return false end
    return { building = job.b.id, destination=job.destination and job.destination.id or nil, inbound = job.inbound, resource = job.resource, amount = job.amount,service=job.service or false, pickedUp=job.pickedUp or false, construction=job.construction or false,supplyPhase=job.supplyPhase,sitePickup=job.sitePickup or nil }
end
function Data.capture(s, savedAt, revision, idleEnabled)
    local world = { stock = clone(s.stock), produced = clone(s.produced), roads = clone(s.roads),
        buildings = {}, jobs = {}, carriers = {}, enemies = clone(s.enemies),
        pendingRoads=clone(s.pendingRoads), builders=clone(s.builders), workers=clone(s.workers),
        guards=clone(s.guards), mealsServed=s.mealsServed, felledTrees=clone(s.felledTrees),treeGrowth=clone(s.treeGrowth),minerals=clone(s.minerals),regrownTrees=s.regrownTrees or 0 }
    for _, name in ipairs(fields) do world[name] = s[name] end
    for _, b in ipairs(s.buildings) do
        if D.buildings[b.kind].output then Economy.normalizeOutputs(b) end
        local entry = clone(b); entry.cachedConnected, entry.networkRevision, entry.activeWorkers = nil, nil, nil
        world.buildings[#world.buildings + 1] = entry
    end
    for _, job in ipairs(s.jobs) do world.jobs[#world.jobs + 1] = jobData(job) end
    for _, c in ipairs(s.carriers) do
        local entry=clone(c)
        entry.job=jobData(c.job)
        entry.hunger,entry.energy,entry.meal=c.hunger or 0,c.energy or 100,clone(c.meal or false)
        world.carriers[#world.carriers+1]=entry
    end
    return { version = Data.VERSION, mode = s.mode, seed = s.map.seed, expansion = s.map.expansion, worldSize=s.map.worldSize,
        savedAt = savedAt, revision = revision or 1, idleEnabled = idleEnabled ~= false, world = world }
end
local function restoreUnsafe(data, mode)
    assert(type(data) == "table" and (data.version == 1 or data.version == 2 or data.version == 3 or data.version == 4 or data.version == 5 or data.version == 6 or data.version == 7 or data.version==8 or data.version==9 or data.version==10 or data.version==11 or data.version == Data.VERSION), "version")
    assert(data.mode == mode and (mode == "finite" or mode == "infinite"), "mode")
    assert(number(data.savedAt, 0, 4102444800) and number(data.revision, 1, 1e12), "timestamp")
    assert(number(data.seed, -1e9, 1e9) and number(data.expansion, 0, 1e6) and data.expansion % 1 == 0, "map")
    assert(type(data.idleEnabled) == "boolean" and (mode == "infinite" or data.expansion == 0), "options")
    local w = data.world
    assert(type(w) == "table" and type(w.stock) == "table" and type(w.produced) == "table", "world")
    for _, r in ipairs(D.goods) do
        local value=w.stock[r]
        if value==nil and (r=="livestock" or r=="meat" or r=="rawwood" or r=="bread" or data.version<5 and D.expandedGoods[r]) then value=0 end
        assert(number(value, 0, 1e12), "stock")
    end
    assert(number(w.produced.food, 0, 1e12), "production")
    if data.version<7 then
        w.forestryTendSeconds,w.fishMealsCooked=0,0
        w.campaignCompleted,w.freePlay,w.campaignRaid=false,false,false
        if w.skipped then w.lesson=#D.lessons+1 end
    end
    if data.version<8 then w.milestoneEligible,w.campaignMilestoneWave=false,0 end
    for _, name in ipairs(fields) do
        local value = w[name]
        if name == "paused" or name == "started" or name == "skipped" or name == "raid" or name == "victory"
            or name == "defeat" or name == "defended" or name == "campaignCompleted" or name == "freePlay" or name == "campaignRaid" or name == "milestoneEligible" then assert(type(value) == "boolean", name)
        else assert(number(value, 0, 1e12), name) end
    end
    assert(w.campaignMilestoneWave%1==0 and w.campaignMilestoneWave<=w.wave,"campaign milestone wave")
    assert(not w.milestoneEligible or mode=="infinite" and w.raid and w.wave>=4 and w.campaignMilestoneWave==w.wave and not w.campaignCompleted,"campaign milestone eligibility")
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
    local worldSize=data.worldSize or 22
    assert((worldSize==22 or worldSize==30) and (mode=="finite" or worldSize==22),"world size")
    s.map.worldSize=worldSize
    for _, name in ipairs(fields) do s[name] = w[name] end
    s.stock, s.produced, s.roads = clone(w.stock), clone(w.produced), clone(w.roads)
    s.felledTrees={}
    for k,value in pairs(w.felledTrees or {}) do
        assert(type(k)=="string" and k:match("^%-?%d+:%-?%d+$") and value==true,"felled tree")
        s.felledTrees[k]=true
    end
    s.stock.livestock,s.stock.meat=s.stock.livestock or 0,s.stock.meat or 0
    for _,resource in ipairs(D.goods)do s.stock[resource]=s.stock[resource] or 0 end
    s.stock.rawwood,s.stock.bread=s.stock.rawwood or 0,s.stock.bread or 0
    if data.version<4 then
        -- Old lesson progress stays on its original objective; the two new
        -- production steps are available through the revised mentor route.
        s.lesson=({1,2,3,4,6,7,9,10,11})[s.lesson] or s.lesson
    end
    s.buildings, s.buildingIndex, s.jobs, s.carriers = {}, {}, {}, {}
    for i, b in ipairs(w.buildings) do
        assert(type(b) == "table" and b.id == i and D.buildings[b.kind] and b.kind ~= "road", "building ID")
        assert(number(b.x, -1e9, 1e9) and b.x % 1 == 0 and number(b.y, -1e9, 1e9) and b.y % 1 == 0, "position")
        assert(type(b.complete) == "boolean" and number(b.progress, 0, 1) and number(b.workers, 0, D.buildings[b.kind].maxWorkers or 2), "building state")
        assert(number(b.timer, 0, 1e12) and number(b.buffer, 0, 1e12) and number(b.inputs, 0, 1e12), "buffer")
        if b.kind=="mill" then
            if data.version<6 then b.recipeVersion=1 end
            assert(b.recipeVersion==1 or b.recipeVersion==2,"mill recipe version")
        end
        if b.kind=="farm" then
            assert(b.farmStep==nil or (number(b.farmStep,0,3) and b.farmStep%1==0),"farm step")
            assert(b.farmWork==nil or number(b.farmWork,0,1e12),"farm work")
        end
        if b.inputGoods~=nil then
            assert(type(b.inputGoods)=="table","typed input stock")
            local total=0;local def=D.buildings[b.kind]
            for resource,amount in pairs(b.inputGoods) do
                assert(Economy.allowed(b,resource) and number(amount,0,1e12),"input resource")
                total=total+amount
            end
            assert(math.abs(total-b.inputs)<.000001,"typed inputs conserve inventory")
        end
        if b.outputGoods~=nil then
            assert(type(b.outputGoods)=="table","typed output shelf")
            local total=0
            for resource,amount in pairs(b.outputGoods)do assert(D.names[resource] and number(amount,0,1e12),"output resource");total=total+amount end
            assert(math.abs(total-b.buffer)<.000001,"typed outputs conserve inventory")
        end
        assert(b.stopped==nil or type(b.stopped)=="boolean","production stop flag")
        assert(b.lifeEnabled==nil or type(b.lifeEnabled)=='boolean','civilian life flag')
        assert(b.lifeOutputHeld==nil or number(b.lifeOutputHeld,0,100),'reserved work output')
        assert(b.workOutputHeld==nil or number(b.workOutputHeld,0,100),'carried workshop output')
        if b.site then
            local site=b.site
            assert(type(site)=='table'and(site.version==1 or site.version==2)and type(site.yardCells)=='table'and #site.yardCells<=100,'activity plot')
            local function point(p,integer)
                assert(type(p)=='table'and number(p.x,-1e9,1e9)and number(p.y,-1e9,1e9)and(not integer and site.compound or p.x%1==0 and p.y%1==0),'activity point')
            end
            point(site.door,true)
            if site.profile=='breaks'then
                assert(WorkSites.breakKinds[b.kind]and type(site.idleCells)=='table'and #site.idleCells==2,'workshop rest profile')
                for _,p in ipairs(site.idleCells)do point(p)end
                if site.workCell or site.storageCell then point(site.workCell);point(site.storageCell)end
            elseif WorkSites.managed(b.kind)then point(site.chairCell);point(site.tankCell);if site.stackCell then point(site.stackCell)end
            elseif b.kind=='woodcutter'and site.storageCell then
                assert(site.compound,'logging rack requires a registered compound');point(site.storageCell);point(site.rackCell)
                assert(site.rackCell.x==site.storageCell.x and site.rackCell.y==site.storageCell.y,'logging rack identity')
            end
            for _,p in ipairs(site.yardCells)do point(p,true)end
            if site.restCells then for _,p in ipairs(site.restCells)do point(p)end end
            if site.compound then
                local c=site.compound;local r=c.bounds
                assert(type(c)=='table'and c.version==1 and(c.ground=='wood'or c.ground=='stone'or c.ground=='earth'),'compound profile')
                assert(type(r)=='table'and #r==4 and number(r[1],-512,512)and number(r[2],-512,512)and number(r[3],-512,512)and number(r[4],-512,512)and r[1]<r[3]and r[2]<r[4],'compound bounds')
                point(c.entrance)
                assert(type(c.foundationCells)=='table'and #c.foundationCells==#site.yardCells,'whole compound reservation')
                local set={};for _,p in ipairs(site.yardCells)do set[p.x..':'..p.y]=true end
                for _,p in ipairs(c.foundationCells)do point(p,true);assert(set[p.x..':'..p.y],'compound reservation identity')end
                assert(type(c.deckCells)=='table'and #c.deckCells<=12,'small declared deck')
                for _,p in ipairs(c.deckCells)do point(p,true);assert(b.kind=='fishery'and c.ground=='wood'and set[p.x..':'..p.y]and s:terrain(p.x,p.y)=='water','declared water deck')end
                if c.source then
                    point(c.source,true);assert(type(c.source.id)=='string'and D.names[c.source.resource],'compound source')
                    local source=c.source
                    if source.resource=='rawstone'then assert(b.kind=='quarry'and source.id=='rawstone:valley'and Deposits.rockAt(s,source.x,source.y),'rock exposure binding')
                    elseif source.resource=='rawwood'then assert(b.kind=='woodcutter'and source.id=='forest:edge'and s:terrain(source.x,source.y)=='forest','forest edge binding')
                    elseif source.resource=='fish'then assert(b.kind=='fishery'and site.waterCell and source.x==site.waterCell.x and source.y==site.waterCell.y and source.id==Deposits.source(s,{x=b.x,y=b.y,site=site},'fish').id,'fish pool binding')
                    else local vein=Deposits.at(s,source.x,source.y);assert(vein and vein.resource==D.buildings[b.kind].deposit and source.resource==vein.resource and source.id==vein.resource..':'..vein.x..':'..vein.y,'mineral binding')end
                end
                if site.railRoute then
                    assert((b.kind=='quarry'or b.kind=='ironmine'or b.kind=='coalmine'or b.kind=='goldmine')and #site.railRoute>=2 and #site.railRoute<=8,'compound rail')
                    for _,p in ipairs(site.railRoute)do point(p)end
                    local first,last=site.railRoute[1],site.railRoute[#site.railRoute]
                    assert(math.abs(first.x-site.chairCell.x)<.000001 and math.abs(first.y-site.chairCell.y)<.000001 and math.abs(last.x-c.entrance.x)<.000001 and math.abs(last.y-c.entrance.y)<.000001,'registered rail endpoints')
                end
            end
            if b.kind=='fishery'then
                point(site.shoreCell,true);point(site.waterCell,true)
                assert(math.abs(site.shoreCell.x-site.waterCell.x)+math.abs(site.shoreCell.y-site.waterCell.y)==1,'bank must touch water')
            end
        end
        if b.recipe~=nil or b.processingRecipe~=nil or b.queuedRecipe~=nil then
            local recipes=D.buildings[b.kind].recipes
            assert(recipes and (b.recipe==nil or number(b.recipe,0,#recipes) and b.recipe%1==0),"recipe selection")
            assert(b.processingRecipe==nil or number(b.processingRecipe,1,#recipes) and b.processingRecipe%1==0,"processing recipe")
            assert(b.queuedRecipe==nil or number(b.queuedRecipe,0,#recipes) and b.queuedRecipe%1==0,"queued recipe")
        end
        if b.processingResource~=nil then
            local def=D.buildings[b.kind]
            assert(Economy.allowed(b,b.processingResource),"processing resource")
        end
        if b.kind=="ranch" then
            assert(b.feedRemaining==nil or number(b.feedRemaining,0,40),"ranch feed duration")
            assert(b.feedClock==nil or number(b.feedClock,0,4),"ranch feeding animation")
            assert(b.feedVisits==nil or number(b.feedVisits,0,1e12),"ranch feed visits")
            assert(b.ranchPhase==nil or b.ranchPhase=='exit' or b.ranchPhase=='feed' or b.ranchPhase=='return','ranch doorway phase')
            assert(b.ranchClock==nil or number(b.ranchClock,0,2.8),'ranch doorway time')
        end
        if b.stageSupplies~=nil then
            assert(type(b.stageSupplies)=="table","stage supplies")
            for batch,value in pairs(b.stageSupplies) do
                assert(type(batch)=="string" and batch:match("^[1-4]wood$") or type(batch)=="string" and batch:match("^[1-4]stone$"),"stage supply resource")
                assert(value==true,"stage supply flag")
            end
        end
        assert(type(b.incoming) == "boolean" and type(b.outgoing) == "boolean", "transit flags")
        local width, height = b.footprintW or 1, b.footprintH or 1
        local maxW, maxH = D.footprint(b.kind)
        assert(number(width, 1, maxW) and width % 1 == 0 and number(height, 1, maxH) and height % 1 == 0, "building footprint")
        if b.footprintCells~=nil then
            assert(type(b.footprintCells)=="table" and #b.footprintCells>0 and #b.footprintCells<=width*height,"building mask")
            local seen={}
            for _,c in ipairs(b.footprintCells) do
                assert(type(c)=="table" and number(c.x,1-width,0) and number(c.y,1-height,0) and c.x%1==0 and c.y%1==0,"mask cell")
                local k=c.x .. ":" .. c.y;assert(not seen[k],"duplicate mask cell");seen[k]=true
            end
            assert(seen["0:0"],"building entrance cell")
        end
        for _,c in ipairs(D.cells(b)) do
            local tileX,tileY=b.x+c.x,b.y+c.y
            assert(not s:buildingAt(tileX, tileY) and not s.roads[tileX .. ":" .. tileY], "building overlap")
        end
        assert(number(b.deliveredLoads or 0,0,1e6),"construction deliveries")
        assert(number(b.mealStock or 0,0,100) and (b.mealIncoming==nil or type(b.mealIncoming)=="boolean"),"dining inventory")
        local restored = clone(b); restored.cachedConnected, restored.networkRevision = nil, nil
        if data.version<4 and b.kind=="kitchen" and b.inputGoods==nil and b.inputs>0 then
            restored.inputGoods={flour=b.inputs}
        end
        -- A v3 shelf still contains finished wood. Deliver that stock under
        -- its old identity, then let the same camp begin supplying raw logs.
        if data.version<4 and b.kind=="woodcutter" and (b.buffer>0 or b.outgoing) then restored.legacyOutput="wood" end
        if data.version<5 and b.kind=="quarry" and (b.buffer>0 or b.outgoing) then restored.legacyOutput="stone" end
        assert(restored.legacyOutput==nil or b.kind=="woodcutter" and restored.legacyOutput=="wood" or b.kind=="quarry" and restored.legacyOutput=="stone","legacy output")
        if b.buildPoints then
            local expected=Sites.blueprint(b)
            assert(type(b.buildPoints)=="table" and #b.buildPoints==#expected,"construction point count")
            local work=0
            for i,e in ipairs(expected) do
                local p=b.buildPoints[i]
                assert(type(p)=="table" and p.id==i and p.part==e.part and p.phase==e.phase and p.side==e.side and
                    p.resource==e.resource and number(p.amount,0,1e6) and math.abs(p.amount-e.amount)<.00001 and
                    number(p.required,0,36) and math.abs(p.required-e.required)<.00001,"construction point plan")
                assert(number(p.work,0,p.required) and type(p.delivered)=="boolean" and (p.work==0 or p.delivered),"point work requires delivered materials")
                work=work+p.work
            end
            assert(math.abs(work/Sites.totalWork-b.progress)<.00001,"construction point total")
            for _,p in ipairs(b.buildPoints) do
                if p.delivered then
                    for _,earlier in ipairs(b.buildPoints) do
                        assert(earlier.phase>=p.phase or earlier.work>=earlier.required-.000001,"structural prerequisites")
                    end
                end
            end
        end
        restored.mealStock,restored.mealIncoming=b.mealStock or 0,b.mealIncoming or false
        if b.kind=="farm" then
            restored.farmStep=b.farmStep or (b.timer>0 and 1 or 0)
            restored.farmWork=b.farmWork or 0
        end
        restored.footprintW, restored.footprintH = width, height
        s.buildings[i] = restored
        for _,c in ipairs(D.cells(restored)) do s.buildingIndex[b.x+c.x .. ":" .. b.y+c.y]=restored end
    end
    assert(s.buildings[1].kind == "store" and s.buildings[1].x == 10 and s.buildings[1].y == 8, "warehouse")
    local yards={}
    for _,b in ipairs(s.buildings)do if b.site and b.site.version==2 then
        for _,p in ipairs(b.site.yardCells)do
            local k=p.x..':'..p.y
            local deck=false;for _,q in ipairs(b.site.compound and b.site.compound.deckCells or {})do if q.x==p.x and q.y==p.y then deck=true;break end end
            assert(not yards[k]and not s:buildingAt(p.x,p.y)and not s.roads[k]and(s:terrain(p.x,p.y)=='grass'or deck and s:terrain(p.x,p.y)=='water'),'activity plot overlap')
            yards[k]=b.id
        end
    end end
    WorkSites.rebuild(s)
    local function restoreJob(job)
        if job == false then return false end
        assert(type(job) == "table" and s.buildings[job.building], "job building")
        assert(type(job.inbound) == "boolean" and D.names[job.resource] and number(job.amount, 1, 1e12), "job")
        assert(job.construction==nil or type(job.construction)=="boolean","construction delivery")
        if job.construction then
            assert(job.inbound and not s.buildings[job.building].complete and (job.resource=="wood" or job.resource=="stone")
                and number(job.supplyPhase,1,4) and job.supplyPhase%1==0,"construction supply phase")
        end
        assert(job.sitePickup==nil or type(job.sitePickup)=='boolean','private pickup flag')
        if job.sitePickup then assert(not job.inbound and WorkSites.storageKind(s.buildings[job.building].kind)and s.buildings[job.building].site,'private pickup source')end
        assert(job.service==nil or type(job.service)=="boolean","service job")
        if job.service then assert(job.inbound and job.resource=="food" and job.amount<=2 and s.buildings[job.building].kind=="kitchen","meal delivery") end
        local destination=job.destination and s.buildings[job.destination] or nil
        if job.destination then
            assert(destination and not job.inbound and destination.complete and job.amount<=4,"delivery destination")
            local def=D.buildings[destination.kind]
            assert(Economy.allowed(destination,job.resource),"delivery resource")
        end
        return { b = s.buildings[job.building], destination=destination, inbound = job.inbound, resource = job.resource, amount = job.amount,service=job.service or false, pickedUp=job.pickedUp or false, construction=job.construction or false,supplyPhase=job.supplyPhase,sitePickup=job.sitePickup or nil }
    end
    for _, job in ipairs(w.jobs) do
        local restored=restoreJob(job)
        ---@cast restored {b:{buffer:number},inbound:boolean,amount:number}
        if data.version<3 and not restored.inbound then restored.b.buffer=restored.b.buffer+restored.amount end
        s.jobs[#s.jobs+1]=restored
    end
    for _, c in ipairs(w.carriers) do
        assert(c.workerLook==nil or c.workerLook==1 or c.workerLook==2,"worker appearance")
        assert(number(c.x, -1e9, 1e9) and number(c.y, -1e9, 1e9) and number(c.index, 1, 100001), "carrier")
        assert(type(c.carrying) == "boolean" and type(c.path) == "table" and #c.path <= 100000, "route")
        for _, p in ipairs(c.path) do assert(type(p) == "table" and number(p.x, -1e9, 1e9) and number(p.y, -1e9, 1e9), "path point") end
        local restored = clone(c); restored.job = restoreJob(c.job)
        if data.version<3 and restored.job and not restored.job.inbound then
            restored.job.pickedUp=c.carrying
            if not c.carrying then restored.job.b.buffer=restored.job.b.buffer+restored.job.amount end
        end
        assert(c.phase==nil or c.phase=="idle" or c.phase=="travel" or c.phase=="packing" or c.phase=="unload","carrier phase")
        assert(c.doorDuration==nil or number(c.doorDuration,2,10),'carrier door duration')
        local duration=c.doorDuration or Cargo.doorSeconds
        assert(c.timer==nil or number(c.timer,0,duration),"carrier animation timer")
        assert(c.handedOff==nil or type(c.handedOff)=="boolean","delivery handoff flag")
        local handoff=duration*.5
        if c.phase=="unload" and (c.timer or 0)<=handoff then assert(c.handedOff==true and not c.carrying,"completed unloading cannot transfer twice") end
        if c.handedOff then assert(c.phase=="unload" and (c.timer or 0)<=handoff and not c.carrying,"handoff phase") end
        if c.sitePickup then
            local state=c.sitePickup;local j=restored.job
            local phases={waiting=true,waitingSource=true,waitingRoute=true,approach=true,loading=true,['return']=true}
            assert(j and j.sitePickup and state.building==j.b.id and phases[state.phase]and number(state.clock,0,1e12),'private pickup cycle')
            for _,p in ipairs({state.target,state.door})do assert(type(p)=='table'and number(p.x,-1e9,1e9)and number(p.y,-1e9,1e9),'private pickup point')end
            local target=require('game.CarrierLife').storage(j.b)
            assert(target and math.abs(target.x-state.target.x)<=1e-9 and math.abs(target.y-state.target.y)<=1e-9 and state.door.x==j.b.x and state.door.y==j.b.y+1,'private pickup destination')
            if state.phase=='return'or state.phase=='waitingRoute'then assert(j.pickedUp and c.carrying,'return carries one committed load')end
            if state.phase=='approach'or state.phase=='waiting'or state.phase=='waitingSource'then assert(not j.pickedUp and not c.carrying,'unpicked reserved shelf')end
            if state.phase=='loading'then assert(c.carrying==(j.pickedUp==true),'single private pickup midpoint')end
        end
        restored.energy=restored.energy or 100
        s.carriers[#s.carriers + 1] = restored
    end
    assert(type(w.enemies) == "table" and #w.enemies <= 10000, "enemies")
    for _, e in ipairs(w.enemies) do assert(number(e.x, -1e9, 1e9) and number(e.y, -1e9, 1e9) and number(e.hp, -1e12, 1e12), "enemy state") end
    s.enemies = clone(w.enemies)
    local function validatePath(a)
        assert(a.workFinishLeft==nil or number(a.workFinishLeft,0,1.2),'workshop finish duration')
        assert(a.workPresence==nil or number(a.workPresence,0,1),'indoor worker presence')
        assert(a.workerLook==nil or a.workerLook==1 or a.workerLook==2,"worker appearance")
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
        assert(number(m.timer,0,12) and number(m.resumeX,-1e9,1e9) and number(m.resumeY,-1e9,1e9) and type(m.paid)=="boolean", "meal state")
        assert(m.waitTime==nil or number(m.waitTime,0,1e12),"dining wait")
        assert(m.queueX==nil or (number(m.queueX,-1e9,1e9) and number(m.queueY,-1e9,1e9)),"dining queue origin")
        assert(m.seat==nil or (number(m.seat,1,4) and m.seat%1==0),"dining seat")
        if m.phase=="enter" or m.phase=="eat" or m.phase=="exit" then assert(m.paid,"reserved meal") end
    end
    if data.version >= 2 then
        assert(type(w.pendingRoads)=="table" and #w.pendingRoads<=100000 and type(w.builders)=="table" and #w.builders<=4, "construction")
        s.pendingRoads,s.roadPlanIndex,s.builders={}, {},clone(w.builders)
        for _,p in ipairs(w.pendingRoads) do
            assert(type(p)=="table" and number(p.x,-1e9,1e9) and p.x%1==0 and number(p.y,-1e9,1e9) and p.y%1==0 and number(p.progress,0,1), "road site")
            local k=p.x .. ":" .. p.y
            assert(not s.roads[k] and not s:buildingAt(p.x,p.y) and not s.roadPlanIndex[k], "road overlap")
            local entry=clone(p);s.pendingRoads[#s.pendingRoads+1]=entry;s.roadPlanIndex[k]=entry
        end
        local claims,workClaims={},{}
        for _,a in ipairs(s.builders) do
            validatePath(a)
            validateMeal(a)
            a.energy=a.energy or 100
            assert(type(a.active)=="boolean" and type(a.carrying)=="boolean" and number(a.timer,0,1e12), "builder state")
            assert(a.phase=="idle" or a.phase=="collect" or a.phase=="packing" or a.phase=="toSite" or a.phase=="approach" or a.phase=="unload" or a.phase=="ready" or a.phase=="recover" or a.phase=="waitMaterials" or a.phase=="awaitStage" or a.phase=="waitSite" or a.phase=="refillExit" or a.phase=="hammer" or a.phase=="leaveSite" or a.phase=="return", "builder phase")
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
                    if j.pointId then
                        local b=s.buildings[j.building]
                        local point=b.buildPoints and b.buildPoints[j.pointId]
                        assert(point and (point.work<point.required or a.phase=="waitSite" or a.phase=="recover") and point.resource==j.resource and
                            (j.pointSide==nil or j.pointSide==point.side) and j.pointPhase==point.phase and
                            j.amount==point.amount,"active construction point")
                        assert((a.phase~="hammer" and a.phase~="ready") or point.delivered,"hammer requires supplied materials")
                        assert(j.delivery==nil or type(j.delivery)=="boolean","delivery task")
                        assert(j.supplyOnly==nil or type(j.supplyOnly)=="boolean","supply task")
                        assert(j.deliveryAmount==nil or number(j.deliveryAmount,0,1000000),"delivery bundle")
                        local claimKey="point:" .. j.building .. ":" .. j.pointId
                        assert(not workClaims[claimKey],"duplicate point worker");workClaims[claimKey]=true
                    end
                    if j.workX~=nil then
                        local b=s.buildings[j.building]
                        local left,right,top,bottom=b.x-(b.footprintW or 1),b.x+1,b.y-(b.footprintH or 1),b.y+1
                        local edgeAllowed=false
                        for _,edge in ipairs(D.edges(b)) do
                            if edge.outsideX==j.workX and edge.outsideY==j.workY then edgeAllowed=true;break end
                        end
                        assert(number(j.workX,left,right) and number(j.workY,top,bottom) and
                            j.workX%1==0 and j.workY%1==0 and edgeAllowed,"construction perimeter")
                        local spot=j.building .. ":" .. j.workX .. ":" .. j.workY
                        assert(not workClaims[spot],"overlapping construction positions");workClaims[spot]=true
                    end
                    claim="b" .. j.building
                end
                claims[claim]=(claims[claim] or 0)+1
                assert(claim:sub(1,1)=="b" and claims[claim]<=4 or claims[claim]==1, "duplicate construction worker")
            else assert(a.phase=="idle" or a.phase=="return" or a.phase=="leaveSite", "builder missing job") end
        end
        assert(type(w.workers)=="table" and number(w.mealsServed,0,1e12), "worker activities")
        s.workers,s.mealsServed={},w.mealsServed
        local count=0
        for k,a in pairs(w.workers) do
            count=count+1;assert(count<=20000 and type(k)=="string" and type(a)=="table", "worker limit")
            local b=s.buildings[a.building]
            assert(b and b.complete and number(a.slot,1,b.workers) and a.slot%1==0 and k==a.building .. ":" .. a.slot, "worker slot")
            validatePath(a);validateMeal(a)
            if a.breaks then
                local state=a.breaks
                assert(require('game.WorkBreaks').kinds[b.kind]and({walk=true,idle=true,['return']=true,blocked=true,workApproach=true,work=true,finish=true,toStorage=true,stow=true,mealReady=true})[state.phase]and number(state.clock,0,1e12),'workshop break cycle')
                assert(type(state.point)=='table'and number(state.point.x,-1e9,1e9)and number(state.point.y,-1e9,1e9),'workshop idle point')
                if state.target then assert(type(state.target)=='table'and number(state.target.x,-1e9,1e9)and number(state.target.y,-1e9,1e9),'workshop route target')end
                if state.phase=='blocked'then
                    assert(state.target and({walk=true,['return']=true,workApproach=true,toStorage=true})[state.destination],'workshop blocked route')
                end
                if state.phase=='work'then
                    local p=WorkSites.workPoint(b,a.slot)
                    assert(p and math.abs(a.x-p.x)<.001 and math.abs(a.y-p.y)<.001,'actual workshop position')
                end
            end
            assert(a.workshopOutdoor==nil or type(a.workshopOutdoor)=='boolean','outdoor workshop flag')
            if a.workshopOutdoor then assert(WorkSites.breakKinds[b.kind]and b.site and b.site.workCell and b.site.storageCell,'outdoor workshop site')end
            if a.workLoad then
                local load=a.workLoad
                assert(a.workshopOutdoor and a.breaks and a.carrying and not a.meal and type(load.goods)=='table','carried workshop batch')
                local total=0
                for resource,amount in pairs(load.goods)do
                    assert(Economy.isProduct(b,resource)and number(amount,1,100)and amount%1==0,'typed workshop load')
                    total=total+amount
                end
                assert(total>0 and load.goods[load.resource]and load.goods[load.resource]>0,'workshop load identity')
                assert(a.breaks.phase=='finish'or a.breaks.phase=='toStorage'or a.breaks.phase=='stow'or a.breaks.phase=='blocked','workshop delivery phase')
            end
            if a.life then
                local l=a.life
                local phases={rest=true,rise=true,toShore=true,cast=true,fish=true,reel=true,toTank=true,stow=true,toChair=true,toMeal=true,mealReady=true,toDoor=true,toBench=true,cut=true,rideIn=true,mine=true,rideOut=true,toRail=true,toStack=true,blocked=true}
                assert(WorkSites.managed(b.kind)and b.site and l.kind==b.kind and phases[l.phase]and number(l.clock or 0,0,1e12)and number(l.workSeconds or 0,0,1e12),'civilian cycle')
                assert(not(l.reservation and l.load),'work goods cannot be both reserved and carried')
                local goods=l.reservation or l.load
                if goods then
                    assert(type(goods)=='table'and Economy.isProduct(b,goods.resource)and number(goods.amount,1,2)and goods.amount%1==0,'civilian goods')
                    if l.reservation then
                        if b.kind=='mason'then assert(goods.inputs and goods.inputs.rawstone==2,'cutting input reservation')
                        else
                            local source=Deposits.source(s,b,goods.resource)
                            assert(source and source.id==goods.sourceId,'resource reservation source')
                        end
                    else assert(a.carrying==true,'carried work output')end
                end
            end
            if a.forestryPhase~=nil then
                assert(b.kind=="forester" and (a.forestryPhase=="walk" or a.forestryPhase=="tend" or a.forestryPhase=="return"),"forestry phase")
                assert(type(a.forestryTarget)=="string" and a.forestryTarget:match("^%-?%d+:%-?%d+$"),"forestry target")
                assert(a.forestryClock==nil or number(a.forestryClock,0,1e12),"forestry work clock")
            end
            assert(a.loadAmount==nil or number(a.loadAmount,1,2),"logger load amount")
            if a.woodPhase then
                assert(b.kind=="woodcutter" and (a.woodPhase=="toTree" or a.woodPhase=="chop" or a.woodPhase=="felling" or a.woodPhase=="gather" or a.woodPhase=="toCamp" or a.woodPhase=="toRack" or a.woodPhase=="stack" or a.woodPhase=="fromRack"),"woodcutting phase")
                assert(number(a.treeX,-1e9,1e9) and number(a.treeY,-1e9,1e9) and number(a.woodClock or 0,0,1e12),"woodcutting target")
            end
            assert(a.rackVisit==nil or a.rackVisit==true,'logging rack cycle flag')
            assert(a.rackWaiting==nil or type(a.rackWaiting)=='boolean','logging rack wait flag')
            assert(a.campWaiting==nil or type(a.campWaiting)=='boolean','logging return wait flag')
            if a.rackVisit then assert(b.kind=='woodcutter'and a.woodPhase and b.site and b.site.compound and b.site.storageCell,'registered logging rack excursion')end
            if a.woodPhase=="felling" or a.woodPhase=="gather" then assert(type(a.felledLoad)=="boolean","felled load") end
            if a.woodPhase=="stack" and (a.woodClock or 0)>=1.05 then assert(a.stockedLoad==true and not a.carrying,"stored logs cannot be delivered twice") end
            s.workers[k]=clone(a);s.workers[k].energy=a.energy or 100
            if data.version<4 and b.kind=="woodcutter" and (a.carrying or a.felledLoad) then b.legacyOutput="wood" end
        end
        for _,a in ipairs(s.carriers) do validatePath(a);validateMeal(a) end
        local held,inputs,pools,workHeld={},{},{},{}
        for _,a in pairs(s.workers)do if a.workLoad then for _,amount in pairs(a.workLoad.goods)do workHeld[a.building]=(workHeld[a.building]or 0)+amount end end end
        for _,a in pairs(s.workers)do if a.life then
            local l=a.life;local goods=l.reservation or l.load
            if goods then held[a.building]=(held[a.building]or 0)+goods.amount end
            if l.reservation then
                local r=l.reservation
                if r.inputs then inputs[a.building]=(inputs[a.building]or 0)+r.inputs.rawstone
                else pools[r.sourceId]=(pools[r.sourceId]or 0)+r.amount end
            end
        end end
        for _,b in ipairs(s.buildings)do
            assert(math.abs((held[b.id]or 0)-(b.lifeOutputHeld or 0))<.000001,'work output reservation total')
            assert(math.abs((workHeld[b.id]or 0)-(b.workOutputHeld or 0))<.000001,'workshop carried output total')
            if (b.workOutputHeld or 0)>0 then assert(b.buffer+(b.workOutputHeld or 0)+(b.lifeOutputHeld or 0)<=Economy.capacity(b),'workshop reserved shelf capacity')end
            assert((inputs[b.id]or 0)<=(b.inputGoods and b.inputGoods.rawstone or 0),'work input reservation total')
            if b.lifeEnabled then assert(b.buffer+(b.lifeOutputHeld or 0)<=Economy.capacity(b),'work shelf capacity')end
        end
        for _,a in pairs(s.workers)do
            local r=a.life and a.life.reservation
            if r and r.sourceId then local source=Deposits.source(s,s.buildings[a.building],r.resource);assert(pools[r.sourceId]<=source.remaining,'shared pool reservations')end
        end
    else
        -- V1 roads remain completed; actors start at their existing jobs without eating twice.
        for _,a in ipairs(s.carriers) do a.hunger,a.meal=0,false end
    end
    assert(w.guards==nil or (type(w.guards)=="table" and #w.guards==s.militia),"guards")
    s.guards={}
    if w.guards then
        for _,a in ipairs(w.guards) do
            validatePath(a);validateMeal(a)
            assert(a.unit==nil or Military.units[a.unit],"soldier unit")
            if a.unit and a.unit~="militia" then
                local expected=Military.units[a.unit].equipment
                assert(type(a.equipment)=="table","issued equipment")
                for resource,n in pairs(expected)do assert(a.equipment[resource]==n,"issued equipment identity")end
                for resource,n in pairs(a.equipment)do assert(expected[resource]==n,"no unissued equipment")end
            end
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
    s.treeGrowth={}
    for k,t in pairs(w.treeGrowth or {})do
        assert(type(k)=="string" and s.felledTrees[k] and type(t)=="table","tree growth entry")
        assert(number(t.x,-1e9,1e9) and number(t.y,-1e9,1e9) and t.x%1==0 and t.y%1==0 and k==math.floor(t.x)..":"..math.floor(t.y),"tree growth position")
        assert(t.phase=="stump" or t.phase=="sapling","tree growth phase")
        assert(number(t.age,0,t.phase=="stump" and Forestry.stumpSeconds or Forestry.growthSeconds),"tree growth age")
        assert(t.cancelled==nil or type(t.cancelled)=="boolean","cancelled growth")
        s.treeGrowth[k]=clone(t)
    end
    Forestry.ensure(s)
    s.regrownTrees=w.regrownTrees or 0;assert(number(s.regrownTrees,0,1e12),"regrown tree count")
    s.minerals={}
    for k,amount in pairs(w.minerals or {})do
        assert(type(k)=="string","mineral key")
        local resource=k:match("^(%a+):")
        local maximum=resource=="fish" and 360 or Deposits.capacity[resource]
        assert(maximum and number(amount,0,maximum),"finite resource reserve")
        assert(k=="fish:valley" or k:match("^%a+:%-?%d+:%-?%d+$"),"deposit coordinate")
        s.minerals[k]=amount
    end
    if data.version<7 then
        local carrier=4
        for _,b in ipairs(s.buildings)do if b.kind=='courier' and b.complete then
            if s.carriers[carrier] then s.carriers[carrier].courier=b.id;s.carriers[carrier].deliveryCount=0;carrier=carrier+1 end
        end end
    end
    local origins={}
    for _,a in ipairs(s.carriers)do
        assert(a.deliveryCount==nil or number(a.deliveryCount,0,1e12),'carrier delivery count')
        if a.courier then
            local b=s.buildings[a.courier]
            assert(b and b.complete and b.kind=='courier' and not origins[a.courier],'courier worker origin')
            origins[a.courier]=true
        end
    end
    assert(s:availableWorkers() >= 0, "workforce")
    return s
end
function Data.restore(data, mode)
    local ok, result = pcall(restoreUnsafe, data, mode)
    if ok then return result end
    return nil,tostring(result)
end
return Data
