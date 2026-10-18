-- Diners sit inside the open model and animate their shoulder joints.
local Game=require "network.Standalone"
local sim,view,seen
seen={}
V.atFrame(6,function()
    Game.UseStore(require("game.SaveStore").new({now=function() return 1000 end,
        read=function() return nil end,write=function() return true end}),true)
end)
V.atFrame(9,function()
    local hud
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
        "Four real villagers occupy the dining room")
    view.home();view.zoom(0.65);hud.update()

end)
for frame=10,46 do V.atFrame(frame,function()
    for key,person in pairs(view.modelWorld.actors) do
        if person.action=="eat" then
            seen[key]=seen[key] or {}
            seen[key][tostring(person.shoulders[2].rotation.x)]=true
        end
    end
    sim:update(0.08)
end) end
V.atFrame(47,function()
    local animated=false
    for _,poses in pairs(seen) do
        local count=0;for _ in pairs(poses) do count=count+1 end
        if count>1 then animated=true end
    end
    V.assert(animated,"A seated villager moves its real arm joint while eating")
    V.finish()
end)
