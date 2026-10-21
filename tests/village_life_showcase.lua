-- Controlled states of the real game renderer, never concept art mockups.
local Game=require 'network.Standalone'
local Meals=require 'game.Meals'
local scene='kitchen'
for _,arg in ipairs(GetArguments()) do scene=arg:match('^-v7%-scene=(.+)$') or scene end
local sim,view,hud,b
V.atFrame(8,function()
 Game.UseStore(require('game.SaveStore').new({now=function() return 1000 end,read=function() return nil end,write=function() return true end}),true)
 sim,view,hud=Game.Inspect();hud.dismissIntro();sim,view,hud=Game.Inspect();hud.dismissIntro()
 sim.started,sim.skipped,sim.population=true,true,40;sim.stock.food=200
 b=sim:addBuilding(scene,8,8,true);b.workers=1
 if scene=='kitchen' then
  b.inputs,b.mealStock=4,8
  sim.carriers[#sim.carriers+1]={x=10,y=9,path={},index=1,job=false,carrying=false,hunger=100,energy=20,workerLook=2}
  for _,a in ipairs(sim.carriers) do a.hunger=100 end
  for _=1,250 do
   sim:update(.1)
   local count=0;for _,a in ipairs(sim.carriers) do if a.meal and a.meal.phase=='eat' then count=count+1 end end
   if count==4 then break end
  end
 elseif scene=='ranch' then b.inputs=4;for _=1,12 do sim:update(.1) end
 elseif scene=='butcher' then b.inputs=4;for _=1,20 do sim:update(.1) end
 elseif scene=='woodcutter' then b.buffer=2;for _=1,2 do sim:update(.1) end
 end
 sim.paused=true;hud.update()
end)
V.atFrame(12,function()
 local model=view.modelWorld;local update=model.update
 model.update=function(self,...)
  update(self,...)
  local center=Vector3(-3,.30,1.5)
  self.cameraNode.position=center+Vector3(0,9,-math.sqrt(700)*9/30);self.cameraNode:LookAt(center)
  self.camera.orthoSize=3.4
  local l=view.panel:GetAbsoluteLayout();self.camera.aspectRatio=l.w/l.h
 end
end)
V.atFrame(16,function()
 local model=view.modelWorld;local shape=model.buildings[b.id].node:GetChild('AuthoredBuilding')
 V.assert(shape~=nil,'The completed workshop is the actual authored architecture')
 V.assert(model.buildings[b.id].stockRoot~=nil,'Visible inventory belongs to the actual building transform')
 if scene=='kitchen' then
  V.assert(Meals.occupancy(sim,b.id)==4,'Four actual diners occupy the four real seats')
  V.assert(shape:GetChild('ArchitectureMesh')~=nil,'The kitchen remains the same roofed mesh during dining')
  for _,a in ipairs(sim.carriers) do V.assert(a.meal and a.meal.phase=='eat','The displayed diner has a paid seated meal') end
 elseif scene=='ranch' then
  V.assert(#model.buildings[b.id].pigs==3,'Three independently articulated pigs occupy the pen')
  V.assert(b.feedVisits==1 and b.inputs==3,'The feeding animation has actually consumed one delivered bag')
 end
end)
V.atFrame(32,function() V.finish() end)
