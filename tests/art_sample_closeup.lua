-- Close camera for art inspection; the houses and actors still come from the
-- actual game fixture, not a pre-rendered illustration or a separate renderer.
dofile("tests/layout_validate.lua")
local Game=require "network.Standalone"
V.atFrame(18,function()
    local _,view=Game.Inspect()
    local model=view.modelWorld
    local update=model.update
    model.update=function(self,...)
        update(self,...)
        local center=Vector3(-3,0.30,1.5)
        self.cameraNode.position=center+Vector3(0,9,-math.sqrt(700)*9/30)
        self.cameraNode:LookAt(center)
        self.camera.orthoSize=3.9
        local l=view.panel:GetAbsoluteLayout();self.camera.aspectRatio=l.w/l.h
    end
end)
