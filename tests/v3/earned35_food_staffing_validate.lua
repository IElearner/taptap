-- Declared normal C configuration: one existing bowmaker -> second baker; third farm resumed.
-- Instrumentation-only replay from the actual successful warmup snapshot.
-- Resets only the external consumption counters; no simulation field is changed.
-- Separate player-operated configuration; not the unchanged-role baseline.
-- staff deletes the two donor actors and creates new chef actors with normal defaults.
-- No manual hunger resets; new identities must actually eat/return before a new 30min window.
-- Fresh normal-starter 35-entity benchmark: six actual carriers, twenty-five jobs.
-- Sustainable-combination comparison: retain two farms, mill, bakery, ranch, butcher and two kitchens.
-- Only woodcutter, sawmill, fishery and the third farm stop; every assigned role stays.
-- Industrial isolation disables tutorial relief explicitly; objective API progress is not a complete UI walkthrough.
-- Existing hunger is retained; actual eating/return must recover before a fresh 30min window.
-- Normal online new-game progression, using only the game's real starter stock.
-- Fixed 35-entity seed-23 benchmark, not a typical required player layout.
-- Unlike the old village fixture, road work never uses offline=true.
-- Intro tutorial relief is counted; the industrial branch explicitly disables it.
local Sim=require 'game.Simulation'
local Data=require 'game.SaveData'
local Store=require 'game.PixelSaveStore'
local D=require 'game.Definitions'
local E=require 'game.Economy'
local pf=File('tests/v3/fixtures/fixed_v3_seed23_35.json',FILE_READ)
local fixedPlan=cjson.decode(pf:ReadString());pf:Close()
local fixedRoads={};for _,xy in ipairs(fixedPlan.roads)do fixedRoads[xy[1]..':'..xy[2]]=true end
local run='earned35-two-chefs'
for _,arg in ipairs(GetArguments())do run=arg:match('^-pixelqa%-run=([%w_-]+)$') or run end
local activeSim
local ticks=0
local mealAudit=nil
local auditStart=0
local pantryBlocks={}
local consumption={}
local productionDuty={}
local function observeConsumption(s)
 -- Transparent observation: delegate exactly once to the original production API.
 s.consumeInput=function(self,b)
  local before={};for r,n in pairs(b.inputGoods or {})do before[r]=n end
  Sim.consumeInput(self,b)
  local row=consumption[b.id] or {kind=b.kind,batches=0,inputs={}};consumption[b.id]=row
  row.batches=row.batches+1
  for r,n in pairs(before)do local used=n-(b.inputGoods[r] or 0);if used>0 then row.inputs[r]=(row.inputs[r] or 0)+used end end
 end
