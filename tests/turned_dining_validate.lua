dofile("tests/village_models_validate.lua")
local Pose=require "game.BuildingPose"
local Meals=require "game.Meals"
V.atFrame(20,function()
    local sim,view=require("network.Standalone").Inspect()
    local hall=sim.buildings[2]
    local shape=view.modelWorld.buildings[hall.id].node:GetChild("AuthoredBuilding")
    V.assert(Pose.yaw(hall)~=0,"The dining regression really uses a turned kitchen")
    for seat=1,4 do
        local x,y=Meals.seatPosition(hall,seat)
        local localSeat=Vector3(((seat-1)%2-.5)*.94,.20,-(math.floor((seat-1)/2)-.5)*.72)
        local actual=shape:LocalToWorld(localSeat)
        V.assert(math.abs(actual.x-(x-10))<.001 and math.abs(actual.z-(9-y))<.001,
            "Diner destination matches the actual transformed chair: " .. seat)
        local doorX,doorY=Meals.diningPosition(hall,seat,"enter",Meals.doorwaySeconds)
        local seatedX,seatedY=Meals.diningPosition(hall,seat,"enter",0)
        V.assert(math.abs(doorX-hall.x)<.001 and math.abs(doorY-hall.y-1)<.001 and
            math.abs(seatedX-x)<.001 and math.abs(seatedY-y)<.001,
            "Entrance route connects the existing road door to its turned chair: " .. seat)
    end
end)
