local Sim=require 'game.Simulation'
local Data=require 'game.SaveData'
local Sites=require 'game.ConstructionSites'
local Ranch=require 'game.RanchCycle'
local Meals=require 'game.Meals'
local Cargo=require 'game.Cargo'
local function tick(s,seconds) for _=1,math.floor(seconds*10+.5) do s:update(.1) end end
local function roundtrip(s) local a,e=Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000,1,true))),'finite');if not a then print('SAVE_VALIDATION_ERROR',e) end;return a end
V.atFrame(8,function()
 for _,pop in ipairs({4,10}) do
  local s=Sim.new();s.started,s.skipped,s.population=true,true,pop;s.stock.food=200
  V.assert(s:build('house',8,8),'A real connected house is planned')
  local b=s.buildings[2];local waits,maximum,loaded,early=0,0,{},false
  local queued=0
  for t=1,3500 do
   s:update(.1)
   local hammer=0
   for _,a in ipairs(s.builders) do
    if a.phase=='waitMaterials' then waits=waits+.1 end
    if a.phase=='hammer' then hammer=hammer+1;V.assert(Sites.ensure(b)[a.job.pointId].delivered,'Each hammer strike is supplied') end
   end
   for _,a in ipairs(s.carriers) do
    if a.job and a.job.construction and a.carrying then loaded[a.job.supplyPhase]=true end
   end
   if b.stageSupplies and b.stageSupplies['2wood'] and Sites.phase(b)==1 then early=true end
   maximum=math.max(maximum,hammer)
   if t%17==0 and not b.complete then V.assert(roundtrip(s)~=nil,'Queued, carried and staged supplies survive saves') end
   if b.complete then break end
  end
  local work=0;for _,p in ipairs(b.buildPoints) do work=work+p.work end
  V.assert(b.complete and b.deliveredLoads==4 and math.abs(work-36)<.000001,'Four material batches complete the same 36 worker-seconds')
  V.assert(waits==0,'Builders are not sent to stand waiting for unsupplied points')
  V.assert(s.stock.wood==64 and s.stock.stone==38,'Prefetch does not charge escrowed materials twice')
  V.assert(loaded[1] and loaded[2] and loaded[3] and loaded[4],'All stage resources really travel in workers hands')
  V.assert(pop==4 and maximum==1 or pop==10 and maximum>1,'Variable crews use a fixed population budget')
  V.assert(early,'Later materials arrive before the preceding stage is complete')
 end
 -- There is no automatic eating before an actual complete kitchen exists.
 local none=Sim.new();none.started,none.skipped=true,true
 for _,c in ipairs(none.carriers) do c.hunger=110;c.energy=10 end
 tick(none,20)
 for _,c in ipairs(none.carriers) do V.assert(not c.meal,'No canteen means no phantom seated diner') end
 -- Goods stay on shelves while a worker walks toward their source.
 local s=Sim.new();s.started,s.skipped=true,true
 local farm=s:addBuilding('farm',8,8,true);local mill=s:addBuilding('mill',12,8,true)
 farm.buffer=3;s:update(.1)
 V.assert(farm.buffer==3 and farm.outgoing,'Assigned goods remain visibly on the source shelf')
 V.assert(s.carriers[1].job.destination==mill,'The first crop delivery prefers the mill')
 local enteredSource,loadedInside=false,false
 for _=1,40 do
  s:update(.1)
  local carrier=s.carriers[1]
  if carrier.phase=='packing' and carrier.timer>Cargo.doorSeconds*.5+.1 then
   enteredSource=true
   V.assert(farm.buffer==3 and not carrier.carrying,'Stock remains on the shelf while the worker walks in')
  end
  if carrier.phase=='packing' and carrier.carrying then
   local _,_,hidden=Cargo.doorPose(carrier,carrier.x,carrier.y)
   loadedInside=loadedInside or hidden
  end
 end
 V.assert(enteredSource and loadedInside,'Pickup changes hands only after the carrier crosses the doorway')
 V.assert(farm.buffer==0 and s.carriers[1].carrying,'Picking up, rather than queueing, removes the stock')
 local loaded=roundtrip(s);V.assert(loaded~=nil,'Actual pickup state is persistent')
 local deliveredInside=false
 for _=1,100 do
  s:update(.1)
  local carrier=s.carriers[1]
  if carrier.phase=='unload' and carrier.handedOff then
   local _,_,hidden=Cargo.doorPose(carrier,carrier.x,carrier.y)
   deliveredInside=deliveredInside or hidden
  end
 end
 V.assert(deliveredInside,'Destination inventory changes after the carrier enters the building')
 V.assert(mill.inputs==3 and s.stock.grain==0,'All three bags reach their preferred destination')
 -- Ranches require repeated real grain feeding, including while saving/reloading.
 local ranch=Sim.new();ranch.started,ranch.skipped=true,true;ranch.stock.food=300
 local b=ranch:addBuilding('ranch',8,8,true);b.workers=1
 tick(ranch,120)
 V.assert(b.timer==0 and (b.feedVisits or 0)==0 and (ranch.produced.livestock or 0)==0,'No grain means no feeding or livestock production')
 ranch.stock.grain=12
 tick(ranch,145)
 V.assert((b.feedVisits or 0)>=3,'Growing pigs are fed several times per cycle')
 V.assert((ranch.produced.livestock or 0)>0 or b.buffer>0,'Fed pigs mature and enter the actual delivery chain')
 V.assert(roundtrip(ranch)~=nil,'Feed duration, growth and stocks survive save/load')
 -- Four places, all occupations can become hungry and visit the same real hall.
 local meal=Sim.new();meal.started,meal.skipped,meal.population=true,true,30;meal.stock.food=200
 local hall=meal:addBuilding('kitchen',8,8,true);hall.mealStock=8
 meal.roads['13:9'],meal.roads['14:9']=true,true;meal.roadCount=2
 local butcher=meal:addBuilding('butcher',14,8,true);butcher.workers=1
 local peak,eaten=0,false
 meal.militia=1;tick(meal,.1)
 for _,a in ipairs(meal.carriers) do a.hunger=95 end
 meal.guards[1].hunger=95
 meal.workers[butcher.id..':1'].hunger=95
 for _=1,500 do
  meal:update(.1);peak=math.max(peak,Meals.occupancy(meal,hall.id))
  local a=meal.workers[butcher.id..':1'];if a.meal and a.meal.phase=='eat' then eaten=true end
  V.assert(Meals.occupancy(meal,hall.id)<=4,'Dining occupancy never exceeds four seats')
 end
 V.assert(peak==4 and eaten,'A hungry specialist queues, sits, eats and returns like an ordinary worker')
 V.assert(roundtrip(meal)~=nil,'Dining queues and specialist identities survive saves')
 -- Food cannot be served twice when a reserved output shipment is still
 -- waiting for its carrier, and recipes preserve their real ingredient types.
 local food=Sim.new();food.started,food.skipped=true,true;food.stock.food=0
 local cook=food:addBuilding('kitchen',8,8,true);cook.workers=1
 food:receiveInput(cook,'flour',1);food:receiveInput(cook,'meat',3)
 tick(food,7)
 V.assert((cook.inputGoods.flour or 0)==0 and (cook.inputGoods.meat or 0)==3,'Cooking consumes the actual delivered flour before meat')
 V.assert(food.produced.food>=4 and cook.mealStock>=4,'Cooking the first meals advances the food tutorial without a warehouse detour')
 tick(food,293)
 local total=food.stock.food+cook.mealStock+cook.buffer+food.mealsServed
 local function transit(job,handedOff)
  if job and job.resource=='food' and not handedOff and (job.inbound or job.pickedUp) then total=total+job.amount end
 end
 for _,job in ipairs(food.jobs) do transit(job,false) end
 for _,a in ipairs(food.carriers) do transit(a.job,a.handedOff) end
 V.assert(total==16,'Four real ingredients produce exactly sixteen meals across pantry, shipments and diners')
 V.assert(roundtrip(food)~=nil,'Mixed ingredient stocks and completed handoffs survive saves')
 -- Save in the middle of a log pickup and compare the complete resource result.
 local wood=Sim.new();wood.started,wood.skipped=true,true;wood.stock.food=200
 local camp=wood:addBuilding('woodcutter',8,8,true);camp.workers=1
 local carrying
 for _=1,1000 do
  wood:update(.1)
  local a=wood.workers[camp.id..':1']
  if a and a.woodPhase=='gather' and a.carrying then carrying=roundtrip(wood);break end
 end
 V.assert(carrying~=nil,'A lumberjack can save while lifting a real felled log')
 if carrying then
  tick(wood,50);tick(carrying,50)
  V.assert(wood.stock.wood==carrying.stock.wood and wood.timber==carrying.timber and wood.buildings[camp.id].buffer==carrying.buildings[camp.id].buffer,'Restoring a pickup neither duplicates nor loses logs')
 end
 print('V7_LIFE_FLOW_CHECKS_COMPLETE')
 V.finish()
end)
