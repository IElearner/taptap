local Game = require "network.Standalone"
local Art = require "game.Art"
local Characters = require "game.Characters"
local Data = require "game.SaveData"
local seen, originalDraw, snapshot = {}, Art.draw, nil
Art.draw = function(vg, name, ...)
    if name:sub(1,7) == "person-" then seen[name] = true end
    return originalDraw(vg, name, ...)
end
V.atFrame(6, function()
    Game.UseStore(require("game.SaveStore").new({ now = function() return 1000 end,
        read = function() return nil end, write = function() return true end }))
    local state, _, hud = Game.Inspect()
    hud.dismissIntro()
    state.population=20
    for _, item in ipairs({ {"farm",8}, {"kitchen",12}, {"butcher",13}, {"barracks",14} }) do
        local b=state:addBuilding(item[1],item[2],8,true)
        if item[1]~="barracks" then b.workers=1 end
    end
    for _ = 1, 300 do state:update(0.1) end
    V.assert(state:train() and state:train(), "Male and female militia can be presented from real training")
    state.paused = true
    snapshot = Data.capture(state,1000,1,true)
    local restored = Data.restore(snapshot, state.mode)
    for index in ipairs(restored.carriers) do
        local before, p1 = Characters.carrier(index,false)
        local after, p2 = Characters.carrier(index,true)
        V.assert(p1 == p2 and before ~= after, "Carrying changes pose without changing identity")
    end
    local idle=Characters.sprite("civilian-blue-man","se",false,nil,0,0)
    V.assert(idle=="person-civilian-blue-man-se","Stationary villagers use their resting pose")
    V.assert(Characters.sprite("civilian-blue-man","se",false,"eat",0,0)=="person-eating-blue-man-1" and
        Characters.sprite("civilian-blue-man","se",false,"eat",0.8,0)=="person-eating-blue-man-2",
        "Eating animates the same civilian between lowered and raised chopsticks")
    V.assert(Characters.sprite("occupation-chef","sw",false,"eat",0,0)=="person-eating-chef-1" and
        Characters.sprite("occupation-guard","se",false,"eat",0.8,0)=="person-eating-guard-2",
        "Specialists and guards keep their identity through eating frames")
    V.assert(Characters.sprite("civilian-blue-man","se",false,"plow",0,0)=="person-farm-plow-1" and
        Characters.sprite("civilian-blue-man","se",false,"plow",0.5,0)=="person-farm-plow-2",
        "Plowing switches actual illustrated action frames")
    V.assert(Characters.sprite("civilian-blue-man","se",true,nil,0,0)==idle and
        Characters.sprite("civilian-blue-man","se",true,nil,0.2,0)==idle .. "-stride",
        "Walking villagers alternate two drawn stride frames")
    V.assert(Characters.sprite("loaded-green-woman","nw",true,nil,0.2,0)=="person-loaded-green-woman-nw-stride",
        "Carrying villagers retain their load while walking")
    V.assert(Characters.sprite("civilian-ochre-woman","sw",false,"hammer",0,0)=="person-civilian-ochre-woman-sw-hammer-up" and
        Characters.sprite("civilian-ochre-woman","sw",false,"hammer",0.3,0)=="person-civilian-ochre-woman-sw-hammer-down",
        "Builders alternate raised and striking hammer frames")
    V.assert(Characters.worker({kind="farm",complete=false,workers=1},1) == nil, "No phantom worker before construction completes")
    V.assert(Characters.worker({kind="farm",complete=true,workers=0},1) == nil, "Unstaffed buildings have no decorative production worker")
    local farmRole, farmProfile = Characters.worker({id=4,kind="farm",complete=true,workers=1},1)
    local porterRole, porterProfile = Characters.carrier(4,false)
    V.assert(farmRole==porterRole and farmProfile==porterProfile,"Farm production and carrying share the civilian worker profession")
    local cookRole = Characters.worker({id=5,kind="kitchen",complete=true,workers=1},1)
    local butcherRole = Characters.worker({id=6,kind="butcher",complete=true,workers=1},1)
    V.assert(cookRole=="occupation-chef" and butcherRole=="occupation-butcher","Kitchen and slaughterhouse use distinct skilled professions")
end)
V.atFrame(30, function()
    local s = Game.Inspect()
    local civilians, guard, cook, butcher = {}, false, false, false
    for name in pairs(seen) do
        if name:find("blue%-man") then civilians.blue = true end
        if name:find("ochre%-woman") then civilians.ochre = true end
        if name:find("grey%-elder") then civilians.grey = true end
        guard = guard or name:find("occupation%-guard") ~= nil
        cook = cook or name:find("occupation%-chef") ~= nil
        butcher = butcher or name:find("occupation%-butcher") ~= nil
    end
    V.assert(civilians.blue and civilians.ochre and civilians.grey, "Actual renderer requests distinct carrier identities")
    V.assert(not seen["person-occupation-farmer-se"] and not seen["person-occupation-logger-se"],
        "Farm and timber workers are rendered as ordinary villagers")
    V.assert(cook and butcher,"Actual renderer shows distinct chef and butcher at their workplaces")
    V.assert(guard, "Actual renderer includes female militia alongside existing militia")
    for resource, amount in pairs(snapshot.world.stock) do
        V.assert(s.stock[resource] == amount, "Presentation preserves saved economy: " .. resource)
    end
    Art.draw = originalDraw
    V.finish()
end)
