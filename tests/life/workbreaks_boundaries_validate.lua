-- D waiting-reason matrix. All actor phases are natural. Materials and temporary
-- road/transport outages are explicit controlled fixtures, not economic claims.
local f=File('tests/life/support.lua',FILE_READ);local H=assert(load(f:ReadString(),'@tests/life/support.lua'))();f:Close()
local Sim=require 'game.Simulation';local Breaks=require 'game.WorkBreaks'
local kinds={'mill','bakery','butcher','sawmill','smelter','tannery','woodweapons','leatherarmor','ironweapons','ironarmor'}
local function fresh(kind)
 local s=Sim.new('finite',23);s.started,s.skipped=true,true;s.stock.wood,s.stock.stone,s.stock.food=1000,1000,500
 local b=H.add(s,kind);local hall=H.add(s,'kitchen');hall.mealStock=8;hall.inputGoods.bread=4;hall.inputs=4
 for _,r in ipairs(H.D.goods)do if r~='food'then s.stock[r]=0 end end
 assert(s:staff(b,1));if H.D.buildings[kind].recipes then assert(s:setRecipe(b,1))end
 return s,b
end
local function fill(b)
 local recipe=H.E.recipe(b);local inputs=recipe and recipe.inputs or {[H.D.buildings[b.kind].input]=1}
 b.inputs=0;b.inputGoods={};for r,n in pairs(inputs)do b.inputGoods[r]=n;b.inputs=b.inputs+n end
end
local function isolateOutput(s,b)
 local original=s.enqueue
 s.enqueue=function(self,source,inbound,resource)
  if source.id==b.id and not inbound then return end -- controlled no-carrier full-shelf isolation
  return original(self,source,inbound,resource)
 end
end
local task=coroutine.create(function()
 for _,kind in ipairs(kinds)do
  for _,reason in ipairs({'missingInput','stopped','disconnected','fullOutput','noOrder'})do
   if reason~='noOrder'or H.D.buildings[kind].recipes then
    local s,b=fresh(kind);local id=b.id
    if reason~='missingInput'and reason~='noOrder'then fill(b)end
    local savedRoads={};for k,v in pairs(s.roads)do savedRoads[k]=v end
    if reason=='stopped'then assert(s:setWorking(b,false))
    elseif reason=='disconnected'then s.roads[b.x..':'..(b.y+1)]=nil;s.roadCount=s.roadCount+1
    elseif reason=='fullOutput'then H.E.add(b,H.D.buildings[kind].output,H.E.capacity(b));isolateOutput(s,b)
    elseif reason=='noOrder'then assert(s:setRecipe(b,0))end
    local beforeInputs=b.inputs;local beforeBuffer=b.buffer;local timer=b.timer;local idle,loaded=false,false
    for i=1,3500 do
     H.step(s);local a=s.workers[id..':1']
     if a and a.breaks and a.breaks.phase=='idle'and a.breaks.reason==reason then idle=true;break end
    end
    V.assert(idle,kind..' genuinely enters idle for '..reason)
    V.assert(b.inputs==beforeInputs and b.buffer==beforeBuffer and b.timer==timer and not b.visualFinishAt,kind..' blocked '..reason..' has no work credit, ingredient debit, or premature product')
    if idle then
     local restored,why=H.restore(s);V.assert(restored~=nil,kind..' '..reason..' idle JSON: '..tostring(why));assert(restored,why)
     s,b=restored,restored.buildings[id];if reason=='fullOutput'then isolateOutput(s,b)end
     for i=1,20 do H.step(s)end
     local a=s.workers[id..':1'];loaded=a and a.breaks and a.breaks.reason==reason
     V.assert(loaded and b.inputs==beforeInputs and b.buffer==beforeBuffer,kind..' saved '..reason..' stays blocked without duplicate material changes')
    end
   end
  end
 end
end)
for frame=8,3200 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end
 local ok,e=coroutine.resume(task);if not ok then V.assert(false,'D waiting boundaries: '..tostring(e));V.finish()elseif coroutine.status(task)=='dead'then V.finish()end
end)end
