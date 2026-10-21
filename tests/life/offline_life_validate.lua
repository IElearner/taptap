-- Independent life/outdoor-workshop offline integration. Controlled materials
-- and hunger=95 are explicit edge fixtures, never sustainability evidence.
local f=File('tests/life/support.lua',FILE_READ);local H=assert(load(f:ReadString(),'@tests/life/support.lua'))();f:Close()
local Sim=require 'game.Simulation';local Offline=require 'game.Offline'
local run='life-offline';for _,v in ipairs(GetArguments())do run=v:match('^-pixelqa%-run=([%w_-]+)$')or run end
local life={fishery=true,ironmine=true,coalmine=true,goldmine=true,quarry=true,mason=true}
local kinds={'fishery','ironmine','coalmine','goldmine','quarry','mason','mill','bakery','butcher','sawmill','smelter','tannery','woodweapons','leatherarmor','ironweapons','ironarmor'}
local records={}
local function totals(s,r)
 local total=s.stock[r]or 0
 for _,b in ipairs(s.buildings)do total=total+(b.inputGoods[r]or 0)+H.E.outputAmount(b,r);if r=='food'then total=total+(b.mealStock or 0)end end
 for _,a in pairs(s.workers)do
  if a.life and a.life.load and a.life.load.resource==r then total=total+a.life.load.amount end
  if a.workLoad and a.workLoad.goods then total=total+(a.workLoad.goods[r]or 0)end
 end
 for _,j in ipairs(s.jobs)do if j.resource==r and(j.inbound or j.pickedUp)then total=total+j.amount end end
 for _,a in ipairs(s.carriers)do local j=a.job;if j and not a.handedOff and j.resource==r and(j.inbound or j.pickedUp)then total=total+j.amount end end
 return total
end
local function eachActor(s,fn)
 for _,a in ipairs(s.carriers)do fn(a)end;for _,a in pairs(s.workers)do fn(a)end;for _,a in ipairs(s.builders)do fn(a)end;for _,a in ipairs(s.guards)do fn(a)end
end
local function setup(kind)
 if life[kind]then return H.setup(kind)end
 local s=Sim.new('finite',23);s.started,s.skipped=true,true;s.stock.wood,s.stock.stone,s.stock.food=1000,1000,500
 local b=H.add(s,kind);local hall=H.add(s,'kitchen');hall.mealStock=8;hall.inputGoods.bread=4;hall.inputs=4
 for _,r in ipairs(H.D.goods)do if r~='food'then s.stock[r]=0 end end
 assert(s:staff(b,1));if H.D.buildings[kind].recipes then assert(s:setRecipe(b,1))end
 local recipe=H.E.recipe(b);local inputs=recipe and recipe.inputs or {[H.D.buildings[kind].input]=1}
 for r,n in pairs(inputs)do b.inputGoods[r]=n;b.inputs=b.inputs+n end
 return s,b,hall
end
local function round(s,savedAt)
 local encoded=cjson.encode(H.Data.capture(s,savedAt,1,true));local data=cjson.decode(encoded);local restored,why=H.Data.restore(data,'finite');assert(restored,why);return restored,data
