-- Recovery from the unaltered, actually earned 242 failed-endurance checkpoint.
-- Existing hunger is retained; actual eating/return must recover before a fresh 30min window.
-- Normal online new-game progression, using only the game's real starter stock.
-- Fixed 33-entity seed-23 benchmark, not a typical required player layout.
-- Unlike the old village fixture, road work never uses offline=true.
-- Intro tutorial relief is counted; the industrial branch explicitly disables it.
local Sim=require 'game.Simulation'
local Data=require 'game.SaveData'
local Store=require 'game.PixelSaveStore'
local D=require 'game.Definitions'
local pf=File('tests/v3/fixtures/fixed_v3_seed23.json',FILE_READ)
local fixedPlan=cjson.decode(pf:ReadString());pf:Close()
local fixedRoads={};for _,xy in ipairs(fixedPlan.roads)do fixedRoads[xy[1]..':'..xy[2]]=true end
local run='v3-e2e'
for _,arg in ipairs(GetArguments())do run=arg:match('^-pixelqa%-run=([%w_-]+)$') or run end
local activeSim
local ticks=0
local mealAudit=nil
local auditStart=0
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
   else record.idleSeconds=record.idleSeconds+.1 end
   if previous[key] and previous[key].phase=='eat' and a.meal and a.meal.phase=='exit'then record.meals=record.meals+1;record.firstMeal=record.firstMeal or s.elapsed-auditStart;record.lastMeal=s.elapsed-auditStart end
   if previous[key] and previous[key].phase and not a.meal then record.returned=record.returned+1;record.firstReturn=record.firstReturn or s.elapsed-auditStart end
  end
 end
 if ticks%100==0 then coroutine.yield() end
end
local function untilTrue(s,predicate,seconds)
    for _=1,seconds*10 do if predicate() then return true end;tick(s) end
    return predicate()
end
local function build(s,kind,x,y)
    if kind=='courier'then V.assert(untilTrue(s,function()return s:availableWorkers()>0 end,300),'Existing resident returns from meal/construction before accepting paid courier blueprint')end
    local beforeWood,beforeStone=s.stock.wood,s.stock.stone
    local ok,message,b=s:build(kind,x,y)
    V.assert(ok,'New-game plan '..kind..' at '..x..','..y..': '..tostring(message))
    if not ok then return nil end
    local cost=D.buildings[kind].cost
    V.assert(s.stock.wood==beforeWood-(cost.wood or 0) and s.stock.stone==beforeStone-(cost.stone or 0),'Actual construction API charges exact stated cost once: '..kind)
    local complete=untilTrue(s,function() return kind=='road' and s.roads[x..':'..y] or b and b.complete end,600)
    V.assert(complete,'Normal online workers finish '..kind..' at '..x..','..y)
    return b
end
local function nextLesson(s,n)
    V.assert(s:nextLesson() and s.lesson==n+1,'Normal new-game lesson '..n..' completes its real objective')
end
-- Automatic legal siting uses real geometry, deposit rules and connected road paths.
-- No stock/population/production fields are granted by this planner.
local reserved={woodcutter={6,4},sawmill={10,16},forester={6,8},ironmine={9,4},coalmine={16,8},goldmine={18,21},fishery={21,19}}
local function cellkey(x,y)return x..':'..y end
local function blockedFor(s,kind,x,y)
 local blocked={}
 for name,xy in pairs(reserved)do
  if name~=kind and s:count(name)==0 then
   for _,c in ipairs(D.cells(name))do blocked[cellkey(xy[1]+c.x,xy[2]+c.y)]=true end
  end
 end
 for _,c in ipairs(D.cells(kind))do blocked[cellkey(x+c.x,y+c.y)]=true end
 return blocked
