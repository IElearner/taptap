-- Controlled boundary fixture; no economy sustainability claim.
-- Dispatcher jobs and real carriers retain normal stock reservation/JSON semantics.
local Sim=require 'game.Simulation'
local D=require 'game.Definitions'
local Data=require 'game.SaveData'
local E=require 'game.Economy'
local P=require 'game.Production'
local ticks=0
local function setup(kind,n,version)
 local s=Sim.new('finite',23);s.started=true;s.skipped=true
 for _,r in ipairs(D.goods)do s.stock[r]=0 end
 s.roads['13:9']=true;s.roadCount=1
 local b=s:addBuilding(kind,13,8,true);b.activeWorkers=1;b.workRate=1
 if kind=='mill'then b.recipeVersion=version or 2 end
 local resource=D.buildings[kind].input
 b.inputGoods[resource]=n;b.inputs=n;s.stock[resource]=8
 return s,b,resource
end
local function delivery(s,b,r)
 local c=s.carriers[1];local expected=s.stock[r]+b.inputs+s.jobs[1].amount;local seen={};local valid=true
 for step=1,1800 do
  s:updateCarrier(c,.1,false);s.elapsed=s.elapsed+.1
  local actual=s.stock[r]+b.inputs
  for _,j in ipairs(s.jobs)do actual=actual+j.amount end
  if c.job and not c.handedOff then actual=actual+c.job.amount end
  if actual~=expected or b.inputs>4 then valid=false end
  local phase=(c.phase or 'idle')..(c.carrying and ':carried' or '')..(c.handedOff and ':handed' or '')
  if c.job and not seen[phase]then
   seen[phase]=true
   local amount=c.job.amount
   s=Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000+step,1,true))),'finite');b=s.buildings[2];c=s.carriers[1]
   V.assert(c.job and c.job.amount==amount,'Actual '..b.kind..' '..phase..' retains reserved amount across JSON')
  end
  ticks=ticks+1;if ticks%100==0 then coroutine.yield()end
  if not c.job and #s.jobs==0 then break end
 end
 V.assert(valid and b.inputs==4 and not b.incoming,'Actual '..b.kind..' replenishment conserves stock/transit/input and reaches capacity exactly once')
 return s,b
end
local task=coroutine.create(function()
 for _,kind in ipairs({'ranch','bakery','sawmill','mill'})do
  local low=kind=='mill' and 2 or 1
  local s,b,r=setup(kind,low)
  P.update(s,0)
  V.assert(#s.jobs==1 and s.jobs[1].resource==r and s.jobs[1].amount==4-low and s.stock[r]==4+low and b.incoming,'Ready '..kind..' at low water reserves only actual remaining input space')
  P.update(s,0)
  V.assert(#s.jobs==1 and s.stock[r]==4+low,'Repeated '..kind..' dispatcher does not duplicate incoming or debit twice')
  s,b=delivery(s,b,r)
  P.update(s,0);V.assert(#s.jobs==0,'Full '..kind..' input does not request more')
  s,b,r=setup(kind,low+1);P.update(s,0)
  V.assert(#s.jobs==0 and s.stock[r]==8,'Ready '..kind..' above low water does not prefill early')
  s,b,r=setup(kind,0);s.stock[r]=1;P.update(s,0)
  V.assert(#s.jobs==1 and s.jobs[1].amount==1 and s.stock[r]==0,'Low actual stock limits '..kind..' reservation to one')
  for _,state in ipairs({'stopped','unassigned','disconnected'})do
   s,b,r=setup(kind,low)
   if state=='stopped'then b.stopped=true elseif state=='unassigned'then b.activeWorkers=0;b.workRate=0 else s.roads['13:9']=nil;s.roadCount=s.roadCount+1 end
   P.update(s,0);V.assert(#s.jobs==0 and s.stock[r]==8,'No '..kind..' prefill while '..state)
  end
 end
 local s,b,r=setup('mill',1,1);P.update(s,0)
 V.assert(#s.jobs==0 and s.stock.grain==8,'Ready legacy mill is excluded from new low-water policy')
 s,b,r=setup('mill',0,1);P.update(s,0)
 V.assert(#s.jobs==1 and s.jobs[1].amount==1,'Empty legacy mill retains one-unit job')
 s,b,r=setup('kitchen',1);P.update(s,0)
 V.assert(#s.jobs==0 and s.stock[r]==8,'Ready kitchen keeps its existing strategy without new prefill')
 s=Sim.new('finite',23);s.started=true;s.skipped=true;s.roads['13:9']=true;s.roadCount=1
 b=s:addBuilding('smelter',13,8,true);s:setRecipe(b,1);b.inputGoods={ironore=1,coal=1};b.inputs=2;b.activeWorkers=1;b.workRate=1;s.stock.ironore=8;s.stock.coal=8
 P.update(s,0)
 V.assert(#s.jobs==0 and s.stock.ironore==8 and s.stock.coal==8,'Ready multi-input iron order is excluded from single-input prefill')
end)
for frame=8,250 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end
 local ok,err=coroutine.resume(task)
 if not ok then V.assert(false,'Prefill regression: '..tostring(err));V.finish()elseif coroutine.status(task)=='dead'then V.finish()end
end)end