end
local task=coroutine.create(function()
 for _,kind in ipairs(kinds)do
  local s,b=setup(kind);local id=b.id;s:update(.1) -- create actual actors before controlled hunger edge
  eachActor(s,function(a)assert(not a.meal,'Fixture must begin before an actual meal');a.hunger=95;a.energy=60 end)
  local expected={};for r,n in pairs(H.E.outputs(b))do expected[r]=n end
  local before={food=totals(s,'food'),meals=s.mealsServed,elapsed=s.elapsed,health=s.health,nextRaid=s.nextRaid}
  s=round(s,1000);b=s.buildings[id]
  local off=Offline.new(s,1000,1900,true);local phases={};local noNewMeals=true;local midReload=false;local ticks=0
  while off.remaining>0 do
   off:step(1);ticks=ticks+1;local a=s.workers[id..':1']
   local phase=a and(a.life and a.life.phase or a.breaks and a.breaks.phase)or 'routine';phases[phase]=true
   eachActor(s,function(actor)if actor.meal then noNewMeals=false end end)
   if not midReload and off.remaining<=448 then
    local settledAt=1900-off.remaining;local oldRemaining=off.remaining;s=round(s,settledAt);b=s.buildings[id]
    off=Offline.new(s,settledAt,1900,true);V.assert(off.remaining==oldRemaining,kind..' mid-offline save resumes only remaining elapsed wall time');midReload=true
   end
   if ticks%128==0 then coroutine.yield()end
  end
  local exact=true
  for r,n in pairs(expected)do if s.stock[r]~=n then exact=false end end
  local a=s.workers[id..':1']
  V.assert(exact,kind..' hungry offline worker produces, physically stores and carrier delivers its one real batch')
  V.assert(noNewMeals and s.mealsServed==before.meals and totals(s,'food')==before.food,kind..' offline neither opens new meals nor consumes food')
  V.assert(a and not a.workLoad and not(a.life and a.life.load),kind..' offline batch is no longer stranded in worker hands')
  V.assert(s.elapsed==before.elapsed and s.health==before.health and s.nextRaid==before.nextRaid,kind..' offline leaves online clock/health/next-wave timing unchanged')
  local complete,data=round(s,1900);local repeated=Offline.new(complete,data.savedAt,1900,true)
  V.assert(repeated.seconds==0 and repeated:step(1),kind..' saved completed offline interval cannot be reclaimed')
  local preserved=true;for _,r in ipairs(H.D.goods)do if totals(complete,r)~=totals(s,r)then preserved=false end end
  V.assert(preserved and complete.mealsServed==s.mealsServed,kind..' repeated reload preserves all carried/shelf/warehouse goods and meal count')
  records[#records+1]={kind=kind,expected=expected,stock=s.stock,phases=phases,foodBefore=before.food,foodAfter=totals(s,'food'),mealsBefore=before.meals,mealsAfter=s.mealsServed}
 end
 -- Existing PAID meal follows the real enter/eat/exit/return sequence. Offline
 -- may finish this previously paid meal but cannot charge it again or erase it.
 for _,kind in ipairs({'fishery','mill'})do
  local s,b=setup(kind);local id=b.id;s:update(.1);s:setWorking(b,false)
  s.workers[id..':1'].hunger=95
  local paid=false
  for i=1,6000 do H.step(s);local a=s.workers[id..':1'];if a.meal and a.meal.paid then paid=true;break end end
  V.assert(paid,kind..' paid-meal offline case starts from a naturally paid meal');assert(paid,'paid prerequisite')
  s=round(s,2000);b=s.buildings[id];local beforeFood,beforeMeals=totals(s,'food'),s.mealsServed
  local a=s.workers[id..':1'];local originalPhase=a.meal.phase;local off=Offline.new(s,2000,2300,true);off:step(1)
  V.assert(a.meal and a.meal.paid,kind..' first offline tick preserves already paid meal rather than clearing it')
  local loops=0;while not off:step(64)do loops=loops+1;coroutine.yield();assert(loops<100)end
  V.assert(not a.meal and s.mealsServed==beforeMeals and totals(s,'food')==beforeFood,kind..' paid meal finishes and returns with no second food deduction')
  records[#records+1]={kind=kind,paidStart=originalPhase,paidFinished=not a.meal,foodBefore=beforeFood,foodAfter=totals(s,'food')}
 end
 do
  local s=Sim.new('finite',23);s.started=true;s.skipped=true
  V.assert(Offline.new(s,1000,999999,true).seconds==28800,'Life expansion retains exact eight-hour offline cap')
  V.assert(Offline.new(s,2000,1900,true).seconds==0,'Future saved timestamp settles zero seconds')
  V.assert(Offline.new(s,1000,1900,false).seconds==0,'Disabled offline production settles zero seconds')
  s.paused=true;V.assert(Offline.new(s,1000,1900,true).seconds==0,'Paused game still has zero offline settlement')
 end
end)
for frame=8,1800 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end
 local ok,e=coroutine.resume(task);if not ok then V.assert(false,'Life/outdoor offline independent regression: '..tostring(e));V.finish()
 elseif coroutine.status(task)=='dead'then local f=File('tests/life/evidence/'..run..'-offline.json',FILE_WRITE);f:WriteString(cjson.encode(records));f:Close();V.finish()end
end)end
