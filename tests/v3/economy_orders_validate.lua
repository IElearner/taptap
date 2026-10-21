-- Controlled production-unit fixtures, not a substitute for earned-resource E2E.
local Sim=require 'game.Simulation'
local Data=require 'game.SaveData'
local D=require 'game.Definitions'
local E=require 'game.Economy'
local P=require 'game.Production'
local ticks=0
local function pulse(s,b)
 b.activeWorkers=1;b.workRate=1;P.update(s,.1)
 ticks=ticks+1;if ticks%100==0 then coroutine.yield()end
end
local function fixture(kind,inputs)
 local s=Sim.new('finite',23);s.started=true;s.skipped=true
 s.roads['13:9']=true;s.roads['14:9']=true;s.roadCount=s.roadCount+2
 local b=s:addBuilding(kind,14,8,true);b.workers=1;b.inputGoods={};b.inputs=0
 for r,n in pairs(inputs or {})do b.inputGoods[r]=n;b.inputs=b.inputs+n end
 return s,b
end
local function untilOutput(s,b,resource,amount,seconds)
 for _=1,seconds*10 do if E.outputAmount(b,resource)>=amount then return true end;pulse(s,b)end
 return E.outputAmount(b,resource)>=amount
end
local task=coroutine.create(function()
 local cases={
  {kind='mason',inputs={rawstone=2},output='stone',period=60},
  {kind='smelter',inputs={ironore=1,coal=1},output='iron',period=60},
  {kind='smelter',recipe=2,inputs={goldore=1,coal=1},output='gold',period=60},
  {kind='tannery',inputs={hide=2},output='leather',period=60},
  {kind='woodweapons',inputs={wood=2},output='bow',period=60},
  {kind='leatherarmor',inputs={leather=1,wood=1},output='leatherarmor',period=60},
  {kind='ironweapons',inputs={iron=1,coal=1},output='ironspear',period=90},
  {kind='ironarmor',inputs={iron=1,coal=1},output='ironarmor',period=90},
 }
 for _,c in ipairs(cases)do
  local s,b=fixture(c.kind,c.inputs)
  for _=1,50 do pulse(s,b)end
  V.assert(b.timer==0 and b.buffer==0 and not b.processingRecipe,'New recipe workshop waits for explicit player order: '..c.kind..' '..c.output)
  local ok,msg=s:setRecipe(b,c.recipe or 1);V.assert(ok,'Actual recipe-selection API accepts '..c.output..': '..tostring(msg))
  for _=1,math.floor(c.period*5)do pulse(s,b)end
  V.assert(b.timer>0 and b.timer<c.period and E.outputAmount(b,c.output)==0,'Half-cycle has no prematurely generated product: '..c.output)
  for r,n in pairs(c.inputs)do V.assert(b.inputGoods[r]==n,'Incomplete batch has not partially consumed '..r..' for '..c.output)end
  local restored,err=Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000,1,true))),'finite')
  V.assert(restored~=nil,'Typed active recipe roundtrip restores: '..c.output..' '..tostring(err))
  if restored then s=restored;b=s.buildings[b.id]end
  V.assert(untilOutput(s,b,c.output,1,c.period+2),'Actual production module completes the selected batch: '..c.output)
  V.assert(E.outputAmount(b,c.output)==1 and b.inputs==0,'Batch consumes exactly its full inputs and produces exactly one output: '..c.output)
  for r in pairs(c.inputs)do V.assert((b.inputGoods[r] or 0)==0,'Finished batch consumes exact declared ingredient: '..c.output..' '..r)end
  local unchanged=b.buffer
  for _=1,30 do pulse(s,b)end
  V.assert(b.buffer==unchanged and b.timer==0,'Depleted recipe cannot produce another batch or drift its timer: '..c.output)
 end
 local partial,b=fixture('smelter',{ironore=1});partial:setRecipe(b,1)
 for _=1,650 do pulse(partial,b)end
 V.assert(b.timer==0 and b.buffer==0 and b.inputs==1 and b.inputGoods.ironore==1,'Missing coal prevents both iron production and partial iron-ore consumption')
 local switching,m=fixture('smelter',{ironore=2,coal=2});switching:setRecipe(m,1)
 for _=1,100 do pulse(switching,m)end
 local ok=switching:setRecipe(m,2)
 V.assert(ok and m.processingRecipe==1 and m.queuedRecipe==2,'Mid-batch order switch queues gold while retaining the running iron recipe')
 V.assert(untilOutput(switching,m,'iron',1,70),'Queued switch still finishes the original iron batch')
 V.assert(E.outputAmount(m,'gold')==0 and (m.inputGoods.coal or 0)==1 and (m.inputGoods.goldore or 0)==0,'Iron completion consumes only the current order and creates no next output early')
 -- Explicit input-delivery fixture: one new gold ore arrives after the iron batch.
 -- This isolates recipe switching; real carrier delivery is tested separately.
 m.inputGoods.goldore=1;m.inputs=m.inputs+1
 V.assert(untilOutput(switching,m,'gold',1,70),'Next actual batch executes the queued gold recipe')
 V.assert(E.outputAmount(m,'iron')==1 and E.outputAmount(m,'gold')==1 and E.outputAmount(m,'ironore')==1,'Switch returns exactly the unused iron ore on a real output shelf while preserving both products')
 local full,w=fixture('smelter',{ironore=1,coal=1});full:setRecipe(w,1)
 E.add(w,'iron',E.capacity(w))
 local total=w.inputs+w.buffer
 local cancelled,why=full:setRecipe(w,0)
 V.assert(cancelled and w.queuedRecipe==0,'Cancel on a full shelf queues an explicit deferred cancellation: '..tostring(why))
 for _=1,20 do pulse(full,w)end
 V.assert(w.buffer==E.capacity(w) and w.inputs==2 and w.buffer+w.inputs==total,'Pending cancellation neither overflows the shelf nor deletes reserved inputs')
 -- Model the actual pickup primitive; the two removed items are now held by
 -- the fixture carrier, not discarded from the accounting assertion below.
 E.take(w,'iron',2);local carried=2
 for _=1,20 do pulse(full,w)end
 V.assert(w.inputs==0 and (not w.recipe or w.recipe==0) and w.buffer==E.capacity(w),'When enough shelf space is freed cancellation returns ingredients atomically')
 V.assert(w.buffer+w.inputs+carried==total and E.outputAmount(w,'ironore')==1 and E.outputAmount(w,'coal')==1,'Deferred cancellation conserves every original product and ingredient')
end)
for frame=8,500 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end
 local ok,err=coroutine.resume(task)
 if not ok then V.assert(false,'Recipe coroutine: '..tostring(err));V.finish()
 elseif coroutine.status(task)=='dead'then V.finish()end
end)end
