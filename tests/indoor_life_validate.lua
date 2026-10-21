local Game=require 'network.Standalone'
local Sim=require 'game.Simulation'
local Data=require 'game.SaveData'
local Ranch=require 'game.RanchCycle'
local Meals=require 'game.Meals'
local Life=require 'game.WorkshopLife'
local sim,view,hall,chef,chefKey,indoorPen
local function tick(s,n)
 local paused=s.paused;s.paused=false
 for _=1,math.floor(n*10+.5) do s:update(.1) end
 s.paused=paused
end
V.atFrame(8,function()
 -- Actual feed consumption happens after the caretaker has crossed the yard.
 local s=Sim.new();s.started,s.skipped,s.population=true,true,10;s.stock.food=200
 local pen=s:addBuilding('ranch',8,8,true);pen.workers=1;pen.inputs=3;pen.inputGoods={grain=3}
 local seen,restored={},{}
 for _=1,800 do
  s:update(.1)
  local phase=pen.ranchPhase or 'indoors';seen[phase]=true
  local a=s.workers[pen.id..':1']
  if phase=='exit' and (pen.feedVisits or 0)==0 then V.assert(pen.inputs==3,'Walking to the pen does not consume feed in advance') end
  if phase=='indoors' and a then V.assert(Life.hidden(pen,a),'The caretaker is concealed inside between feeding visits') end
  if phase=='feed' and a then V.assert(not Life.hidden(pen,a) and Life.action(pen,a)=='feed','Feeding shows the same caretaker in the pen') end
  if not restored[phase] then
   local save=Data.capture(s,1000,1,true)
   local loaded=Data.restore(cjson.decode(cjson.encode(save)),'finite')
   V.assert(loaded~=nil,'Saving preserves caretaker phase: '..phase)
   if loaded then
    local p=loaded.buildings[pen.id]
    V.assert(p.ranchPhase==pen.ranchPhase and p.inputs==pen.inputs and p.feedClock==pen.feedClock,'Resume does not repeat or skip a feed handoff')
   end
   restored[phase]=true
  end
 end
 V.assert(seen.exit and seen.feed and seen['return'] and seen.indoors,'The complete indoor-exit-feed-return cycle really occurs')
 V.assert(pen.inputs==3-(pen.feedVisits or 0),'Every completed feeding consumes exactly one real grain batch')
 local invalid=Data.capture(s,1000,1,true);invalid.world.buildings[pen.id].ranchClock=999
 V.assert(Data.restore(invalid,'finite')==nil,'Malformed doorway timers are rejected')
 Game.UseStore(require('game.SaveStore').new({now=function() return 1000 end,read=function() return nil end,write=function() return true end}),true)
 local hud;sim,view,hud=Game.Inspect();hud.dismissIntro();sim,view,hud=Game.Inspect();hud.dismissIntro()
 sim.started,sim.skipped,sim.population=true,true,40;sim.stock.food=200
 hall=sim:addBuilding('kitchen',8,8,true);hall.workers=1;hall.inputs=8;hall.inputGoods={flour=8};hall.mealStock=8
 for x=11,14 do sim.roads[x..':9']=true end;sim.roadCount=sim.roadCount+4
 indoorPen=sim:addBuilding('ranch',14,8,true);indoorPen.workers=1
 sim.carriers[4]={x=10,y=9,path={},index=1,job=false,carrying=false,hunger=100,energy=20,workerLook=2}
 for _,a in ipairs(sim.carriers) do a.hunger=100 end
 for _=1,400 do
  sim:update(.1)
  if Meals.occupancy(sim,hall.id)==4 then
   local eating=0;for _,a in ipairs(sim.carriers) do if a.meal and a.meal.phase=='eat' then eating=eating+1 end end
   if eating==4 then break end
  end
 end
 chefKey=hall.id..':1';chef=sim.workers[chefKey];chef.hunger=0
 sim.paused=false;hud.update()
end)
V.atFrame(12,function()
 local world=view.modelWorld;local original=world.update
 world.update=function(self,...)
  original(self,...)
  local center=Vector3(-3,.23,1.5)
  self.cameraNode.position=center+Vector3(0,9,-math.sqrt(700)*9/30)
  self.cameraNode:LookAt(center);self.camera.orthoSize=3.5
  local l=view.panel:GetAbsoluteLayout();self.camera.aspectRatio=l.w/l.h
 end
end)
V.atFrame(25,function()
 sim.paused=true
 local world=view.modelWorld;local room=world.buildings[hall.id]
 V.assert(room.painted.spec.material=='art/v12/kitchen.material' and room.painted.node.enabled,'The enclosed hall keeps its whole roof and clean table artwork in the actual world')
 local diners=0
 for i,a in ipairs(sim.carriers) do
  local p=world.actors['carrier'..i]
  if a.meal and a.meal.phase=='eat' then
   diners=diners+1
   V.assert(p and p.interior=='diner' and p.node.enabled,'A real paid diner appears through a dining window')
   V.assert(p.actionKey=='front-dining' and p.direction==1,'Every seated person faces straight out of the window rather than alternating sideways')
   V.assert(p.quad.size.y<p.height*.4 and not p.load.enabled and not p.shadow.enabled,'The wall hides chairs and legs instead of displaying an outdoor body')
  end
 end
 V.assert(diners==4,'All four indoor places are in use')
 V.assert(room.painted.foreground~=nil,'The existing tabletops and sills visibly occlude the lower seated bodies')
 local cook=world.actors['worker'..chefKey]
 V.assert(cook and cook.interior=='chef' and cook.node.enabled,'The cooking chef appears only at her separate window')
 V.assert(room.smoke.node.enabled and room.smoke.strength>0,'The actual working kitchen emits chimney smoke')
 for _,chair in ipairs(room.chairs) do V.assert(not chair.enabled,'No old chairs remain lined up outdoors') end
 local caretaker=world.actors['worker'..indoorPen.id..':1']
 V.assert(caretaker and not caretaker.node.enabled and not caretaker.billboards.enabled,'The actual caretaker drawable disappears inside the hut')
 V.assert(not caretaker.previous.enabled,'A blended previous pose cannot remain outside after the caretaker enters')
 local yard=world.buildings[indoorPen.id]
 local Art=require 'game.PaintedArchitecture'
 local endPoint=yard.gate.worldPosition+yard.gate.worldRotation*Vector3(.30*yard.gate.worldScale.x,0,0)
 local gateEnd=world.camera:WorldToScreenPoint(endPoint)
 local openingEnd=world.camera:WorldToScreenPoint(Art.anchor(world,indoorPen,.816,.798))
 V.assert(math.abs(gateEnd.x-openingEnd.x)<.01,'The closed short gate stays within the painted doorway posts')
 V.assert(yard.entrance.worldScale.z>0 and yard.entrance.worldScale.z<=1.30,'The front apron bridges toward the road without becoming a long protruding lane')
 indoorPen.inputs=1;indoorPen.inputGoods={grain=1}
end)
V.atFrame(28,function()
 hall.inputs=0;hall.inputGoods={};tick(sim,3.5)
end)
V.atFrame(32,function()
 local p=view.modelWorld.actors['worker'..chefKey]
 V.assert(chef.workPresence==1 and p and p.interior==nil and p.node.enabled,'The chef walks out to rest with her unchanged full-body appearance')
 V.assert(not view.modelWorld.buildings[hall.id].smoke.node.enabled,'An inactive kitchen stops emitting smoke')
 local caretaker=view.modelWorld.actors['worker'..indoorPen.id..':1']
 V.assert(caretaker.node.enabled and caretaker.billboards.enabled,'The same caretaker drawable reappears for the next real feeding visit')
 hall.inputs=4;hall.inputGoods={flour=4};local timer=hall.timer;tick(sim,1)
 V.assert(hall.timer==timer and chef.workPresence>0,'Cooking waits until the resting chef has returned indoors')
 tick(sim,2.5)
end)
V.atFrame(38,function()
 local p=view.modelWorld.actors['worker'..chefKey]
 V.assert(chef.workPresence==0 and p.interior=='chef','Returning to work restores the window pose rather than a second character')
 tick(sim,5)
end)
V.atFrame(44,function()
 local caretaker=view.modelWorld.actors['worker'..indoorPen.id..':1']
 V.assert(not Ranch.busy(indoorPen) and not caretaker.billboards.enabled,'After feeding, the caretaker returns inside and its actual drawable is hidden again')
 V.finish()
end)
