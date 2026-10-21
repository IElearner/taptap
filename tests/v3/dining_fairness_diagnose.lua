-- Diagnostic replay from immutable earned hunger failure. No new stock, actors,
-- staff, orders, terrain or hunger reset; phase/arrival/payment trace only.
local Sim=require 'game.Simulation'
local Data=require 'game.SaveData'
local Meals=require 'game.Meals'
local run='dining-fairness'
for _,arg in ipairs(GetArguments())do run=arg:match('^-pixelqa%-run=([%w_-]+)$')or run end
local f=File('tests/v3/fixtures/earned242_after_failed_endurance.json',FILE_READ)
local s=Data.restore(cjson.decode(f:ReadString()),'finite');f:Close()
local start=s.elapsed
local events,summaries={},{}
local function actors()
 local out={}
 for i,a in ipairs(s.carriers)do out['carrier:'..i]=a end
 for k,a in pairs(s.workers)do out['worker:'..k]=a end
 for i,a in ipairs(s.guards)do out['guard:'..i]=a end
 for i,a in ipairs(s.builders)do out['builder:'..i]=a end
 return out
end
local function status(a)
 local m=a.meal
 return {phase=m and m.phase or false,target=m and m.target,paid=m and m.paid or false,x=a.x,y=a.y,hunger=a.hunger,job=a.job and {resource=a.job.resource,amount=a.job.amount,inbound=a.job.inbound,service=a.job.service,b=a.job.b and a.job.b.id}}
end
local task=coroutine.create(function()
 for step=1,9000 do
  local previous={};for key,a in pairs(actors())do previous[key]=status(a)end
  local pantry={};for _,b in ipairs(s.buildings)do if b.kind=='kitchen'then pantry[b.id]=b.mealStock or 0 end end
  s:update(.1)
  for key,a in pairs(actors())do
   local before,after=previous[key],status(a)
   if before and (before.phase~=after.phase or before.target~=after.target or before.paid~=after.paid)then
    local hall=after.target and s.buildings[after.target]
    local waiting=0;for _,other in pairs(actors())do if hall and other.meal and other.meal.target==hall.id and not other.meal.paid then waiting=waiting+1 end end
    events[#events+1]={t=s.elapsed-start,actor=key,before=before,after=after,hall=hall and {id=hall.id,pantryBefore=pantry[hall.id],pantryAfter=hall.mealStock,waiting=waiting,buffer=hall.buffer,inputs=hall.inputs,incoming=hall.incoming,mealIncoming=hall.mealIncoming}}
    local r=summaries[key]or {paid=0,eaten=0,emptyReturn=0,targetChanges=0};summaries[key]=r
    if not before.paid and after.paid then r.paid=r.paid+1 end
    if before.phase=='eat'and after.phase=='exit'then r.eaten=r.eaten+1 end
    if before.phase=='queue'and after.phase=='return'and not after.paid then r.emptyReturn=r.emptyReturn+1 end
    if before.target and after.target~=before.target then r.targetChanges=r.targetChanges+1 end
   end
  end
  if step%100==0 then coroutine.yield()end
 end
 local payload={sourceFixture='earned242_after_failed_endurance.json',seconds=s.elapsed-start,events=events,summaries=summaries,foodProduced=s.produced.food-987,mealsAccepted=s.mealsServed-1007,diagnosticOnly=true}
 local out=File('tests/v3/evidence/'..run..'-trace.json',FILE_WRITE);out:WriteString(cjson.encode(payload));out:Close()
 print('V3_DINING_FAIRNESS_TRACE',cjson.encode({seconds=payload.seconds,summaries=summaries,eventCount=#events,foodProduced=payload.foodProduced,mealsAccepted=payload.mealsAccepted}))
 V.assert(#events>0 and s.population==34 and #s.carriers==4,'Diagnostic preserves original real population/transport while recording actual arrival, payment and empty-return events; not a fairness acceptance pass')
end)
for frame=8,150 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end
 local ok,err=coroutine.resume(task)
 if not ok then V.assert(false,tostring(err));V.finish()
 elseif coroutine.status(task)=='dead'then V.finish()end
end)end
