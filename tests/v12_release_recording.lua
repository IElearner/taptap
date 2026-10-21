-- Deterministic review footage captured from the actual Maker scene.
-- It uses a disposable save backend and never touches a player's progress.
local Game=require 'network.Standalone'
local Meals=require 'game.Meals'
local scene,run='village','review2'
local requestedLimit
for _,arg in ipairs(GetArguments()) do
    requestedLimit=tonumber(arg:match('^-v12%-limit=(%d+)$')) or requestedLimit
    scene=arg:match('^-v12%-scene=(.+)$') or scene
    run=arg:match('^-v12%-run=([%w_-]+)$') or run
end
local limits={village=400,construction=1200,kitchen=700,ranch=900}
local limit=requestedLimit or assert(limits[scene]);local count=0;local sim,view,building;local lastRecorded={}
function CaptureVisualUpgradeFrame()
    if count>=limit then return end
    local frame=Image()
    if graphics:TakeScreenShot(frame) then
        frame:SaveJPG(string.format('/workspace/artifacts/shanheli-v12/frames-%s-%s/%04d.jpg',scene,run,count),94)
        count=count+1
        if count==limit then
            lastRecorded.complete=building and building.complete
            lastRecorded.meals=sim.mealsServed
            lastRecorded.feedVisits=building and building.feedVisits or 0
        end
    end
end
V.atFrame(8,function()
    Game.UseStore(require('game.SaveStore').new({now=function() return 1000 end,read=function() return nil end,write=function() return true end}),true)
    local hud;sim,view,hud=Game.Inspect();hud.dismissIntro();sim,view,hud=Game.Inspect();hud.dismissIntro()
    if scene=='village' then
        hud.root:FindById('visitDemo').props.onClick()
        sim,view,hud=Game.Inspect();hud.dismissIntro();sim,view,hud=Game.Inspect();hud.dismissIntro()
        for _=1,1100 do sim:update(.1) end
    else
        sim.started,sim.skipped,sim.population=true,true,10;sim.stock.food=200
        for i,a in ipairs(sim.carriers) do a.workerLook=(i-1)%2+1;a.hunger=0 end
        if scene=='construction' then
            V.assert(sim:build('house',8,8),'Recording plans a real connected house')
            building=sim.buildings[2]
        else
            building=sim:addBuilding(scene,8,8,true);building.workers=1;building.inputs=4
            if scene=='kitchen' then
                sim.population=40;building.mealStock=8
                sim.carriers[4]={x=10,y=9,path={},index=1,job=false,carrying=false,hunger=100,energy=20,workerLook=2}
                for _,a in ipairs(sim.carriers) do a.hunger=100 end
                V.assert(Meals.occupancy(sim,building.id)==0,'The film starts with empty seats and records the full doorway sequence')
            else sim:update(.1) end
        end
    end
    sim.started,sim.skipped,sim.menuOpen,sim.paused=true,true,false,true
    hud.update()
end)
V.atFrame(12,function()
    local world=view.modelWorld;local original=world.update
    world.update=function(self,...)
        original(self,...)
        if scene=='village' then return end
        local center=Vector3(-3,.23,1.5)
        self.cameraNode.position=center+Vector3(0,9,-math.sqrt(700)*9/30)
        self.cameraNode:LookAt(center);self.camera.orthoSize=scene=='construction' and 4.7 or 3.5
        local l=view.panel:GetAbsoluteLayout();self.camera.aspectRatio=l.w/l.h
    end
    SubscribeToEvent('EndAllViewsRender','CaptureVisualUpgradeFrame')
end)
for frame=13,limit+60 do
    V.atFrame(frame,function() sim.paused=false;sim:update(.05);sim.paused=true end)
end
V.atFrame(limit+64,function()
    V.assert(count==limit,'Every recorded frame comes from the real running renderer')
    if scene=='construction' then
        local total=0;for _,point in ipairs(building.buildPoints) do total=total+point.work end
        V.assert(lastRecorded.complete and math.abs(total-36)<.00001,'The filmed house completes its fixed 36 worker-seconds')
        V.assert(building.deliveredLoads==4,'The film includes four physical stage-material deliveries')
    elseif scene=='kitchen' then V.assert(lastRecorded.meals>=4,'The filmed visitors really finish their meals')
    elseif scene=='ranch' then V.assert(lastRecorded.feedVisits>0,'The film includes actual feeding with delivered grain') end
    V.finish()
end)
