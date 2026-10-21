-- Record the actual running simulation through the game's normal renderer.
-- No generated animation/video or substitute renderer is used.
local Game=require "network.Standalone"
local sim,view
local dining=false
for _,arg in ipairs(GetArguments()) do if arg=="-motion-demo=dining" then dining=true end end
local frameLimit=dining and 60 or 100
local frameNumber=0
function CaptureInteractionFrame()
    if frameNumber>=frameLimit then return end
    local shot=Image()
    if graphics:TakeScreenShot(shot) then
        shot:Resize(960,508)
        shot:SavePNG(string.format("/workspace/taptap/.tmp/directional-%s-frames/%03d.png",dining and "dining" or "construction",frameNumber))
        frameNumber=frameNumber+1
    end
end
V.atFrame(8,function()
    Game.UseStore(require("game.SaveStore").new({now=function() return 1000 end,
        read=function() return nil end,write=function() return true end}),true)
    local hud
    sim,view,hud=Game.Inspect();hud.dismissIntro()
    sim,view,hud=Game.Inspect();hud.dismissIntro();sim.started,sim.skipped=true,true
    if dining then
        local hall=sim:addBuilding("kitchen",8,8,true);hall.mealStock=8
        sim.militia=1;sim:update(.1)
        for _,a in ipairs(sim.carriers) do a.hunger=92 end
        for _,a in ipairs(sim.guards) do a.hunger=92 end
        for _=1,300 do
            sim:update(.1)
            if require("game.Meals").occupancy(sim,hall.id)==4 then break end
        end
        for _=1,17 do sim:update(.1) end
    else
        for _,p in ipairs({{7,9},{6,9},{6,8},{6,7},{6,6}}) do sim.roads[p[1]..":"..p[2]]=true end
        sim.roadCount=5
        V.assert(sim:build("house",6,5),"Recording uses an actual accessible construction site")
        -- Record the frame-raising portion, after the real delivery/foundation
        -- simulation. Recorded frames themselves advance at normal 0.1s steps.
        for _=1,4000 do
            sim:update(.05)
            local reached=false
            local site=sim:buildingAt(6,5)
            for _,p in ipairs(site.buildPoints or {}) do if p.phase==2 and p.work>0 then reached=true end end
            if reached then break end
        end
    end
    sim.paused=true;hud.update()
end)
V.atFrame(12,function()
    local model=view.modelWorld
    local update=model.update
    model.update=function(self,...)
        update(self,...)
        local center=dining and Vector3(-3,.18,1.5) or Vector3(-5,.20,4.5)
        self.cameraNode.position=center+Vector3(0,9,-math.sqrt(700)*9/30)
        self.cameraNode:LookAt(center);self.camera.orthoSize=dining and 3.4 or 4.2
        local layout=view.panel:GetAbsoluteLayout();self.camera.aspectRatio=layout.w/layout.h
    end
    SubscribeToEvent("EndAllViewsRender","CaptureInteractionFrame")
end)
for frame=13,frameLimit+16 do
    V.atFrame(frame,function() sim.paused=false;sim:update(.1);sim.paused=true end)
end
V.atFrame(frameLimit+18,function()
    V.assert(frameNumber==frameLimit,"The complete sequence of actual rendered interaction frames was captured")
    V.finish()
end)
