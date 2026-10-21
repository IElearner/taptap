local Sim=require 'game.Simulation'
local Meals=require 'game.Meals'
local function fresh()
 local s=Sim.new('infinite');s.started,s.skipped=true,true;s.stock.food=0;s.foodClock=14.95
 local hall=s:addBuilding('kitchen',8,8,true);hall.mealStock=0;hall.workers=0
 for _,a in ipairs(s.carriers) do a.hunger=0;a.energy=100 end
 return s,hall
end
local function health(s,expected,label)
 s:update(.1)
 V.assert(s.health==expected,label..' health='..s.health)
end
V.atFrame(8,function()
 local s,b=fresh();b.mealStock=2
 health(s,100,'Connected pantry food prevents false starvation with empty warehouse')
 s,b=fresh();b.mealStock=2;s.roads['8:9']=nil
 health(s,96,'An unreachable pantry cannot prevent real starvation')
 s,b=fresh();s.stock.food=2;Meals.restock(s,b)
 V.assert(s.stock.food==0 and #s.jobs==1,'Restock reserves the actual warehouse food into a service job')
 health(s,100,'Prepaid queued service food remains available while awaiting a carrier')
 s,b=fresh();local a=s.carriers[1]
 a.job={b=b,inbound=true,service=true,resource='food',amount=2};a.carrying=true
 a.phase='walking';a.path={{x=10,y=9},{x=9,y=9},{x=8,y=9}};a.index=1
 health(s,100,'A carrier holding the prepaid meal shipment prevents false starvation')
 s,b=fresh();a=s.carriers[1]
 a.job={b=b,inbound=false,resource='food',amount=2,pickedUp=true};a.carrying=true
 a.phase='walking';a.path={{x=8,y=9},{x=9,y=9},{x=10,y=9}};a.index=1
 health(s,100,'Picked up cooked food en route to the warehouse remains real food')
 s,b=fresh();b.mealStock=2;a=s.carriers[1]
 a.job={b=b,inbound=true,service=true,resource='food',amount=2};a.handedOff=true
 V.assert(Meals.availableFood(s)==2,'A completed handoff is counted once in the pantry, not twice')
 b.mealStock=0
 health(s,96,'An exhausted completed handoff does not hide true starvation')
 s,b=fresh()
 health(s,96,'No warehouse, pantry, or shipment food applies one four-health starvation tick')
 s.foodClock=14.95;health(s,92,'A second truly empty interval applies exactly one further tick')
 V.finish()
end)
