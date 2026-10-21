local Game=require "network.Standalone"
local Characters=require "game.Characters"
local Cargo=require "game.Cargo"
local demo,view
V.atFrame(8,function()
    Game.UseStore(require("game.SaveStore").new({now=function() return 1000 end,read=function() return nil end,write=function() return true end}),true)
    local hud
    demo,view,hud=Game.Inspect();hud.dismissIntro()
    demo,view,hud=Game.Inspect();hud.dismissIntro();demo.paused=true
    local model=view.modelWorld
    local update=model.update
    local people={}
    for i,resource in ipairs({"wood","stone","grain","meat","gold"}) do
        people[i]={x=7.8+(i-1)*1.1,y=12,workerLook=i%2+1,carrying=true,phase="toSite",timer=0,job={resource=resource},facing="se"}
    end
    model.update=function(self,...)
        update(self,...)
        for i,a in ipairs(people) do
            local _,profile=Characters.carrier(i,true,a)
            local key="cargoShowcase"..i
            a.x=a.x+.001;a.y=a.y+.002
            self:person(key,a,profile,nil,a.x,a.y,i)
            self.actors[key].seen=true
        end
        local center=Vector3(.05,.22,-3)
        self.cameraNode.position=center+Vector3(0,9,-math.sqrt(700)*9/30)
        self.cameraNode:LookAt(center);self.camera.orthoSize=2.7
        local l=view.panel:GetAbsoluteLayout();self.camera.aspectRatio=l.w/l.h
    end
end)
V.atFrame(20,function()
    for i=1,5 do
        local p=view.modelWorld.actors["cargoShowcase"..i]
        V.assert(p and p.load.enabled,"Game-rendered worker carries an authored cargo: "..i)
    end
    V.finish()
end)
