-- Run with UrhoXRuntime main.lua ... -validate-test=<absolute path>.
local Sim = require "game.Simulation"
local D = require "game.Definitions"
local function advance(s, seconds)
    for _ = 1, math.ceil(seconds * 10) do s:update(0.1) end
end
local function untilTrue(s,predicate,seconds)
    for _=1,seconds*10 do if predicate() then return true end;s:update(.1) end
    return predicate()
end
local function build(s, kind, x, y)
    local ok, message, b = s:build(kind, x, y)
    V.assert(ok, kind .. ": " .. message)
    if ok and kind=="road" then
        for _=1,3000 do if s.roads[x .. ":" .. y] then break end;s:update(0.1,true) end
        V.assert(s.roads[x .. ":" .. y], "Planned road is constructed before logistics use")
    end
    if ok and kind~="road" then
        V.assert(untilTrue(s,function() return b.complete end,600),kind .. ": real staged construction finishes within ten simulated minutes")
    end
    return b
end
V.atFrame(6, function()
    require("network.Standalone").UseStore(require("game.SaveStore").new({
        now = function() return 1000 end, read = function() return nil end, write = function() return true end,
    }))
end)
V.atFrame(8, function()
    local live, view, hud = require("network.Standalone").Inspect()
    local enter = hud.root:FindById("enterVillage")
    V.assert(enter ~= nil, "Mobile entry action exists")
    enter.props.onClick(enter)
    V.assert(live.started, "Entry action begins gameplay")
    local road = hud.root:FindById("build_road")
    road.props.onClick(road)
    local layout = view.panel:GetAbsoluteLayout()
    local sx = layout.x + layout.w * 0.5 - 3*56*view.cameraState().zoom
    local sy = layout.y + layout.h * 0.5
    view.panel.props.onTap({ x = sx, y = sy }) -- tile (7,9) at default camera
    V.assert(live:roadSiteAt(7,9) ~= nil and live.roadCount==0, "Map tap plans the intended road tile without instant completion")
    advance(live,10)
    V.assert(live.roadCount==1,"Mobile road plan is completed by a real builder")
    local pause = hud.root:FindById("pause")
    pause.props.onClick(pause)
    V.assert(live.paused, "Pause HUD action reaches simulation")
    pause.props.onClick(pause)
    local s = Sim.new()
    s.started = true
    local stock = s.stock.wood
    local planning=Sim.new();planning.started=true
    local planned,_,waiting=planning:build("house",6,6)
    V.assert(planned and waiting.progress==0,"Disconnected buildings can be surveyed before roads")
    V.assert(planning.stock.wood==stock-D.buildings.house.cost.wood,"A plan reserves its materials once")
    V.assert(not s:build("road", 20, 8), "Water placement rejected")
    V.assert(not s:nextLesson(), "Tutorial cannot advance without completing objective")
    for x = 7, 4, -1 do build(s, "road", x, 9) end
    V.assert(s:nextLesson(), "Road tutorial completed with four connected tiles")
    local home = build(s, "house", 7, 8)
    V.assert(home.footprintW==3 and home.footprintH==2 and s:buildingAt(5,7)==home,
        "New homes reserve a three-by-two footprint")
    advance(s, 20)
    V.assert(home.complete and s.population == 14, "Housing completes and adds villagers once")
    V.assert(s:nextLesson(), "Housing tutorial advances")
    for y=10,13 do build(s,"road",9,y) end
    build(s,"road",8,13)
    build(s, "farm", 8, 12); advance(s, 30)
    V.assert(s:nextLesson(), "Farm tutorial advances")
    build(s,"road",13,9)
    build(s, "mill", 13, 8); advance(s, 30)
    V.assert(s:nextLesson(), "Mill tutorial advances")
    build(s,"road",14,9);build(s,"road",15,9)
    for y=10,13 do build(s,"road",15,y) end
    build(s,"road",14,13)
    build(s, "kitchen", 14, 12)
    V.assert(untilTrue(s,function() return s.produced.food>=4 end,300),"The complete grain chain delivers its first cooked batch")
    V.assert(s.produced.food >= 4, "Grain is transported, milled, cooked and delivered as food")
    V.assert(s:nextLesson(), "Food tutorial counts delivered food, not starter inventory")
    build(s,"road",16,9);build(s,"road",17,9);build(s,"woodcutter",17,8);advance(s,30)
    V.assert(s:nextLesson(), "Woodcutter tutorial advances")
    build(s,"road",8,8);build(s,"road",8,7);build(s,"barracks",8,6);advance(s,30)
    for _ = 1, 3 do V.assert(s:train(), "Train a militia from available workers") end
    V.assert(s:nextLesson(), "Militia tutorial advances")
    local before = s.elapsed
    s.paused = true; advance(s, 10)
    V.assert(s.elapsed == before, "Pause freezes simulation")
    s.paused = false
    V.assert(s:startRaid(), "Prepared village can trigger raid")
    V.assert(not s:startRaid(), "Duplicate raids rejected")
    advance(s, 60)
    V.assert(s.victory and not s.defeat and s.health > 0, "Three militia can win introductory raid")
    V.assert(s:nextLesson() and s.lesson == #D.lessons + 1, "All eight tutorial steps can finish")
    for _, value in pairs(s.stock) do V.assert(value >= 0, "No negative inventory") end
    local poor = Sim.new(); poor.stock.wood = 0
    V.assert(not poor:build("house", 8, 8), "Insufficient stock prevents building")
    V.assert(not poor:train(), "No barracks prevents training")
    local defeat = Sim.new(); defeat.started = true; defeat.militia = 3
    defeat:startRaid(); defeat.militia = 0; advance(defeat, 80)
    V.assert(defeat.defeat and not defeat.victory, "Undefended warehouse can lose")

    -- Distinct world modes, unbounded coordinate terrain and survival lifecycle.
    local world = Sim.new("infinite", 7319)
    world.started = true
    V.assert(world.mode == "infinite" and world.map.seed == 7319, "Infinite seed and mode are explicit")
    V.assert(world:terrain(16, 23) == "fog", "Undiscovered frontier blocks building")
    V.assert(not world:build("road", 16, 23), "Cannot build through frontier fog")
    V.assert(not s:expand(), "Finite mission never expands")
    V.assert(Sim.new():terrain(23, 10) == "edge", "Finite boundary remains fixed")
    local cost = world:expansionCost()
    local wood, food = world.stock.wood, world.stock.food
    V.assert(world:expand(), "Infinite frontier can expand")
    V.assert(world.stock.wood == wood - cost.wood and world.stock.food == food - cost.food, "Exploration spends exact cost")
    V.assert(world.map.expansion == 1 and world.timber == 480 and world.rock == 280, "Exploration discovers land and resource reserves")
    V.assert(world:terrain(16, 23) == "grass", "New frontier includes guaranteed road corridors")
    V.assert(world:expansionCost().wood > cost.wood, "Exploration cost rises with expansion")
    for x = 13, 16 do build(world, "road", x, 9) end
    for y = 10, 23 do build(world, "road", 16, y) end
    V.assert(world:path(10, 9, 16, 23) ~= nil, "Real logistics road crosses the old finite boundary")
    local poorWorld = Sim.new("infinite"); poorWorld.stock.food = 0
    V.assert(not poorWorld:expand() and poorWorld.map.expansion == 0, "Unaffordable exploration never mutates land")
    local map = require("game.WorldMap").new("infinite", 7319)
    map.expansion = 200
    local first = map:terrain(1000, -640)
    V.assert(first ~= "edge" and first ~= "fog", "Distant coordinates have no final map edge")
    V.assert(first == map:terrain(1000, -640), "Generated terrain is stable on revisit")
    local survival = Sim.new("infinite"); survival.started = true; survival.militia = 12; survival.stock.food = 999
    survival.nextRaid = 0.1
    advance(survival, 60)
    V.assert(survival.wavesDefeated == 1 and not survival.victory and not survival.defeat, "Infinite wave victory continues rather than ending game")
    V.assert(survival.nextRaid > 0, "Next wave countdown scheduled after successful defense")
    survival.nextRaid = 0.1; advance(survival, 60)
    V.assert(survival.wave == 2 and survival.wavesDefeated == 2, "Automatic second wave scales and remains playable")
    local starving = Sim.new("infinite"); starving.started = true; starving.stock.food = 0
    advance(starving, 16)
    V.assert(starving.health == 96, "Infinite mode has food pressure, unlike tutorial relief")
    V.assert(starving:repair() and starving.health == 100, "Warehouse can be repaired with real supplies")
    local supply = Sim.new(); supply.started = true
    local quarry = build(supply, "quarry", 8, 8)
    build(supply,"road",13,9);build(supply,"road",14,9)
    local courier = build(supply, "courier", 14, 8)
    local startStone = supply.stock.stone
    advance(supply, 45)
    V.assert(quarry.complete and supply.stock.stone > startStone, "Stone production reaches warehouse")
    V.assert(courier.complete and #supply.carriers == 4, "Courier post adds physical logistics capacity")
    supply.rock = 0; advance(supply, 40)
    V.assert(supply.rock == 0, "Finite deposits cannot become negative")
    local active, _, activeHud = require("network.Standalone").Inspect()
    activeHud.root:FindById("modeInfinite").props.onClick()
    local switched, _, switchedHud = require("network.Standalone").Inspect()
    V.assert(switched.mode == "infinite" and not switched.started, "Mode menu binds a fresh infinite world")
    switchedHud.root:FindById("enterVillage").props.onClick()
    switchedHud.root:FindById("expandWorld").props.onClick()
    V.assert(switched.started and switched.map.expansion == 1, "Mobile menu and exploration actions work end to end")
end)
V.atFrame(20, function() V.finish() end)
