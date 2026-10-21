-- Inspect actual four-person construction and the rebuilt worker up close.
dofile("tests/model_world_validate.lua")
local Game=require "network.Standalone"
V.atFrame(18,function()
    local _,view=Game.Inspect()
    local model=view.modelWorld
    local update=model.update
    model.update=function(self,...)
        update(self,...)
        local center=Vector3(-5,0.30,4.5)
        self.cameraNode.position=center+Vector3(0,9,-math.sqrt(700)*9/30)
        self.cameraNode:LookAt(center)
        self.camera.orthoSize=4.2
        local l=view.panel:GetAbsoluteLayout();self.camera.aspectRatio=l.w/l.h
    end
end)
