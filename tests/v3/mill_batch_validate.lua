-- Controlled inventory scaffold; production dispatcher and real carrier routes.
-- The change under test affects new warehouse reservations only, not saved jobs.
local Sim=require 'game.Simulation'
local Data=require 'game.SaveData'
local D=require 'game.Definitions'
local E=require 'game.Economy'
local P=require 'game.Production'
local ticks=0
local function setup(version)
 local s=Sim.new('finite',23);s.started=true;s.skipped=true
 for _,r in ipairs(D.goods)do s.stock[r]=0 end
 s.roads['13:9']=true;s.roadCount=1
 local b=s:addBuilding('mill',13,8,true);b.recipeVersion=version or 2;b.activeWorkers=1;b.workRate=1
 return s,b
end
local function transfer(s,b)
 local c=s.carriers[1];local seen={};local conserved=true
 local total=s.stock.grain+b.inputs
 for _,j in ipairs(s.jobs)do total=total+j.amount end
 for step=1,1800 do
  s:updateCarrier(c,.1,false);s.elapsed=s.elapsed+.1
  local n=s.stock.grain+b.inputs
  for _,j in ipairs(s.jobs)do n=n+j.amount end
  if c.job and not c.handedOff then n=n+c.job.amount end
  if n~=total or b.inputs>4 then conserved=false end
  local mark=(c.phase or 'idle')..(c.carrying and ':carried' or '')..(c.handedOff and ':delivered' or '')
  if c.job and not seen[mark]then
   seen[mark]=true
   local amount=c.job.amount
   local loaded,why=Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000+step,1,true))),'finite')
   V.assert(loaded~=nil,'Mill inbound save/load during real '..mark..': '..tostring(why))
   if loaded then s=loaded;b=s.buildings[2];c=s.carriers[1];V.assert(c.job and c.job.amount==amount,'Stored task amount survives '..mark)end
  end
  ticks=ticks+1;if ticks%100==0 then coroutine.yield()end
  if #s.jobs==0 and not c.job then break end
 end
 V.assert(conserved,'All grain remains exactly conserved across every transit and JSON state')
 V.assert(not b.incoming and not c.job and #s.jobs==0,'Actual delivery completes and clears one incoming lock exactly once')
 return s,b
end
local task=coroutine.create(function()
 local s,b=setup(2);s.stock.grain=8
 P.update(s,0)
 V.assert(#s.jobs==1 and s.jobs[1].amount==4 and s.jobs[1].resource=='grain' and s.stock.grain==4 and b.incoming,'Modern mill reserves four real grain through Production dispatcher')
 P.update(s,0);V.assert(#s.jobs==1 and s.stock.grain==4,'Incoming lock prevents duplicate modern mill reservation')
 s,b=transfer(s,b)
 V.assert(b.inputs==4 and b.inputGoods.grain==4 and s.stock.grain==4,'Actual modern carrier delivers exactly four grain')
 b.activeWorkers=1;b.workRate=1;P.update(s,89.9)
 V.assert(b.inputs==4 and E.outputAmount(b,'flour')==0,'Modern mill still requires ninety effective work seconds')
 P.update(s,.11)
 V.assert(b.inputs==2 and b.inputGoods.grain==2 and E.outputAmount(b,'flour')==2,'One modern batch still consumes exactly two grain and produces exactly two flour')
 s,b=setup(2);s.stock.grain=1;s:enqueue(b,true,'grain')
 V.assert(s.jobs[1].amount==1 and s.stock.grain==0,'Modern batch is bounded by actual one-grain warehouse stock')
 s,b=setup(2);b.inputs=3;b.inputGoods.grain=3;s.stock.grain=8;s:enqueue(b,true,'grain')
 V.assert(s.jobs[1].amount==1 and s.stock.grain==7,'Modern batch is bounded by the single remaining real input slot')
 s,b=transfer(s,b);s:enqueue(b,true,'grain')
 V.assert(b.inputs==4 and #s.jobs==0 and s.stock.grain==7,'Full modern input capacity creates no task and no charge')
 s,b=setup(1);s.stock.grain=8;P.update(s,0)
 V.assert(#s.jobs==1 and s.jobs[1].amount==1 and s.stock.grain==7,'Legacy mill retains one-grain warehouse reservation')
 s,b=transfer(s,b);b.activeWorkers=1;b.workRate=1;P.update(s,5.9)
 V.assert(b.inputs==1 and E.outputAmount(b,'flour')==0,'Legacy mill retains the six-second work period')
 P.update(s,.11)
 V.assert(b.inputs==0 and E.outputAmount(b,'flour')==2,'Legacy recipe still consumes one grain for two flour')
 s,b=setup(2);s.stock.grain=7;b.incoming=true;s.jobs={{b=b,inbound=true,resource='grain',amount=1}}
 s=Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000,1,true))),'finite');b=s.buildings[2]
 V.assert(s.jobs[1].amount==1 and s.stock.grain==7,'Pre-upgrade saved modern one-grain task remains one with unchanged reserved balance')
 s,b=transfer(s,b)
 V.assert(b.inputs==1 and b.inputGoods.grain==1 and s.stock.grain==7,'Existing one-grain task is delivered once without retrospective upgrade')
end)
for frame=8,250 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end
 local ok,err=coroutine.resume(task)
 if not ok then V.assert(false,'Mill batch regression: '..tostring(err));V.finish()elseif coroutine.status(task)=='dead'then V.finish()end
end)end
