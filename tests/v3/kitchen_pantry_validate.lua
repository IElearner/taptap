-- Already cooked shelf-food fixtures. No recipe output is granted after setup;
-- exact reservation, pantry, cargo, delivery and paid-meal balances are tested.
local Sim=require 'game.Simulation'
local P=require 'game.Production'
local E=require 'game.Economy'
local Data=require 'game.SaveData'
local Meals=require 'game.Meals'
local function setup(n)
 local s=Sim.new('finite',23);s.started=true;s.skipped=true;s.stock.food=0
 s.roads['13:9']=true;s.roadCount=1
 local b=s:addBuilding('kitchen',13,8,true);b.workers=0;b.activeWorkers=0
 E.add(b,'food',n)
 return s,b
end
V.atFrame(8,function()
 local s,b=setup(6);P.update(s,0)
 V.assert(b.mealStock==6 and b.buffer==0 and (b.outputGoods.food or 0)==0,'Six unreserved existing cooked meals move from the local shelf into its empty pantry')
 V.assert(s.produced.food==6 and s.stock.food==0,'Local serving records existing food delivery exactly once without creating warehouse stock')
 P.update(s,0)
 V.assert(b.mealStock==6 and b.buffer==0 and s.produced.food==6,'Repeated updates do not duplicate old shelf meals or delivery counters')
 s,b=setup(6);s:enqueue(b,false,'food');P.update(s,0)
 V.assert(#s.jobs==1 and s.jobs[1].amount==4 and b.buffer==4 and b.mealStock==2,'Queued four-meal outbound reservation stays intact; only two unreserved meals enter the pantry')
 local loaded=Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000,1,true))),'finite');s=loaded;b=s.buildings[2];P.update(s,0)
 V.assert(b.buffer==4 and b.mealStock==2 and s.jobs[1].amount==4 and s.produced.food==2,'Queued reservation and local redistribution survive restore without double serving')
 local c=s.carriers[1];s:updateCarrier(c,.1,false);P.update(s,0)
 V.assert(c.job and not c.job.pickedUp and c.job.amount==4 and b.buffer==4 and b.mealStock==2,'Assigned but uncollected four-meal job retains its entire physical shelf reservation')
 local sawLoaded=false
 for _=1,1200 do
  s:updateCarrier(c,.1,false);s.elapsed=s.elapsed+.1
  if c.carrying and c.job and c.job.pickedUp and not c.handedOff then
   sawLoaded=true;P.update(s,0)
   V.assert(b.buffer==0 and b.mealStock==2 and c.job.amount==4,'Already picked-up cargo stays with the carrier and cannot be served again')
   local again=Data.restore(cjson.decode(cjson.encode(Data.capture(s,1200,2,true))),'finite');s=again;b=s.buildings[2];c=s.carriers[1]
   break
  end
 end
 V.assert(sawLoaded,'Actual old cooked-food carrier reaches its real loaded movement phase')
 for _=1,1200 do if not c.job then break end;s:updateCarrier(c,.1,false);s.elapsed=s.elapsed+.1 end
 V.assert(not c.job and b.mealStock==2 and b.buffer==0 and s.stock.food==4 and s.produced.food==6,'Actual reserved cargo arrives once while local two meals remain distinct')
 s,b=setup(6);b.mealStock=5;b.mealIncoming=true;s.stock.food=0
 s.jobs={{b=b,inbound=true,resource='food',amount=2,service=true}}
 P.update(s,0)
 V.assert(b.mealStock==6 and b.buffer==5,'Two already reserved service meals leave exactly one local pantry slot')
 c=s.carriers[1]
 for _=1,1200 do s:updateCarrier(c,.1,false);s.elapsed=s.elapsed+.1;if not c.job and not b.mealIncoming then break end end
 V.assert(b.mealStock==8 and not b.mealIncoming,'Actual incoming service delivery respects pantry capacity after local shelf refill')
 s,b=setup(1);P.update(s,0)
 local a=s.carriers[2];a.x,a.y=13,9;a.hunger=100
 a.meal={target=b.id,phase='queue',waitTime=0,timer=0,paid=false,resumeX=10,resumeY=9}
 Meals.tick(s,a,.1,false,false)
 V.assert(b.mealStock==0 and a.meal.paid and s.mealsServed==1,'Real diner pays the redistributed existing meal once at acceptance')
 local paid=Data.restore(cjson.decode(cjson.encode(Data.capture(s,1400,3,true))),'finite');s=paid;b=s.buildings[2];a=s.carriers[2]
 for _=1,200 do Meals.tick(s,a,.1,false,false);P.update(s,0)end
 V.assert(b.mealStock==0 and b.buffer==0 and s.mealsServed==1 and s.produced.food==1,'Paid meal and restored shelf pantry never charge or produce a second copy')
 V.finish()
end)
