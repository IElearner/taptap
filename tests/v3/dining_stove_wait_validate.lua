-- Controlled short-wait boundaries. Actual Production timer, ordinary
-- recipe/yield and real walk->queue transition are used; no period changes.
local Sim=require 'game.Simulation'
local Meals=require 'game.Meals'
local Move=require 'game.Movement'
local Data=require 'game.SaveData'
local E=require 'game.Economy'
local function setup(workerFirst)
 local s=Sim.new('finite',23);s.started=true;s.skipped=true;s.stock.food=0
 for x=7,17 do s.roads[x..':9']=true end;s.roadCount=11
 local employer
 if workerFirst then employer=s:addBuilding('mason',17,8,true);employer.workers=1 end
 local b=s:addBuilding('kitchen',13,8,true);b.workers=1;b.inputs=1;b.inputGoods={bread=1}
 local far=s:addBuilding('kitchen',7,8,true);far.workers=0
 for _=1,40 do s:update(.1);if b.timer>=1 then break end end
 local a=employer and s.workers[employer.id..':1']or s.carriers[1]
 a.hunger=100;a.x,a.y=12.9,9
 a.meal={target=b.id,phase='walk',timer=0,paid=false,resumeX=10,resumeY=9};Move.route(s,a,13,9)
 Meals.tick(s,a,.2,false,false)
 return s,b,far,a,employer
end
V.atFrame(8,function()
 for _,workerFirst in ipairs({false,true})do
  local s,b,far,a=setup(workerFirst);local timer=b.timer;s:update(.1)
  V.assert(b.timer>timer and a.meal and a.meal.phase=='queue'and not a.meal.paid,'An empty-counter arrival stays queued while a real chef advances its cooking timer; worker-before-kitchen='..tostring(workerFirst))
  local returned=false
  for _=1,100 do s:update(.1);if a.meal and a.meal.phase=='return'then returned=true end end
  V.assert(not returned and a.meal and a.meal.paid and s.mealsServed==1 and s.produced.food==4 and b.inputs==0,'Same real batch serves the waiting diner once without an empty return or extra ingredients')
 end
 for _,kind in ipairs({'no-input','stopped','disconnected','no-chef','chef-door-transition','reserved-full-output'})do
  local s,b,far,a=setup(false);s:update(.1)
  V.assert(a.meal and a.meal.phase=='queue','Valid cooking wait began before losing eligibility: '..kind)
  if kind=='no-input'then b.inputs=0;b.inputGoods={}
  elseif kind=='stopped'then assert(s:setWorking(b,false))
  elseif kind=='disconnected'then s.roads['13:9']=nil;s.roadCount=s.roadCount+1
  elseif kind=='no-chef'then assert(s:staff(b,-1))
  elseif kind=='chef-door-transition'then s.workers[b.id..':1'].workPresence=1
  else E.add(b,'food',6);b.outgoing=true;s.jobs={{b=b,inbound=false,resource='food',amount=6}}end
  s:update(.1)
  V.assert(not a.meal or a.meal.phase~='queue','Loss of actual local cooking eligibility ends special empty-counter waiting immediately: '..kind)
 end
 local s,b,far,a=setup(false);s:update(.1)
 local accrued=a.meal.stoveWaitSeconds
 V.assert(accrued and accrued>0 and accrued<=.100001,'Actual empty-stove waiting accumulates simulation time without prepayment')
 local snapshot=Data.capture(s,1000,1,true)
 s=Data.restore(cjson.decode(cjson.encode(snapshot)),'finite');b=s.buildings[b.id];a=s.carriers[1]
 V.assert(a.meal.stoveWaitSeconds==accrued and not a.meal.paid,'Mid-wait save/load retains the precise accumulated short-wait time without charging a meal')
 s:update(.1)
 V.assert(a.meal.phase=='queue'and a.meal.stoveWaitSeconds>accrued,'Restored actual cooking continues waiting from the previous age instead of restarting it')
 -- Explicit near-limit fixture tests the timeout boundary without changing
 -- production period or pretending thirty seconds were already simulated.
 a.meal.stoveWaitSeconds=29.8
 local captured=Data.capture(s,1000,2,true)
 s=Data.restore(cjson.decode(cjson.encode(captured)),'finite');b=s.buildings[b.id];a=s.carriers[1]
 s:update(.1)
 V.assert(a.meal.phase=='queue'and a.meal.stoveWaitSeconds>=29.89,'Saved near-limit queue preserves 29.8 elapsed waiting seconds')
 s:update(.1)
 V.assert(a.meal.phase=='return'and not a.meal.paid and s.mealsServed==0 and b.inputs==1 and b.timer>0,'Thirty cumulative seconds ends special waiting despite the still-valid real stove, without free food or payment')
 s,b,far,a=setup(false);s:update(.1)
 s.stock.food=1;Meals.restock(s,b);local service=s.jobs[#s.jobs]
 assert(service and service.service);assert(s:setWorking(b,false));s:update(.1)
 local retained=false
 for _,j in ipairs(s.jobs)do if j==service then retained=true end end
 for _,c in ipairs(s.carriers)do if c.job==service then retained=true end end
 V.assert(a.meal.phase~='queue'and retained and b.mealIncoming and s.stock.food==0,'An already-started stove wait exits on stop while its separately reserved incoming service meal stays intact')
 s,b,far,a=setup(false);b.inputs=0;b.inputGoods={};s.stock.food=1;Meals.restock(s,b);s:update(.1)
 V.assert(a.meal.phase=='queue'and not a.meal.stoveWaitSeconds and b.mealIncoming,'A legacy service-only queue that never began a stove wait retains its original waiting behavior')
 V.finish()
end)
