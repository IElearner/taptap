-- Real diners should alternate two painted eating poses in the visible bay.
local Game=require "network.Standalone"
local Art=require "game.Art"
local sim,original,seen
V.atFrame(6,function()
    Game.UseStore(require("game.SaveStore").new({now=function() return 1000 end,
        read=function() return nil end,write=function() return true end}),true)
end)
V.atFrame(9,function()
    local view,hud
    sim,view,hud=Game.Inspect();hud.dismissIntro()
    sim,view,hud=Game.Inspect();hud.dismissIntro()
    sim.started,sim.skipped,sim.menuOpen=true,true,false
    local intro=hud.root:FindById("modeScreen");if intro then intro:Hide() end
    local mentor=hud.root:FindById("mentorDialogue");if mentor then mentor:Hide() end
    local kitchen=sim:addBuilding("kitchen",8,8,true)
    kitchen.mealStock=8
    sim.militia=1;sim:update(0.1)
    for _,actor in ipairs(sim.carriers) do actor.hunger=92 end
    for _,actor in ipairs(sim.guards) do actor.hunger=92 end
    for _=1,200 do
        sim:update(0.1)
        if require("game.Meals").occupancy(sim,kitchen.id)==4 then break end
    end
    V.assert(require("game.Meals").occupancy(sim,kitchen.id)==4,
        "Four real villagers occupy the painted dining bay")
    view.home();view.zoom(0.65);hud.update()
    original,seen=Art.draw,{}
    Art.draw=function(vg,name,...)
        local painted=original(vg,name,...)
        if painted and name:find("^person%-eating%-%a") then seen[name]=true end
        return painted
    end
end)
for frame=10,46 do V.atFrame(frame,function() sim:update(0.08) end) end
V.atFrame(47,function()
    Art.draw=original
    local animated=false
    for name in pairs(seen) do
        local base=name:match("^(person%-eating%-.+)%-1$")
        if base and seen[base .. "-2"] then animated=true end
    end
    V.assert(animated,"A seated villager visibly alternates eating keyframes while dining")
    V.finish()
end)
