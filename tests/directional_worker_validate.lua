local Game=require "network.Standalone"
local Animation=require "game.DirectionalAnimation"
local Characters=require "game.Characters"
local demo,view,people
V.atFrame(8,function()
    V.assert(Animation.direction(180)==1 and Animation.direction(90)==7 and Animation.direction(-90)==3 and Animation.direction(0)==5,"Turning chooses front, right, left and back artwork correctly")
    V.assert(select(2,Animation.select({carrying=false},nil,true,.2,0))~=select(2,Animation.select({carrying=false},nil,true,.4,0)),"Walking advances from actual distance travelled")
    V.assert(Animation.select({job={kind="road"},timer=1},"hammer",false,0,0)=="road","Road work selects its own crouched mallet cycle")
    Game.UseStore(require("game.SaveStore").new({now=function() return 1000 end,read=function() return nil end,write=function() return true end}),true)
    local hud
    demo,view,hud=Game.Inspect();hud.dismissIntro();demo,view,hud=Game.Inspect();hud.dismissIntro()
    demo.skipped=true;demo.paused=true;hud.update()
    local model=view.modelWorld
    local update=model.update
    people={
        {x=7,y=11.8,carrying=false,phase="idle",timer=0,facing="sw",workerLook=1},
        {x=9,y=11.8,carrying=true,phase="toSite",timer=0,facing="sw",workerLook=1,job={resource="wood"}},
        {x=11,y=11.8,carrying=false,phase="hammer",timer=.43*1.6,facing="sw",workerLook=1,job={kind="road",x=11,y=12.2}},
        {x=13,y=11.8,carrying=false,phase="hammer",timer=.67*1.6,facing="sw",workerLook=1,job={kind="building",side="north",pointPhase=2}},
    }
    for i=1,4 do
        people[i].y=10.7
        local a={}
        for k,v in pairs(people[i]) do a[k]=v end
        a.y=12.2;a.workerLook=2
        if a.job and a.job.kind=="road" then a.job={kind="road",x=a.x,y=a.y+.4} end
        people[#people+1]=a
    end
    model.update=function(self,...)
        update(self,...)
        for i,a in ipairs(people) do
            local _,profile=Characters.carrier(1,a.carrying,a)
            self:person("directionalProbe"..i,a,profile,a.phase=="hammer" and "hammer" or nil,a.x,a.y,i)
        end
        local center=Vector3(0,.25,-2.45)
        self.cameraNode.position=center+Vector3(0,9,-math.sqrt(700)*9/30)
        self.cameraNode:LookAt(center);self.camera.orthoSize=4
        local l=view.panel:GetAbsoluteLayout();self.camera.aspectRatio=l.w/l.h
    end
end)
V.atFrame(20,function()
    local model=view.modelWorld
    for i=1,8 do
        local p=model.actors["directionalProbe"..i]
        V.assert(p and p.directional and p.billboards:GetMaterial()~=nil,"New worker artwork is actually rendered in the game scene: "..i)
        V.assert(p.direction>=1 and p.direction<=8 and p.frame>=1 and p.frame<=8,"Only authored directional frames are selected: "..i)
    end
    local p=model.actors.directionalProbe2
    local a=people[2]
    local node=p.node
    for _,resource in ipairs({"stone","grain","meat","gold","wood"}) do
        a.job.resource=resource
        local _,profile=Characters.carrier(1,true,a)
        model:person("directionalProbe2",a,profile,nil,a.x,a.y,0)
        V.assert(p.node==node and p.load.enabled,"Swapping cargo preserves the same animated person: "..resource)
    end
    local Motion=require "game.ActorMotion"
    local _,profile=Characters.carrier(1,true,a)
    local width,height=p.quad.size.x,p.quad.size.y
    a.phase,a.timer="unload",Motion.unloadSeconds
    model:person("directionalProbe2",a,profile,nil,a.x,a.y,0)
    local first=p.frame
    model.sim.elapsed=model.sim.elapsed+.7;a.timer=a.timer-.7
    model:person("directionalProbe2",a,profile,nil,a.x,a.y,0)
    V.assert(p.actionKey=="transition" and p.frame~=first,"Lowering the load advances real transition frames even in paused test recording")
    a.phase,a.timer,a.carrying="ready",Motion.readySeconds,false
    model.sim.elapsed=model.sim.elapsed+.1
    model:person("directionalProbe2",a,profile,nil,a.x,a.y,0)
    V.assert(p.actionKey=="transition" and p.frame>=5,"The worker straightens and takes a hammer before striking")
    V.assert(p.quad.size.x==width and p.quad.size.y==height,"Switching from carrying through unload and preparation never resizes the actor")
    V.finish()
end)
