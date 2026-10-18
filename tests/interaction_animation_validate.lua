-- Render real work cycles and verify that the same villager animates throughout.
local Game=require "network.Standalone"
local Art=require "game.Art"
local sim,original,frames
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
    local farm=sim:addBuilding("farm",8,8,true)
    V.assert(sim:staff(farm,1),"A real worker visits the field")
    view.home();view.zoom(0.8);hud.update()
    original,frames=Art.draw,{}
    Art.draw=function(vg,name,...)
        local painted=original(vg,name,...)
        if name:find("^person%-civilian%-") and painted then frames[name]=true end
        return painted
    end
end)
for frame=10,64 do
    V.atFrame(frame,function() sim:update(0.1) end)
end
V.atFrame(65,function()
    Art.draw=original
    local identity=sim.buildings[2]
    local role=require("game.Characters").worker(identity,1)
    V.assert(frames["person-" .. role .. "-se"] or frames["person-" .. role .. "-sw"] or
        frames["person-" .. role .. "-ne"] or frames["person-" .. role .. "-nw"],
        "Field work renders the assigned villager instead of a generic farmer")
    V.assert(not frames["person-farm-plow-1"] and not frames["person-farm-plow-2"],
        "Farm actions do not replace the villager's identity")
    V.assert(Art.exists("person-eating-blue-man-1") and Art.exists("person-eating-blue-man-2") and
        Art.exists("person-eating-chef-1") and Art.exists("person-eating-chef-2"),
        "Villagers and specialists have distinct eating keyframes")
    V.finish()
end)
