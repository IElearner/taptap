-- Controlled production boundaries, separate from the earned village.
local Sim=require 'game.Simulation'
local Data=require 'game.SaveData'
local E=require 'game.Economy'
local P=require 'game.Production'
local ticks=0
local function fixture(kind,goods)
 local s=Sim.new('finite',23);s.started=true;s.skipped=true
 for r in pairs(s.stock)do s.stock[r]=0 end
 s.roads['13:9']=true;s.roads['14:9']=true;s.roadCount=2
 local b=s:addBuilding(kind,14,8,true);b.workers=1;b.inputs=0;b.inputGoods={}
 for r,n in pairs(goods)do b.inputGoods[r]=n;b.inputs=b.inputs+n end
 return s,b
end
local function advance(s,b,seconds)
 for _=1,math.floor(seconds*10+.5)do
  b.activeWorkers=1;b.workRate=1;P.update(s,.1);ticks=ticks+1
  if ticks%100==0 then coroutine.yield()end
 end
end
local function restore(s,b)
 local loaded,why=Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000,1,true))),'finite')
 V.assert(loaded~=nil,'Active typed food boundary restores: '..tostring(why))
 return loaded,loaded and loaded.buildings[b.id]
end
local task=coroutine.create(function()
 for _,case in ipairs({
  {inputs={bread=1,meat=1,fish=1},selected='bread'},
  {inputs={meat=1,fish=1},selected='meat'},
  {inputs={fish=1},selected='fish'},
 })do
  local s,b=fixture('kitchen',case.inputs);local initial=b.inputs
  advance(s,b,3)
  V.assert(b.inputs==initial and b.processingResource==case.selected and b.buffer+(b.mealStock or 0)==0,'Mixed food batch locks one actual alternative without consuming early: '..case.selected)
  s,b=restore(s,b);advance(s,b,3.1)
  V.assert(b.inputs==initial-1 and b.buffer+(b.mealStock or 0)==4,'One completed alternative cooks exactly four meals: '..case.selected)
  for r,n in pairs(case.inputs)do V.assert((b.inputGoods[r]or 0)==n-(r==case.selected and 1 or 0),'Mixed batch consumes only its selected ingredient: '..case.selected..'/'..r)end
 end
 local s,b=fixture('butcher',{livestock=1});advance(s,b,4)
 V.assert(b.inputs==1 and b.buffer==0,'Half slaughter retains the whole animal and has no premature meat or hide')
 s,b=restore(s,b);advance(s,b,4.1)
 V.assert(b.inputs==0 and E.outputAmount(b,'meat')==3 and E.outputAmount(b,'hide')==1 and b.buffer==4,'One real slaughter atomically creates three meat and one hide')
 s,b=restore(s,b);advance(s,b,10)
 V.assert(E.outputAmount(b,'meat')==3 and E.outputAmount(b,'hide')==1,'Completed slaughter survives repeated updates and JSON without duplicating either product')
 local full,f=fixture('butcher',{livestock=1});f.buffer=5;f.outputGoods={hide=5}
 advance(full,f,10)
 V.assert(f.inputs==1 and f.timer==0 and E.outputAmount(f,'hide')==5 and E.outputAmount(f,'meat')==0,'Insufficient shared shelf space blocks both slaughter outputs without consuming livestock')
 E.take(f,'hide',1) -- Explicit unit-boundary removal of one unreserved shelf unit.
 advance(full,f,8.1)
 V.assert(f.inputs==0 and f.buffer==E.capacity(f) and E.outputAmount(f,'hide')==5 and E.outputAmount(f,'meat')==3,'Exactly enough shared capacity accepts the complete dual-output batch without overflow')
 local blocked,m=fixture('smelter',{ironore=1,coal=1});blocked:setRecipe(m,1)
 blocked.roads['14:9']=nil;blocked.roadCount=1;advance(blocked,m,61)
 V.assert(m.timer==0 and m.inputs==2 and m.buffer==0,'Disconnected typed workshop neither advances nor consumes its multi-input batch')
 blocked.roads['14:9']=true;blocked.roadCount=2;blocked:setWorking(m,false);advance(blocked,m,61)
 V.assert(m.timer==0 and m.inputs==2 and m.buffer==0,'Stopped typed workshop preserves both inputs and its timer')
 blocked:setWorking(m,true);advance(blocked,m,60.1)
 V.assert(m.inputs==0 and E.outputAmount(m,'iron')==1,'Reconnected and resumed typed workshop finishes the original complete batch once')
end)
for frame=8,100 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end
 local ok,why=coroutine.resume(task)
 if not ok then V.assert(false,'Food/capacity boundary: '..tostring(why));V.finish()
 elseif coroutine.status(task)=='dead'then V.finish()end
end)end
