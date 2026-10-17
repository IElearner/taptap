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
    for _, item in ipairs({ {"farm",8}, {"mill",9}, {"woodcutter",11}, {"barracks",12} }) do
        V.assert(state:build(item[1],item[2],8), "Build staffed scene: " .. item[1])
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
end)
V.atFrame(30, function()
    local s = Game.Inspect()
    local civilians, farmer, logger, guard = {}, false, false, false
    for name in pairs(seen) do
        if name:find("blue%-man") then civilians.blue = true end
        if name:find("ochre%-woman") then civilians.ochre = true end
        if name:find("grey%-elder") then civilians.grey = true end
        farmer = farmer or name:find("occupation%-farmer") ~= nil
        logger = logger or name:find("occupation%-logger") ~= nil
        guard = guard or name:find("occupation%-guard") ~= nil
    end
    V.assert(civilians.blue and civilians.ochre and civilians.grey, "Actual renderer requests distinct carrier identities")
    V.assert(farmer and logger, "Actual renderer presents farmers and loggers at staffed buildings")
    V.assert(guard, "Actual renderer includes female militia alongside existing militia")
    for resource, amount in pairs(snapshot.world.stock) do
        V.assert(s.stock[resource] == amount, "Presentation preserves saved economy: " .. resource)
    end
    Art.draw = originalDraw
    V.finish()
end)
