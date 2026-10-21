-- Controlled queue admission boundaries with actual actor identities and
-- Movement walk->queue transitions. Food is a real reserved service handoff.
local Sim=require 'game.Simulation'
local Meals=require 'game.Meals'
local Move=require 'game.Movement'
local Data=require 'game.SaveData'
local function fixture()
 local s=Sim.new('finite',23);s.started=true;s.skipped=true
 for x=13,17 do s.roads[x..':9']=true end;s.roadCount=5
 local hall=s:addBuilding('kitchen',13,8,true);hall.workers=0
 s:addBuilding('barracks',17,8,true);assert(s:train('militia'))
 -- Controlled single-meal inventory is reserved through the normal restock API.
 s.stock.food=1;Meals.restock(s,hall)
 local old,new=s.carriers[1],s.guards[1]
 old.hunger,new.hunger=100,100
 return s,hall,old,new
end
local function arrive(s,a,hall)
 a.x,a.y=hall.x-.1,hall.y+1
 a.meal={target=hall.id,phase='walk',timer=0,paid=false,resumeX=10,resumeY=9}
 assert(Move.route(s,a,hall.x,hall.y+1))
 for _=1,10 do s.elapsed=s.elapsed+.1;Meals.tick(s,a,.1,false,false);if a.meal.phase=='queue'then break end end
 assert(a.meal and a.meal.phase=='queue')
end
local function deliver(s,hall)
 for i,j in ipairs(s.jobs)do if j.b==hall and j.service then table.remove(s.jobs,i);s:completeDelivery(j);return end end
 error('Missing original reserved food service')
end
V.atFrame(8,function()
 local s,hall,old,new=fixture();arrive(s,old,hall)
 for _=1,20 do s.elapsed=s.elapsed+.1;Meals.tick(s,old,.1,false,false)end
 arrive(s,new,hall);deliver(s,hall)
 -- The newcomer deliberately executes first, as workers/guards precede
 -- carriers in the real simulation. Arrival order must still win admission.
 Meals.tick(s,new,.1,false,false);Meals.tick(s,old,.1,false,false)
 V.assert(old.meal.paid and not new.meal.paid and s.mealsServed==1 and hall.mealStock==0,'Earlier arrived carrier receives the single meal despite the later guard updating first')
 local paidPhase=old.meal.phase
 Meals.tick(s,new,.1,false,false);Meals.tick(s,old,.1,false,false)
 V.assert(old.meal.paid and old.meal.phase==paidPhase and s.mealsServed==1,'A paid queue winner keeps its original seat without a second deduction')
 s,hall,old,new=fixture();arrive(s,old,hall)
 for _=1,20 do s.elapsed=s.elapsed+.1;Meals.tick(s,old,.1,false,false)end
 arrive(s,new,hall)
 local restored=Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000,1,true))),'finite')
 V.assert(restored~=nil,'Both real waiting diners and their reserved future meal survive save/load')
 s=restored;hall=s.buildings[2];old=s.carriers[1];new=s.guards[1];deliver(s,hall)
 Meals.tick(s,new,.1,false,false);Meals.tick(s,old,.1,false,false)
 V.assert(old.meal.paid and not new.meal.paid and s.mealsServed==1,'Queue arrival priority survives a real JSON roundtrip and remains independent of actor update order')
 s,hall,old,new=fixture();arrive(s,old,hall)
 for _=1,20 do s.elapsed=s.elapsed+.1;Meals.tick(s,old,.1,false,false)end
 arrive(s,new,hall)
 old.meal.queueArrivedAt=nil;new.meal.queueArrivedAt=nil -- old saved queues have waitTime only
 restored=Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000,1,true))),'finite')
 s=restored;hall=s.buildings[2];old=s.carriers[1];new=s.guards[1];deliver(s,hall)
 Meals.tick(s,new,.1,false,false);Meals.tick(s,old,.1,false,false)
 V.assert(old.meal.paid and not new.meal.paid and s.mealsServed==1,'Legacy queues without the new arrival field retain their actual waited-time precedence on restore')
 -- Both actual walk completions occur at the same simulation timestamp.
 -- The declared stable actor identity tie-break must ignore call order.
 for _,reverse in ipairs({false,true})do
  s,hall,old,new=fixture();s.elapsed=10
  for _,a in ipairs({old,new})do
   a.x,a.y=hall.x-.1,hall.y+1
   a.meal={target=hall.id,phase='walk',timer=0,paid=false,resumeX=10,resumeY=9}
   assert(Move.route(s,a,hall.x,hall.y+1))
  end
  local first,second=reverse and new or old,reverse and old or new
  Meals.tick(s,first,.2,false,false);Meals.tick(s,second,.2,false,false)
  V.assert(old.meal.phase=='queue'and new.meal.phase=='queue','Same-frame tie fixture uses two actual walk completions')
  deliver(s,hall);Meals.tick(s,first,.1,false,false);Meals.tick(s,second,.1,false,false)
  V.assert(old.meal.paid and not new.meal.paid and s.mealsServed==1,'Same-frame stable identity tie keeps one exact winner under admission order reverse='..tostring(reverse))
 end
 s,hall,old,new=fixture();arrive(s,old,hall)
 for _=1,20 do s.elapsed=s.elapsed+.1;Meals.tick(s,old,.1,false,false)end
 arrive(s,new,hall);old.meal=false;deliver(s,hall);Meals.tick(s,new,.1,false,false)
 V.assert(new.meal.paid and s.mealsServed==1,'An earlier actor who leaves the queue releases admission priority immediately')
 s,hall,old,new=fixture();arrive(s,old,hall)
 local other=s:addBuilding('kitchen',7,8,true);s.roads['7:9']=true;s.roadCount=s.roadCount+1;other.workers=0;other.mealStock=1
 arrive(s,new,other);Meals.tick(s,new,.1,false,false)
 V.assert(new.meal.paid and new.meal.target==other.id and not old.meal.paid,'An older waiting diner at a different hall does not block this hall admission')
 V.finish()
end)
