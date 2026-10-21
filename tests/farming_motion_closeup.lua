-- Inspect the actual assigned farmer, retaining the farm/identity regression.
dofile("tests/interaction_animation_validate.lua")
local Game=require "network.Standalone"
V.atFrame(10,function()
    local _,view=Game.Inspect()
    local model=view.modelWorld
    local update=model.update
    model.update=function(self,...)
        update(self,...)
        local center=Vector3(-2.5,.18,1.5)
        self.cameraNode.position=center+Vector3(0,9,-math.sqrt(700)*9/30)
        self.cameraNode:LookAt(center);self.camera.orthoSize=2.8
        local layout=view.panel:GetAbsoluteLayout();self.camera.aspectRatio=layout.w/layout.h
    end
end)
