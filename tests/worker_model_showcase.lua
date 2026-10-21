local Game=require "network.Standalone"
local Characters=require "game.Characters"
local demo,view
V.atFrame(8,function()
    Game.UseStore(require("game.SaveStore").new({now=function() return 1000 end,read=function() return nil end,write=function() return true end}),true)
    local hud
    demo,view,hud=Game.Inspect();hud.dismissIntro()
    demo,view,hud=Game.Inspect();hud.dismissIntro();demo.skipped=true;demo.paused=true;hud.update()
    local model=view.modelWorld
    local update=model.update
    local people={}
    for look=1,2 do for column=1,4 do
        people[#people+1]={x=7+(column-1)*2,y=10.8+(look-1)*1.7,workerLook=look,carrying=column==2,
            phase=column>=3 and "hammer" or column==2 and "toSite" or "idle",timer=(column==3 and .67 or .43)*1.6,
            job=column>=3 and {kind=column==3 and "road" or "building",x=7+(column-1)*2,y=10.4+(look-1)*1.7,side="south",pointPhase=column==3 and 1 or 2} or {resource="wood"},
            facing="sw",column=column}
    end end
    model.update=function(self,...)
        update(self,...)
        for i,a in ipairs(people) do
            local _,profile=Characters.carrier(i,a.carrying,a)
            self:person("workerShowcase"..i,a,profile,a.column>=3 and "hammer" or nil,a.x,a.y,i)
        end
        local center=Vector3(0,.26,-2.65)
        self.cameraNode.position=center+Vector3(0,9,-math.sqrt(700)*9/30)
        self.cameraNode:LookAt(center);self.camera.orthoSize=4.3
        local l=view.panel:GetAbsoluteLayout();self.camera.aspectRatio=l.w/l.h
    end
end)
V.atFrame(20,function()
    local manifest=require "game.WorkerManifest"
    for i=1,8 do
        local p=view.modelWorld.actors["workerShowcase"..i]
        local id=i<=4 and "blue-man" or "ochre-woman"
        V.assert(p and p.modelId==id,"Remodelled worker identity is stable: "..i)
        local mesh=p.head:GetComponent("StaticModel")
        V.assert(mesh and mesh.model==cache:GetResource("Model",manifest.models[id.."_head"].model),"New worker head mesh is actually used: "..i)
        V.assert(p.torso:GetComponent("StaticModel").model==cache:GetResource("Model",manifest.models[id.."_torso"].model),"New worker clothing mesh is actually used: "..i)
        V.assert(p.hands[1]:GetChild("Grip") and p.feet[1],"New hands and shoes stay on articulated joints: "..i)
    end
    V.finish()
end)