end
local function chainState(s)
 local result={elapsed=s.elapsed,stock={},produced={},buildings={},consumed=cjson.decode(cjson.encode(consumption)),meals=s.mealsServed}
 for _,r in ipairs({'grain','flour','bread','meat','fish','food'})do result.stock[r]=s.stock[r] or 0;result.produced[r]=s.produced[r] or 0 end
 for _,b in ipairs(s.buildings)do if b.kind=='farm' or b.kind=='mill' or b.kind=='bakery' or b.kind=='kitchen'then
  result.buildings[#result.buildings+1]={id=b.id,kind=b.kind,stopped=b.stopped,workers=b.workers,inputs=b.inputGoods,outputs=b.outputGoods,buffer=b.buffer,pantry=b.mealStock,timer=b.timer}
 end end
 return cjson.decode(cjson.encode(result))
end
local auditPhase="recovery"
local orderPolicies={}
local tutorialRelief=0
local introRelief=0
local function actors(s)
 local result={}
 for i,a in ipairs(s.carriers)do result['carrier:'..i]=a end
 for k,a in pairs(s.workers)do result['worker:'..k]=a end
 for i,a in ipairs(s.guards)do result['guard:'..i]=a end
 for i,a in ipairs(s.builders)do result['builder:'..i]=a end
 return result
end
local function tick(s)
 local previous={}
 if mealAudit then for key,a in pairs(actors(s))do previous[key]={phase=a.meal and a.meal.phase or false,hunger=a.hunger or 0} end end
 if not s.skipped and s.mode=='finite' and s.foodClock+.1>=15 and s.stock.food<8 then tutorialRelief=tutorialRelief+8-s.stock.food end
 for _,b in ipairs(s.buildings)do
  if b.kind=='mill' or b.kind=='bakery' or b.kind=='ranch' or b.kind=='farm' or b.kind=='butcher' or b.kind=='kitchen'then
   local row=productionDuty[b.id] or {kind=b.kind,seconds=0,noInputSeconds=0,stoppedSeconds=0,activeWorkerSeconds=0,workRateSeconds=0,outputBlockedSeconds=0};productionDuty[b.id]=row
   row.seconds=row.seconds+.1
   if b.stopped then row.stoppedSeconds=row.stoppedSeconds+.1 end
   if not E.hasInputs(b)then row.noInputSeconds=row.noInputSeconds+.1 end
   if not E.canProduce(b)then row.outputBlockedSeconds=row.outputBlockedSeconds+.1 end
   row.activeWorkerSeconds=row.activeWorkerSeconds+(b.activeWorkers or 0)*.1
   row.workRateSeconds=row.workRateSeconds+(b.workRate or 0)*.1
  end
 end
 s:update(.1);ticks=ticks+1
 for id,policy in pairs(orderPolicies)do
  local b=s.buildings[id]
  if b and not policy.done and (s.produced[policy.resource] or 0)>=policy.target then
   if policy.thenIron then
    s:setRecipe(b,1);policy.resource,policy.target,policy.thenIron='iron',4,false
   else s:setWorking(b,false);policy.done=true end
   print('V3_REAL_ORDER_CONTROL',s.elapsed,b.kind,policy.resource,policy.target,policy.done)
  end
 end
 if mealAudit then
  for key,a in pairs(actors(s))do
   local record=mealAudit[key] or {meals=0,returned=0,maxHunger=0,activeSeconds=0,idleSeconds=0};mealAudit[key]=record
   local allocated=not key:find('builder:',1,true) or a.active or a.meal or previous[key] and previous[key].hunger~=(a.hunger or 0)
   if allocated then record.activeSeconds=record.activeSeconds+.1;record.maxHunger=math.max(record.maxHunger,a.hunger or 0)
    if (a.hunger or 0)>=300 then
     record.severeSeconds=(record.severeSeconds or 0)+.1
     if not record.firstSevere then
      local jobs={};for _,j in ipairs(s.jobs)do if j.b and j.b.kind=='mill' and j.inbound then jobs[#jobs+1]={amount=j.amount,resource=j.resource,location='queue'}end end
      for i,c in ipairs(s.carriers)do local j=c.job;if j and j.b and j.b.kind=='mill' and j.inbound then jobs[#jobs+1]={amount=j.amount,resource=j.resource,carrier=i,phase=c.phase}end end
      record.firstSevere={time=s.elapsed-auditStart,phase=a.meal and a.meal.phase or false,hunger=a.hunger,millJobs=jobs}
     end
    end
   else record.idleSeconds=record.idleSeconds+.1 end
   if previous[key] and previous[key].phase=='eat' and a.meal and a.meal.phase=='exit'then record.meals=record.meals+1;record.firstMeal=record.firstMeal or s.elapsed-auditStart;record.lastMeal=s.elapsed-auditStart end
   if previous[key] and previous[key].phase and not a.meal then record.returned=record.returned+1;record.firstReturn=record.firstReturn or s.elapsed-auditStart end
  end
 end
 if mealAudit then
  local halls={}
  for _,b in ipairs(s.buildings)do if b.kind=='kitchen'then
   local blocked=(b.mealStock or 0)==0 and b.buffer>0
   local t=pantryBlocks[b.id]or {seconds=0,longest=0,current=0};pantryBlocks[b.id]=t
   t.current=blocked and t.current+.1 or 0;if blocked then t.seconds=t.seconds+.1;t.longest=math.max(t.longest,t.current)end
   if ticks%900==0 then halls[#halls+1]={id=b.id,inputs=b.inputs,inputGoods=b.inputGoods,pantry=b.mealStock,buffer=b.buffer,outgoing=b.outgoing,incoming=b.incoming,workRate=b.workRate,active=b.activeWorkers,timer=b.timer,block=t.current}end
  end end
  if ticks%900==0 then
   local jobs={};for i,j in ipairs(s.jobs)do jobs[#jobs+1]={order=i,resource=j.resource,amount=j.amount,source=j.inbound and 'warehouse' or j.b and j.b.kind,destination=j.destination and j.destination.id or j.inbound and j.b.id}end
   print('V3_KITCHEN_90S',cjson.encode({phase=auditPhase,elapsed=s.elapsed-auditStart,halls=halls,jobs=jobs,stockFood=s.stock.food,produced=s.produced.food,served=s.mealsServed}))
  end
 end
 if ticks%100==0 then coroutine.yield() end
end
local function untilTrue(s,predicate,seconds)
    for _=1,seconds*10 do if predicate() then return true end;tick(s) end
    return predicate()
end
local task=coroutine.create(function()
 local f=File('tests/v3/fixtures/earned_cad35_four_chefs_recovered.json',FILE_READ);local raw=cjson.decode(f:ReadString());f:Close()
 local s,why=Data.restore(raw,'finite');activeSim=s
 V.assert(s and #s.buildings==35 and #s.carriers==6 and s.population==34,'Normal staffing trial restores exact earned four-chef village: '..tostring(why))
 local donor,bakery,thirdFarm
 for _,b in ipairs(s.buildings)do
  if b.kind=='woodweapons'then donor=b elseif b.kind=='bakery'then bakery=b elseif b.kind=='farm' and b.stopped then thirdFarm=b end
 end
 V.assert(donor and donor.workers==1 and bakery and bakery.workers==1 and thirdFarm,'Earned village contains actual completed bowmaker donor, single baker and stopped third farm')
 local initial=Data.capture(s,1000+s.elapsed,1,true)
 s:setWorking(donor,false)
 V.assert(s:setWorking(thirdFarm,true) and not thirdFarm.stopped,'Normal operation resumes the existing third farm without adding population or material')
 local accepted,transfer=false,nil
 for attempt=1,6000 do
  local oldActor=s.workers[donor.id..':1'];local before=Data.capture(s,1000+s.elapsed,1,true)
  if s:staff(donor,-1)then
   local same=s.population==before.world.population
   for _,r in ipairs(D.goods)do same=same and s.stock[r]==before.world.stock[r] and (s.produced[r]or 0)==(before.world.produced[r]or 0)end
   V.assert(same and not oldActor.carrying and not oldActor.meal,'Safe real bowmaker release does not discard paid meals/cargo or alter resources')
   transfer={source=donor.id..':1',oldHunger=oldActor.hunger,oldEnergy=oldActor.energy,time=s.elapsed,stock=before.world.stock,produced=before.world.produced}
   accepted=true;break
  end
  tick(s)
 end
 V.assert(accepted,'Actual donor safely finishes existing work/meal before release')
 if not accepted then error('Donor not safely releasable within declared600s')end
 local before=Data.capture(s,1000+s.elapsed,1,true)
 local ok,reason=s:staff(bakery,1)
 local same=s.population==before.world.population
 for _,r in ipairs(D.goods)do same=same and s.stock[r]==before.world.stock[r] and (s.produced[r]or 0)==(before.world.produced[r]or 0)end
 V.assert(ok and same and bakery.workers==2,'Existing resident becomes second baker without grants: '..tostring(reason))
 tick(s)
 local newActor=s.workers[bakery.id..':2'];transfer.destination=bakery.id..':2';transfer.newHunger=newActor and newActor.hunger;transfer.newEnergy=newActor and newActor.energy
 V.assert(newActor~=nil,'New baker normal default actor state is recorded, not described as preserving donor hunger')
 local total=0;for _,b in ipairs(s.buildings)do total=total+b.workers end
 V.assert(total==25 and #s.carriers==6 and #s.guards==3 and s.population==34 and s:availableWorkers()==0,'Configuration retains25 workers+6carriers+3guards and34population exactly')
 local tf=File('tests/v3/evidence/'..run..'-transfers.json',FILE_WRITE);tf:WriteString(cjson.encode({transfer=transfer,initial=initial,after=Data.capture(s,1000+s.elapsed,1,true)}));tf:Close()
 observeConsumption(s)
 local operationStart=chainState(s)
    -- Every allocated carrier/worker/guard with zero allocated idle-resident proxies
    -- must recover by actual meals, with inherited hunger untouched.
    auditStart=s.elapsed;mealAudit={}
    local recoveryStart=s.elapsed
    local recovered=untilTrue(s,function()
     for key,a in pairs(actors(s))do
      local required=not key:find('builder:',1,true)
      local rec=mealAudit[key]
      if required and (not rec or rec.meals<1 or rec.returned<1 or (a.hunger or 0)>=300)then return false end
     end
     return true
    end,1800)
    local recoveryReport={elapsed=s.elapsed-recoveryStart,recovered=recovered,stock=s.stock,roles=mealAudit,pantryBlocks=pantryBlocks,operationStart=operationStart,chainEnd=chainState(s)}
    print('V3_REAL_RECOVERY',cjson.encode(recoveryReport))
    local af=File('tests/v3/evidence/'..run..'-recovery-audit.json',FILE_WRITE);af:WriteString(cjson.encode(recoveryReport));af:Close()
    local rf=File('tests/v3/evidence/'..run..'-recovery-state.json',FILE_WRITE);rf:WriteString(cjson.encode(Data.capture(s,1000+s.elapsed,1,true)));rf:Close()
    V.assert(recovered,'All allocated roles recover inherited hunger by actual eating and return, with no reset or resource gifts')
    if not recovered then error('Real food recovery failed; retained recovery-state and per-role first meal/return evidence')end
    local beforeMeals=s.mealsServed;local beforeFood=s.produced.food;local steadyChainStart=chainState(s);productionDuty={}
    print('V3_ENDURANCE_START',s.elapsed,s.population,s:availableWorkers(),cjson.encode(s.workers),cjson.encode(s.builders),cjson.encode(s.carriers),cjson.encode(s.guards))
    mealAudit={};auditStart=s.elapsed;auditPhase="steady30min";pantryBlocks={}
    for checkpoint=1,6 do
      for step=1,3000 do
       tick(s)
       if step%900==0 then
        local census={population=s.population,free=s:availableWorkers(),carriers=#s.carriers,guards=#s.guards,workers=0,buildersActive=0,buildersMeal=0,buildersIdle=0,stock=s.stock}
        for _ in pairs(s.workers)do census.workers=census.workers+1 end
        for _,a in ipairs(s.builders)do if a.active then census.buildersActive=census.buildersActive+1 elseif a.meal then census.buildersMeal=census.buildersMeal+1 else census.buildersIdle=census.buildersIdle+1 end end
        print('V3_90SECOND_CENSUS',s.elapsed,cjson.encode(census))
       end
      end
      local snapshot=Data.capture(s,1000+s.elapsed,checkpoint,true)
      local loaded,why=Data.restore(cjson.decode(cjson.encode(snapshot)),'finite')
      V.assert(loaded~=nil,'Full 25-industry five-minute checkpoint restores: '..tostring(why))
      if loaded then s=loaded;activeSim=s;observeConsumption(s)end
      for r,n in pairs(s.stock)do V.assert(n>=0,'Full industry stock stays nonnegative: '..r)end
      V.assert(s:availableWorkers()>=0,'Full industry does not overbook residents')
      print('V3_ENDURANCE',checkpoint,s.elapsed,s.mealsServed,cjson.encode(s.stock))
    end
    V.assert(s.mealsServed>beforeMeals+60 and s.produced.food>beforeFood,'Village with 34 housing capacity keeps producing and serving real food for thirty minutes')
    print('V3_30MIN_FOOD',s.produced.food-beforeFood,s.mealsServed-beforeMeals,s.stock.food,tutorialRelief-introRelief)
    local represented=0
    for key,record in pairs(mealAudit)do
     represented=represented+1
     if not key:find('builder:',1,true) or record.activeSeconds>900 then
      V.assert(record.meals>=4 and record.returned>=4,'Every continuously allocated role eats and returns during sustained operation: '..key)
     end
     V.assert(record.maxHunger<300,'No actual persistent role remains severely hungry during sustained operation: '..key)
    end
    print('V3_ACTUAL_MEAL_AUDIT',s.population,represented,cjson.encode(mealAudit))
    local af=File('tests/v3/evidence/'..run..'-steady-audit.json',FILE_WRITE);af:WriteString(cjson.encode({roles=mealAudit,productionDuty=productionDuty,pantryBlocks=pantryBlocks,foodProduced=s.produced.food-beforeFood,mealsServed=s.mealsServed-beforeMeals,chainStart=steadyChainStart,chainEnd=chainState(s)}));af:Close()

 local sf=File('tests/v3/evidence/'..run..'-steady-state.json',FILE_WRITE);sf:WriteString(cjson.encode(Data.capture(s,1000+s.elapsed,1,true)));sf:Close()
 V.assert(tutorialRelief==0,'No tutorial food rescue occurs during reassignment, recovery or the independent steady window')
end)
for frame=8,1200 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end
 local ok,err=coroutine.resume(task)
 if not ok then
  if activeSim then local f=File('tests/v3/evidence/'..run..'-failed-state.json',FILE_WRITE);f:WriteString(cjson.encode(Data.capture(activeSim,1000+activeSim.elapsed,1,true)));f:Close()end
  V.assert(false,'Normal two-chef configuration: '..tostring(err));V.finish()
 elseif coroutine.status(task)=='dead'then V.finish()end
end)end
