-- Field work moves real articulated geometry without changing worker identity.
local Game=require "network.Standalone"
local sim,view,identity,poses
poses={}
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
    local farm=sim:addBuilding("farm",8,8,true)
    V.assert(sim:staff(farm,1),"A real worker visits the field")
    view.home();view.zoom(0.8);hud.update()
    local _,profile=require("game.Characters").worker(farm,1)
    identity=profile.id
end)
for frame=10,64 do
    V.atFrame(frame,function()
        local person=view.modelWorld.actors["worker2:1"]
        if person then
            V.assert(person.profile.id==identity,"Field work keeps the same worker model")
            poses[tostring(person.torso.rotation.x)]=true
        end
        sim:update(0.1)
    end)
end
V.atFrame(65,function()
    local count=0;for _ in pairs(poses) do count=count+1 end
    V.assert(count>1,"The field worker bends and moves through actual joint poses")
    V.finish()
end)
