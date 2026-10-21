dofile("tests/layout_validate.lua")
local Pose=require "game.BuildingPose"
local Data=require "game.SaveData"
local Game=require "network.Standalone"
local added={}
V.atFrame(14,function()
    local sim,_,hud=Game.Inspect()
    added[1]=sim:addBuilding("house",6,12,true)
    added[2]=sim:addBuilding("house",10,5,true)
    hud.update()
end)
V.atFrame(18,function()
    local sim,view=Game.Inspect()
    local angles={}
    for _,b in ipairs(sim.buildings) do
        local shape=view.modelWorld.buildings[b.id].node:GetChild("AuthoredBuilding")
        if b.kind=="house" and b.complete then
            local yaw=Pose.yaw(b)
            V.assert(math.abs(yaw)>=5 and math.abs(yaw)<=12,"House has a small turn, rather than a uniform 45 degree rotation")
            V.assert(shape and math.abs(shape.rotation.yawAngle-yaw)<.01,"The actual architecture mesh uses its own ground orientation")
            V.assert(#require("game.Definitions").cells(b)==6,"Turning a house preserves its rectangular reserved plot")
            angles[yaw]=true
        end
    end
    local count=0;for _ in pairs(angles) do count=count+1 end
    V.assert(count>=3,"Different houses face three distinct small angles in the same scene")
    local restored=Data.restore(cjson.decode(cjson.encode(Data.capture(sim,1000,1,true))),"finite")
    V.assert(restored~=nil,"The turned village keeps a valid existing save format")
    for _,b in ipairs(added) do
        V.assert(restored and Pose.yaw(restored.buildings[b.id])==Pose.yaw(b),"Loading a save cannot randomize a house orientation")
    end
    V.assert(view.modelWorld.camera.orthographic and math.abs(view.modelWorld.cameraNode.position.y-30)<.001,
        "Only architecture turns; the existing overhead camera is retained")
end)
