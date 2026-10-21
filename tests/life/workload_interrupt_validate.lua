-- Actual finished goods, then normal stop/staff attempts plus a declared hungry
-- edge. No phase/load assignment; material fixture exactly one whole recipe.
local f=File('tests/life/support.lua',FILE_READ);local H=assert(load(f:ReadString(),'@tests/life/support.lua'))();f:Close()
local Sim=require 'game.Simulation'
local task=coroutine.create(function()
 for _,kind in ipairs({'mill','butcher','smelter'})do for _,phase in ipairs({'finish','toStorage','stow'})do
  local s=Sim.new('finite',23);s.started,s.skipped=true,true;s.stock.wood,s.stock.stone,s.stock.food=1000,1000,500
  local b=H.add(s,kind);local hall=H.add(s,'kitchen');hall.mealStock=8;hall.inputGoods.bread=4;hall.inputs=4
  for _,r in ipairs(H.D.goods)do if r~='food'then s.stock[r]=0 end end
  assert(s:staff(b,1));if H.D.buildings[kind].recipes then assert(s:setRecipe(b,1))end
  local recipe=H.E.recipe(b);local inputs=recipe and recipe.inputs or {[H.D.buildings[kind].input]=1};local out={};for r,n in pairs(H.E.outputs(b))do out[r]=n end
  for r,n in pairs(inputs)do b.inputGoods[r]=n;b.inputs=b.inputs+n end
  local id=b.id;local reached=false
  for i=1,7000 do H.step(s);local a=s.workers[id..':1'];if a and a.workLoad and a.breaks.phase==phase then reached=true;break end end
  V.assert(reached,kind..' naturally reaches loaded '..phase);assert(reached)
  local old=s.workers[id..':1'];old.hunger=95 -- controlled pending meal boundary, not free food
  V.assert(s:setWorking(b,false),kind..' normal stop accepted while '..phase)
  local removed=s:staff(b,-1)
  V.assert(not removed and b.workers==1 and s.workers[id..':1']==old,kind..' occupied load slot cannot be removed before handoff')
  local z,why=H.restore(s);V.assert(z~=nil,kind..' stopped hungry loaded '..phase..' JSON: '..tostring(why));assert(z,why);s=z;b=s.buildings[id]
  local noEarlyMeal=true;local noLoss=true;local paid=false;local ate=false;local returned=false;local done=false
  for i=1,9000 do
   H.step(s);local a=s.workers[id..':1'];if a.workLoad and a.meal then noEarlyMeal=false end
   if a.meal and a.meal.paid then paid=true end;if a.meal and a.meal.phase=='eat'then ate=true end
   if ate and not a.meal then returned=true end
   local delivered=true
   for r,n in pairs(out)do if H.goods(s,r)~=n then noLoss=false end;if s.stock[r]~=n then delivered=false end end
   if delivered and returned then done=true;break end
  end
  V.assert(noEarlyMeal and noLoss and done and paid,kind..' stopped '..phase..' safely stows all typed goods before eating and really returning')
  V.assert((b.workOutputHeld or 0)==0 and not s.workers[id..':1'].workLoad and b.stopped,kind..' pause remains active without orphaned held load after meal')
 end end
end)
for frame=8,1800 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end;local ok,e=coroutine.resume(task);if not ok then V.assert(false,'Outdoor load interruption: '..tostring(e));V.finish()elseif coroutine.status(task)=='dead'then V.finish()end
end)end