end
local function pathTo(s,kind,x,y)
 local blocked=blockedFor(s,kind,x,y)
 local target=cellkey(x,y+1);local queue,seen,parents={}, {}, {}
 for k in pairs(s.roads)do local rx,ry=k:match('(-?%d+):(-?%d+)');queue[#queue+1]={tonumber(rx),tonumber(ry)};seen[k]=true end
 local i=1;local found=seen[target]
 while not found and queue[i]do
  local a=queue[i];i=i+1
  for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
   local nx,ny=a[1]+d[1],a[2]+d[2];local nk=cellkey(nx,ny)
   if not seen[nk] and not blocked[nk] and s:terrain(nx,ny)=='grass' and not s:buildingAt(nx,ny)then
    seen[nk]=true;parents[nk]=cellkey(a[1],a[2]);queue[#queue+1]={nx,ny}
    if nk==target then found=true;break end
   end
  end
 end
 if not found then return nil end
 local route={};local k=target
 while not s.roads[k]do
  local rx,ry=k:match('(-?%d+):(-?%d+)');table.insert(route,1,{tonumber(rx),tonumber(ry)});k=parents[k]
 end
 return route
end
local function site(s,kind)
 local ordinal=s:count(kind)+1;local seen=0
 for _,p in ipairs(fixedPlan.buildings)do
  if p.kind==kind then seen=seen+1;if seen==ordinal then
   local ok=s:canBuild(kind,p.x,p.y);local route=ok and pathTo(s,kind,p.x,p.y)
   if route then return {x=p.x,y=p.y,path=route,score=#route}end
   return nil
  end end
 end
 local choices={};local fixed=reserved[kind];local searched=0
 local low,high=s.map:bounds()
 for x=low,high do for y=low,high-1 do
  if not fixed or x==fixed[1] and y==fixed[2]then
   searched=searched+1;if searched%16==0 then coroutine.yield()end
   local ok=s:canBuild(kind,x,y)
   if ok then
    local conflict=false
    local blocked=blockedFor(s,kind,-100,-100)
    for _,c in ipairs(D.cells(kind))do
     if blocked[cellkey(x+c.x,y+c.y)]then conflict=true end
     for name,xy in pairs(reserved)do if name~=kind and s:count(name)==0 and x+c.x==xy[1] and y+c.y==xy[2]+1 then conflict=true end end
    end
    if not conflict then
     local route=pathTo(s,kind,x,y)
     if route then choices[#choices+1]={x=x,y=y,path=route,score=#route+(.02*(math.abs(x-10)+math.abs(y-9)))}end
    end
   end
  end
 end end
 table.sort(choices,function(a,b)if a.score==b.score then if a.y==b.y then return a.x<b.x end;return a.y<b.y end;return a.score<b.score end)
 return choices[1]
end
local function expandBuild(s,kind)
 local funded=untilTrue(s,function()return s:canAfford(D.buildings[kind].cost)end,7200)
 V.assert(funded,'Real production funds expanded '..kind)
 if not funded then error('Funding stalled '..kind..' '..cjson.encode({elapsed=s.elapsed,stock=s.stock,produced=s.produced,meals=s.mealsServed}))end
 local spot=site(s,kind)
 V.assert(spot~=nil,'A legal connected placement exists for expanded '..kind)
 if not spot then error('No legal placement '..kind)end
 print('V3_PLACEMENT',kind,spot.x,spot.y,#spot.path,cjson.encode(s.stock))
 for _,p in ipairs(spot.path)do build(s,'road',p[1],p[2])end
 local b=build(s,kind,spot.x,spot.y)
 if not b or not b.complete then error('Construction stalled '..kind)end
 V.assert(s:connected(b),'Expanded '..kind..' has real finished-road connection')
 if D.buildings[kind].recipes then V.assert(s:setRecipe(b,1),'Player explicitly orders '..kind..' recipe')end
 local limits={ironmine={'ironore',4},coalmine={'coal',10},goldmine={'goldore',2},tannery={'leather',2},woodweapons={'bow',1},leatherarmor={'leatherarmor',1},ironweapons={'ironspear',1},ironarmor={'ironarmor',1}}
 if limits[kind]then orderPolicies[b.id]={resource=limits[kind][1],target=limits[kind][2]}end
 if kind=='smelter'then
  V.assert(s:setRecipe(b,2),'First smelter order earns two gold ingots before allocating finite coal to iron')
  orderPolicies[b.id]={resource='gold',target=2,thenIron=true}
 end
 local f=File('tests/v3/evidence/'..run..'-progress.json',FILE_WRITE);f:WriteString(cjson.encode(Data.capture(s,1000+s.elapsed,1,true)));f:Close()
 return b
end
local task=coroutine.create(function()
 local f=File('tests/v3/fixtures/earned242_after_failed_endurance.json',FILE_READ);local raw=cjson.decode(f:ReadString());f:Close()
 local s,why=Data.restore(raw,'finite');activeSim=s
 V.assert(s~=nil,'Unaltered earned failure checkpoint restores for one-variable real courier experiment: '..tostring(why))
 local before={stock=Data.capture(s,1000,1,true).world.stock,population=s.population,carriers=#s.carriers,free=s:availableWorkers(),elapsed=s.elapsed,food=s.produced.food,meals=s.mealsServed}
 V.assert(untilTrue(s,function()return s:availableWorkers()>0 end,300),'Wait for a real free resident before courier siting; existing meal reservations remain intact')
 local courier=expandBuild(s,'courier')
 V.assert(courier.complete and #s.carriers==before.carriers+1 and s.population==before.population,'Exactly one genuinely constructed courier adds one carrier using existing residents')
 print('V3_PAID_COURIER',cjson.encode({before=before,after={stock=s.stock,population=s.population,carriers=#s.carriers,free=s:availableWorkers(),elapsed=s.elapsed},building=courier.id}))
 local paid=File('tests/v3/evidence/'..run..'-paid-state.json',FILE_WRITE);paid:WriteString(cjson.encode(Data.capture(s,1000+s.elapsed,1,true)));paid:Close()
 auditStart=s.elapsed;mealAudit={};local startFood,startMeals=s.produced.food,s.mealsServed
 for step=1,18000 do
  tick(s)
  if step%900==0 then
   local halls={};for _,b in ipairs(s.buildings)do if b.kind=='kitchen'then halls[#halls+1]={id=b.id,inputs=b.inputs,mealStock=b.mealStock,buffer=b.buffer,incoming=b.incoming,workers=b.workers,active=b.activeWorkers,timer=b.timer}end end
   print('V3_COURIER_90S',cjson.encode({elapsed=s.elapsed-auditStart,foodProduced=s.produced.food-startFood,meals=s.mealsServed-startMeals,stock=s.stock,halls=halls,free=s:availableWorkers()}))
  end
 end
 local final={elapsed=s.elapsed-auditStart,foodProduced=s.produced.food-startFood,meals=s.mealsServed-startMeals,stock=s.stock,roles=mealAudit}
 local af=File('tests/v3/evidence/'..run..'-role-audit.json',FILE_WRITE);af:WriteString(cjson.encode(final));af:Close()
 local sf=File('tests/v3/evidence/'..run..'-final-state.json',FILE_WRITE);sf:WriteString(cjson.encode(Data.capture(s,1000+s.elapsed,1,true)));sf:Close()
 local recovered=true
 for key,a in pairs(actors(s))do
  local rec=mealAudit[key];local required=not key:find('builder:',1,true) or rec.activeSeconds>900
  if required then
   V.assert(rec.meals>=1 and rec.returned>=1,'Real added-courier experiment gives an actual meal and return to '..key)
   if rec.meals<1 or rec.returned<1 or (a.hunger or 0)>=300 then recovered=false end
  end
 end
 V.assert(recovered,'Single additional genuinely paid courier restores every allocated role below severe hunger without changing other staffing')
 print('V3_COURIER_RESULT',cjson.encode({recovered=recovered,foodProduced=final.foodProduced,meals=final.meals,elapsed=final.elapsed,population=s.population,carriers=#s.carriers,free=s:availableWorkers()}))
end)
for frame=8,900 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end
 local ok,err=coroutine.resume(task)
 if not ok then
  if activeSim then local f=File('tests/v3/evidence/'..run..'-failed-state.json',FILE_WRITE);f:WriteString(cjson.encode(Data.capture(activeSim,1000+activeSim.elapsed,1,true)));f:Close()end
  V.assert(false,'Paid courier experiment: '..tostring(err));V.finish()
 elseif coroutine.status(task)=='dead'then V.finish()end
end)end
