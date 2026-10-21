-- Controlled warehouse amounts; actual production dispatcher, carrier state
-- machine, typed pantry and JSON restore. No direct food or transit settlement.
local Sim=require 'game.Simulation'
local Data=require 'game.SaveData'
local D=require 'game.Definitions'
local P=require 'game.Production'
local function setup()
 local s=Sim.new('finite',23);s.started=true;s.skipped=true
 for _,r in ipairs(D.goods)do s.stock[r]=0 end
 s.roads['13:9']=true;s.roadCount=1
 local b=s:addBuilding('kitchen',13,8,true);b.activeWorkers=1;b.workRate=1
 return s,b
end
local ticks=0
local function deliver(s,b)
 local c=s.carriers[1];local seen={};local valid=true
 local total=s.stock.bread+s.stock.meat+s.stock.fish+b.inputs
 for _,j in ipairs(s.jobs)do total=total+j.amount end
 for step=1,1500 do
  s:updateCarrier(c,.1,false);s.elapsed=s.elapsed+.1
  local n=s.stock.bread+s.stock.meat+s.stock.fish+b.inputs
  for _,j in ipairs(s.jobs)do n=n+j.amount end
  if c.job and not c.handedOff then n=n+c.job.amount end
  if n~=total or b.inputs>4 then valid=false end
  local mark=(c.phase or 'idle')..(c.carrying and ':loaded' or '')..(c.handedOff and ':handed' or '')
  if c.job and not seen[mark]then
   seen[mark]=true
   local loaded,why=Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000+step,1,true))),'finite')
   V.assert(loaded~=nil,'Actual kitchen inbound restores during '..mark..': '..tostring(why))
   if loaded then s=loaded;b=s.buildings[2];c=s.carriers[1]end
  end
  ticks=ticks+1;if ticks%100==0 then coroutine.yield()end
  if #s.jobs==0 and not c.job then break end
 end
 V.assert(valid,'Kitchen reserved warehouse inputs remain conserved across every real transit/restore stage')
 V.assert(not b.incoming and not c.job and #s.jobs==0,'Actual kitchen delivery clears its reservation exactly once')
 return s,b
end
local task=coroutine.create(function()
 local s,b=setup();s.stock.bread=8
 P.update(s,0)
 V.assert(#s.jobs==1 and s.jobs[1].amount==4 and s.jobs[1].resource=='bread' and s.stock.bread==4 and b.incoming,'Production dispatcher reserves four existing bread and one typed kitchen job')
 P.update(s,0)
 V.assert(#s.jobs==1 and s.stock.bread==4,'Repeated dispatch with an incoming reservation neither duplicates the job nor charges twice')
 s,b=deliver(s,b)
 V.assert(b.inputs==4 and b.inputGoods.bread==4 and s.stock.bread==4,'Real loaded carrier delivers exactly four reserved bread')
 b.activeWorkers=1;b.workRate=1;P.update(s,5.9)
 V.assert(b.inputs==4 and b.mealStock==0,'Bulk hauling does not shorten the six-second cooking period')
 P.update(s,.11)
 V.assert(b.inputs==3 and b.inputGoods.bread==3 and b.mealStock==4,'One cooking batch still consumes only one bread and produces four real meals')
 s,b=setup();s.stock.fish=2;s:enqueue(b,true,'fish')
 V.assert(s.jobs[1].amount==2 and s.stock.fish==0,'New kitchen batch never exceeds real warehouse stock')
 s,b=setup();b.inputs=3;b.inputGoods.bread=3;s.stock.fish=8;s:enqueue(b,true,'fish')
 V.assert(s.jobs[1].amount==1 and s.jobs[1].resource=='fish' and s.stock.fish==7,'Mixed existing pantry permits only its one remaining slot and keeps the new job single-resource')
 s,b=deliver(s,b)
 V.assert(b.inputs==4 and b.inputGoods.bread==3 and b.inputGoods.fish==1,'Typed four-slot kitchen pantry retains both resources after actual transit')
 s:enqueue(b,true,'fish')
 V.assert(#s.jobs==0 and s.stock.fish==7,'Full kitchen input capacity reserves no additional material')
 s,b=setup();s.stock.bread=7;b.incoming=true
 s.jobs={{b=b,inbound=true,resource='bread',amount=1}}
 local old=Data.capture(s,1000,1,true)
 s=Data.restore(cjson.decode(cjson.encode(old)),'finite');b=s.buildings[2]
 V.assert(s.jobs[1].amount==1 and s.stock.bread==7,'Existing saved one-unit kitchen delivery retains its original amount and reserved warehouse balance')
 s,b=deliver(s,b)
 V.assert(b.inputs==1 and b.inputGoods.bread==1 and s.stock.bread==7,'Old one-unit task delivers exactly one after the capacity upgrade')
end)
for frame=8,300 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end
 local ok,err=coroutine.resume(task)
 if not ok then V.assert(false,'Kitchen batch regression: '..tostring(err));V.finish()
 elseif coroutine.status(task)=='dead'then V.finish()end
end)end
