-- D controlled material/geometry acceptance. Never assigns actor.breaks/life,
-- workPresence, timer or visualFinish fields. Simulation creates every phase.
local f=File('tests/life/support.lua',FILE_READ);local H=assert(load(f:ReadString(),'@tests/life/support.lua'))();f:Close()
local Sim=require 'game.Simulation';local Breaks=require 'game.WorkBreaks';local Routine=require 'game.WorkRoutine'
local run='workbreaks';for _,v in ipairs(GetArguments())do run=v:match('^-pixelqa%-run=([%w_-]+)$')or run end
local kinds={'mill','bakery','butcher','sawmill','smelter','tannery','woodweapons','leatherarmor','ironweapons','ironarmor'}
local results={};local current;local originalConsume=H.E.consume;local originalAdd=H.E.add
local function copy(t)local r={};for k,v in pairs(t or {})do r[k]=v end;return r end
H.E.consume=function(b,r)
 local before=copy(b.inputGoods);local result=originalConsume(b,r)
 if current and b.id==current.id then
  current.commits=current.commits+1
  for k,n in pairs(current.required)do if (before[k]or 0)-(b.inputGoods[k]or 0)~=n then current.atomic=false end end
  current.commitAt=current.sim.elapsed
 end
 return result
end
H.E.add=function(b,r,n)
 if current and b.id==current.id then
  current.added[r]=(current.added[r]or 0)+n
  local a=current.sim.workers[b.id..':1'];local target=H.Sites.pickupPoint(b)
  if current.commits==0 or not a or not a.workLoad or not a.breaks or a.breaks.phase~='stow'or math.abs(a.x-target.x)>.001 or math.abs(a.y-target.y)>.001 then current.earlyOutput=true end
 end
 return originalAdd(b,r,n)
end
local function setup(kind)
 local s=Sim.new('finite',23);s.started=true;s.skipped=true;s.stock.wood,s.stock.stone,s.stock.food=1000,1000,500
 local b=H.add(s,kind);local hall=H.add(s,'kitchen');hall.mealStock=8;hall.inputGoods.bread=4;hall.inputs=4
 for _,r in ipairs(H.D.goods)do if r~='food'then s.stock[r]=0 end end
 assert(s:staff(b,1));if H.D.buildings[kind].recipes then assert(s:setRecipe(b,1))end
 return s,b
end
local function required(b)
 local recipe=H.E.recipe(b)
 if recipe then return copy(recipe.inputs)end
 return {[H.D.buildings[b.kind].input]=1}
end
local function supply(b,inputs)
 b.inputs=0;b.inputGoods={}
 for r,n in pairs(inputs)do b.inputGoods[r]=n;b.inputs=b.inputs+n end
end
local function restore(s,id,label)
 local x,why=H.restore(s);V.assert(x~=nil,label..' save/read: '..tostring(why));assert(x,why)
 if current then current.sim=x end
 return x,x.buildings[id]
end
local task=coroutine.create(function()
 for _,kind in ipairs(kinds)do
  local s,b=setup(kind);local id=b.id;local req=required(b);local out=copy(H.E.outputs(b));local phases={};local samples={};local returnedAtDoor=false;local sawWork=false;local sawFinish=false;local noEarly=true;local lastBreak
  current={id=id,sim=s,required=req,commits=0,atomic=true,added={}}
  -- Begin genuinely without inputs, let the original worker enter and then
  -- walk to its real waiting place before providing one declared batch.
  local idle=false
  for i=1,5000 do
   H.step(s);local a=s.workers[id..':1']
   if a and a.breaks then
    local phase=a.breaks.phase
    if not phases[phase]then phases[phase]=true;samples[#samples+1]={stage='missingInput',phase=phase,x=a.x,y=a.y,reason=a.breaks.reason};s,b=restore(s,id,kind..' '..phase)end
    if phase=='idle'then idle=true;break end
   end
   if b.visualFinishAt or b.buffer>0 then noEarly=false end
  end
  V.assert(idle and phases.walk and Breaks.reason(s,b)=='missingInput',kind..' actual missing-input worker walks to a waiting place')
  V.assert(noEarly and current.commits==0,kind..' no product/finish is invented while missing material')
  supply(b,req) -- Explicit controlled one-batch supply, not earned economy.
  local firstReturn=false;local heldCorrect=true;local delivered=false
  for i=1,9000 do
   H.step(s);local a=s.workers[id..':1'];local phase=a and a.breaks and a.breaks.phase
   if phase=='return'then firstReturn=true end
   if a and lastBreak=='return'and phase=='workApproach'then returnedAtDoor=math.abs(a.x-b.x)<.2 and math.abs(a.y-b.y-1)<.2 end
   lastBreak=phase
   if phase=='work'and b.timer>0 and (b.workRate or 0)>0 then sawWork=true end
   if current.commits==0 and (b.visualFinishAt or a and a.workLoad)then noEarly=false end
   if b.visualFinishAt then sawFinish=true;if math.abs(b.visualFinishAt-(current.commitAt or -1))>.000001 then noEarly=false end end
   local held=0
   for _,worker in pairs(s.workers)do if worker.building==id and worker.workLoad then for _,n in pairs(worker.workLoad.goods)do held=held+n end end end
   if held~=(b.workOutputHeld or 0)or b.buffer+held>H.E.capacity(b)then heldCorrect=false end
   if phase and not phases[phase]then
    phases[phase]=true;samples[#samples+1]={stage='production',phase=phase,x=a.x,y=a.y,workLoad=a.workLoad,held=b.workOutputHeld,buffer=b.buffer}
    s,b=restore(s,id,kind..' actual '..phase)
   end
   local complete=current.commits==1
   for r,n in pairs(out)do if s.stock[r]~=n then complete=false end end
   if complete then delivered=true;break end
  end
  V.assert(firstReturn and returnedAtDoor and sawWork,kind..' idle worker returns via actual door and ground station before advancing real work timer')
  V.assert(current.commits==1 and current.atomic and not current.earlyOutput and noEarly,kind..' complete recipe commits once to worker load; shelf add only at actual stow point')
  local correct=true;for r,n in pairs(out)do if current.added[r]~=n then correct=false end end
  V.assert(correct and sawFinish and heldCorrect,kind..' typed output held accounting and true finish marker are conserved until actual handoff')
  V.assert(phases.workApproach and phases.work and phases.finish and phases.toStorage and phases.stow,kind..' all actual outdoor work/carry/storage phases survive JSON')
  V.assert(delivered,kind..' completed typed output is physically handed to ordinary carrier and warehouse')
  results[#results+1]={kind=kind,phases=phases,samples=samples,commits=current.commits,atomic=current.atomic,earlyOutput=current.earlyOutput or false,noEarly=noEarly,commitAt=current.commitAt,finishAt=b.visualFinishAt,added=current.added,required=req};current=nil
 end
end)
for frame=8,2400 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end
 local ok,e=coroutine.resume(task)
 if not ok then H.E.consume=originalConsume;H.E.add=originalAdd;V.assert(false,'D actual work-break cycle: '..tostring(e));V.finish()
 elseif coroutine.status(task)=='dead'then H.E.consume=originalConsume;H.E.add=originalAdd;local out=File('tests/life/evidence/'..run..'-workbreaks.json',FILE_WRITE);out:WriteString(cjson.encode(results));out:Close();V.finish()end
end)end
