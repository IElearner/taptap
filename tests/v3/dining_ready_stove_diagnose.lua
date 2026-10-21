-- Ten-second controlled observation, not a proposed-wait-policy acceptance.
-- A real staffed kitchen advances its timer; one actual carrier arrives empty.
local Sim=require 'game.Simulation'
local Meals=require 'game.Meals'
local Move=require 'game.Movement'
V.atFrame(8,function()
 local s=Sim.new('finite',23);s.started=true;s.skipped=true;s.stock.food=0;s.roads['13:9']=true;s.roadCount=1
 local b=s:addBuilding('kitchen',13,8,true);b.workers=1;b.inputs=1;b.inputGoods={bread=1}
 for _=1,40 do s:update(.1);if b.timer>=1 then break end end
 local a=s.carriers[1];a.hunger=100;a.x,a.y=12.9,9
 a.meal={target=b.id,phase='walk',timer=0,paid=false,resumeX=8,resumeY=9};Move.route(s,a,13,9)
 Meals.tick(s,a,.2,false,false)
 local before={timer=b.timer,inputs=b.inputs,pantry=b.mealStock,rate=b.workRate,active=b.activeWorkers,phase=a.meal.phase}
 s:update(.1)
 local after={timer=b.timer,inputs=b.inputs,pantry=b.mealStock,rate=b.workRate,active=b.activeWorkers,phase=a.meal and a.meal.phase}
 V.assert(before.phase=='queue'and before.inputs==1 and before.pantry==0 and before.rate>0 and after.timer>before.timer,'Observed empty-counter arrival occurs while the actual assigned chef advances the real cooking timer')
 local samples={before,after}
 for _=1,100 do s:update(.1);samples[#samples+1]={elapsed=s.elapsed,timer=b.timer,inputs=b.inputs,pantry=b.mealStock,rate=b.workRate,active=b.activeWorkers,phase=a.meal and a.meal.phase,paid=a.meal and a.meal.paid,x=a.x,y=a.y}end
 V.assert(s.produced.food==4 and b.inputs==0,'The same unchanged ingredient completes its actual six-second batch during the next ten simulated seconds')
 print('V3_READY_STOVE_EMPTY_RETURN',cjson.encode({earlyReturn=after.phase=='return',before=before,after=after,samples=samples,diagnosticOnly=true}))
 V.finish()
end)
