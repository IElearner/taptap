-- Capture the real runtime frame by frame, with deterministic simulation time.
-- This is a review fixture; it never writes to the player's save slot.
local Game=require 'network.Standalone'
local Meals=require 'game.Meals'
local scene='kitchen'
for _,arg in ipairs(GetArguments()) do scene=arg:match('^-v7%-scene=(.+)$') or scene end
local limits={kitchen=260,ranch=180,butcher=220,woodcutter=480,construction=560}
local limit=assert(limits[scene]);local frameNumber=0
local sim,view,b;local seen={};local peak=0;local highestStock=0
function CaptureVillageLifeFrame()
 if frameNumber>=limit then return end
 local shot=Image()
 if graphics:TakeScreenShot(shot) then
  shot:Resize(960,540)
  shot:SavePNG(string.format('/workspace/taptap/.tmp/v7-%s-frames/%04d.png',scene,frameNumber))
  frameNumber=frameNumber+1
 end
end
V.atFrame(8,function()
 Game.UseStore(require('game.SaveStore').new({now=function() return 1000 end,
  read=function() return nil end,write=function() return true end}),true)
 local hud;sim,view,hud=Game.Inspect();hud.dismissIntro();sim,view,hud=Game.Inspect();hud.dismissIntro()
 sim.started,sim.skipped,sim.population=true,true,40;sim.stock.food=200
 for i,a in ipairs(sim.carriers) do a.workerLook=(i-1)%2+1;a.hunger=0 end
 if scene=='construction' then
  sim.population=10;V.assert(sim:build('house',8,8),'The recording starts with a real planned house');b=sim.buildings[2]
 else
  b=sim:addBuilding(scene,8,8,true);b.workers=1
  if scene=='kitchen' then
   b.inputs,b.mealStock=4,8
   sim.carriers[4]={x=10,y=9,path={},index=1,job=false,carrying=false,hunger=100,energy=20,workerLook=2}
   for _,a in ipairs(sim.carriers) do a.hunger=100 end
  elseif scene=='ranch' then b.inputs=4
  elseif scene=='butcher' then b.inputs=4
  end
 end
 sim.paused=true;hud.update()
end)
V.atFrame(12,function()
 local model=view.modelWorld;local update=model.update
 local function frameCamera(self)
  local center=scene=='woodcutter' and Vector3(-4.4,.25,1.65) or Vector3(-3,.25,1.5)
  self.cameraNode.position=center+Vector3(0,9,-math.sqrt(700)*9/30);self.cameraNode:LookAt(center)
  self.camera.orthoSize=scene=='woodcutter' and 5.3 or scene=='construction' and 4.1 or 3.4
  local l=view.panel:GetAbsoluteLayout();self.camera.aspectRatio=l.w/l.h
 end
 model.update=function(self,...) update(self,...);frameCamera(self) end
 frameCamera(model)
 SubscribeToEvent('EndAllViewsRender','CaptureVillageLifeFrame')
end)
for frame=13,limit+16 do
 V.atFrame(frame,function()
  sim.paused=false;sim:update(.1);sim.paused=true
  peak=math.max(peak,Meals.occupancy(sim,b.id));highestStock=math.max(highestStock,b.buffer or 0)
  for _,a in pairs(sim.workers) do if a.woodPhase then seen[a.woodPhase]=true end end
 end)
end
V.atFrame(limit+18,function()
 V.assert(frameNumber==limit,'Every frame came from the actual game renderer')
 if scene=='kitchen' then V.assert(peak==4 and sim.mealsServed>=4,'Four real visitors sit, eat and leave a roofed kitchen')
 elseif scene=='ranch' then V.assert(b.feedVisits==1 and b.inputs==3,'A real grain bag feeds the moving pigs')
 elseif scene=='butcher' then V.assert(highestStock>0 and (sim.produced.meat or 0)>0,'Meat really appears locally and is carried to the warehouse')
 elseif scene=='woodcutter' then
  for _,phase in ipairs({'toTree','chop','felling','gather','toCamp','toRack','stack','fromRack'}) do
   V.assert(seen[phase],'The lumberjack performs '..phase)
  end
  V.assert(highestStock>0 and sim.stock.wood>72,'Real logs are stacked and delivered')
 elseif scene=='construction' then V.assert(b.complete and b.deliveredLoads==4,'Four actual material batches finish the house') end
 print('V7_RECORDED_SCENE',scene,frameNumber,sim.elapsed,highestStock)
 V.finish()
end)
