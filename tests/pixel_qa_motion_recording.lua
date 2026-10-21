-- Actual new-game construction, not a path tween or concept-scene animation.
local UI=require 'urhox-libs/UI'
local Game=require 'network.Standalone'
local Store=require 'game.PixelSaveStore'
local Actors=require 'game.PixelActors'
local run='motion01'
for _,arg in ipairs(GetArguments()) do run=arg:match('^-pixelqa%-run=([%w_-]+)$') or run end
local out='/workspace/artifacts/pixel-v1/independent-qa/'
local sim,view,building
local count,limit=0,800
local trace,history={},{}
function CapturePixelQAMotion()
    if count>=limit then return end
    local frame=Image()
    if graphics:TakeScreenShot(frame) then
        frame:SavePNG(string.format(out..run..'-frames/%04d.png',count))
        local record={frame=count,time=count*.05,progress=building.progress,complete=building.complete,actors={}}
        for _,p in ipairs(Actors.collect(sim,history)) do
            local x,y=view.worldToScreen(p.x,p.y)
            record.actors[#record.actors+1]={key=p.key,look=p.look,phase=p.actor.phase,action=p.action,direction=p.direction,frame=p.frame,cargo=p.cargo,x=x*UI.GetScale(),y=y*UI.GetScale()}
        end
        trace[#trace+1]=record
        count=count+1
    end
end
V.atFrame(8,function()
    Game.UseStore(Store.new({now=function() return 1000 end,read=function() return nil end,write=function() return true end}))
    local hud;sim,view,hud=Game.Inspect();hud.dismissIntro()
    sim,view,hud=Game.Inspect()
    sim.skipped=true
    hud.update(1)
    local ok,b=sim:build('house',8,8)
    V.assert(ok,'New-game resources can plan the filmed connected house without extra resources')
    if not ok then error(tostring(b)) end
    building=sim:buildingAt(8,8)
    if view.focus then view.focus(8,7.4) end
    sim.paused=true
end)
V.atFrame(12,function() SubscribeToEvent('EndAllViewsRender','CapturePixelQAMotion') end)
for frame=13,812 do
    V.atFrame(frame,function() sim.paused=false;sim:update(.05);sim.paused=true end)
end
V.atFrame(818,function()
    V.assert(count==limit,'All 800 motion frames came from the native renderer')
    local moving,carrying,hammering=false,false,false
    for _,r in ipairs(trace) do for _,a in ipairs(r.actors) do
        if a.phase=='walk' or a.phase=='carry' or a.phase=='toSite' then moving=true end
        if a.cargo then carrying=true end
        if a.action=='hammer' then hammering=true end
    end end
    V.assert(carrying and hammering,'The real recording includes delivered material and actual construction work')
    local f=File(out..run..'-trace.json',FILE_WRITE);f:WriteString(cjson.encode(trace));f:Close()
    V.finish()
end)
