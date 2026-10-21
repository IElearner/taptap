-- Real regressions for the V12 candidate: staged dispatch, old-save recovery,
-- distributed food, four independent settings, and art-aligned animal lanes.
local Sim=require 'game.Simulation'
local Sites=require 'game.ConstructionSites'
local Data=require 'game.SaveData'
local Meals=require 'game.Meals'
local Dining=require 'game.FrontDining'
local Game=require 'network.Standalone'
local sim,view,hall,ranch
local function untilTrue(s,predicate,seconds)
 for _=1,seconds*10 do if predicate() then return true end;s:update(.1) end
 return predicate()
end
local function millSite()
 local s=Sim.new();s.started,s.skipped,s.population=true,true,20;s.stock.food=200
 s.roads['13:9']=true;s.roadCount=s.roadCount+1
 local ok,_,b=s:build('mill',13,8);V.assert(ok,'A real mill plan can reproduce delayed stage delivery')
 return s,b
end
V.atFrame(8,function()
 local s,b=millSite()
 -- Later batches arrive before the foundation batch. This is the original
 -- reachable ordering which used to send all four builders to phase two.
 b.stageSupplies={['2wood']=true,['3wood']=true,['4wood']=true}
 s:update(.1)
 local future=0
 for _,a in ipairs(s.builders) do if a.job and a.job.building==b.id and a.job.advance then future=future+1 end end
 V.assert(future==0,'No crew member preclaims future work while the current stage has unclaimed points')
 V.assert(untilTrue(s,function() return b.complete end,180),'A real late foundation delivery still leads to a completed mill')
 local work=0;for _,p in ipairs(b.buildPoints) do work=work+p.work end
 V.assert(math.abs(work-Sites.totalWork)<.00001,'Dispatcher repair preserves all 36 worker-seconds')
 local old,stuck=millSite();local points=Sites.ensure(stuck)
 stuck.stageSupplies={['1stone']=true,['2wood']=true,['3wood']=true,['4wood']=true}
 for i=1,4 do
  local p=points[i+4]
  old.builders[i]={x=13+(i-2)*.1,y=9,path={},index=1,active=true,phase='awaitStage',timer=300,carrying=false,hunger=0,energy=100,workerLook=1,
   job={kind='building',building=stuck.id,pointId=p.id,pointPhase=p.phase,pointSide=p.side,resource=p.resource,amount=p.amount,delivery=false,advance=true,supplyOnly=false,
    doorX=13,doorY=9,workX=({13,11,13,14})[i],workY=({9,7,5,7})[i],side=({'south','west','north','east'})[i]}}
 end
 local restored,reason=Data.restore(cjson.decode(cjson.encode(Data.capture(old,1000,1,true))),'finite')
 if not restored then print('V12_SAVE_REPAIR_ERROR',reason) end
 V.assert(restored~=nil,'An actual saved all-awaitStage crew remains loadable')
 if restored then
  local target=restored.buildings[stuck.id]
  V.assert(untilTrue(restored,function() return target.complete end,180),'Loaded all-awaitStage crews release and finish the blocked foundation automatically')
  V.assert(restored:build('road',14,9),'A following road can be planned after the repaired mill')
  V.assert(untilTrue(restored,function() return restored.roads['14:9'] end,50),'The recovered crew also constructs following road plans')
 end
 local m={meal={phase='enter',timer=Meals.doorwaySeconds}}
 V.assert(Dining.presence(m)==0,'A merely reserved seat has no phantom dish')
 m.meal.phase,m.meal.timer='eat',Meals.eatSeconds
 V.assert(Dining.presence(m)==1,'A seated eater has a complete personal setting')
 m.meal.phase,m.meal.timer='exit',0
 V.assert(Dining.presence(m)==0,'The setting is cleared when its owner leaves')
 Game.UseStore(require('game.SaveStore').new({now=function() return 1000 end,read=function() return nil end,write=function() return true end}),true)
 local hud;sim,view,hud=Game.Inspect();hud.dismissIntro();sim,view,hud=Game.Inspect();hud.dismissIntro()
 sim.started,sim.skipped,sim.population=true,true,40;sim.stock.food=200
 hall=sim:addBuilding('kitchen',8,8,true);hall.mealStock=8
 ranch=sim:addBuilding('ranch',15,8,true);ranch.workers=1;ranch.inputs=4
 sim.carriers[4]={x=10,y=9,path={},index=1,job=false,carrying=false,hunger=100,energy=20,workerLook=2}
 for _,a in ipairs(sim.carriers) do a.hunger=100 end
 V.assert(untilTrue(sim,function()
  local n=0;for _,a in ipairs(sim.carriers) do if a.meal and a.meal.phase=='eat' then n=n+1 end end;return n==4
 end,45),'All four actual carriers simultaneously eat paid meals')
 sim.paused=true;hud.update()
end)
V.atFrame(20,function()
 local world=view.modelWorld;local room=world.buildings[hall.id]
 V.assert(#room.placeSettings==4,'The actual renderer owns four independent table settings')
 local seen={}
 for seat,setting in ipairs(room.placeSettings) do
  V.assert(setting.node.enabled and setting.draw.enabled and setting.alpha==1,'Occupied setting is rendered: '..seat)
  V.assert(setting.occupant==Meals.occupant(sim,hall.id,seat) and not seen[setting.occupant],'The visible dish belongs to exactly one actual diner: '..seat)
  seen[setting.occupant]=true
  V.assert(setting.draw.numBillboards==2 and setting.draw.material~=nil,'Each place has its own loaded side dish and tea: '..seat)
 end
 local a=room.placeSettings[2].occupant;a.meal=false
 Dining.updateSettings(world,hall,room)
 V.assert(not room.placeSettings[2].node.enabled and room.placeSettings[1].node.enabled and room.placeSettings[3].node.enabled,'One diner leaving clears only its own setting')
 local pen=world.buildings[ranch.id]
 V.assert(pen.painted.frontFence and pen.painted.frontFence.enabled,'The rendered front fence has its own foreground layer')
 local Life=require 'game.WorkshopLife'
 local start=sim.elapsed
 local separation=math.huge
 for frame=1,480 do
  sim.elapsed=start+frame*.25
  Life.update(world,ranch)
  for i,pig in ipairs(pen.pigs) do
   V.assert(pig.penU>=.52 and pig.penU<=.86 and pig.penV>=.64 and pig.penV<=.66,'Animal target stays behind the complete front fence and its post tops')
   V.assert(math.abs(pig.ground.y-.025)<.00001 and pig.art.shadow.enabled,'Animal feet and contact shadow remain on the paddock ground')
   for j=1,i-1 do separation=math.min(separation,(pig.ground-pen.pigs[j].ground):Length()) end
  end
 end
 V.assert(separation>.16,'Separate grazing lanes keep three animals distinguishable through a complete cycle')
 V.assert(room.frontCourt.paving:GetComponent('CustomGeometry'):GetNumVertices(0)==48,'Door approach is continuous curved paving rather than a rectangular plane')
 V.assert((room.frontCourt.finish-Vector3(hall.x-10,.018,9-(hall.y+1))):Length()<.0001,'The approach terminates on the real logistics road')
 V.finish()
end)
