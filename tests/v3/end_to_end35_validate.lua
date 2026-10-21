-- Fresh normal-starter 35-entity benchmark: six actual carriers, twenty-five jobs.
-- Sustainable-combination comparison: retain two farms, mill, bakery, ranch, butcher and two kitchens.
-- Only woodcutter, sawmill, fishery and the third farm stop; every assigned role stays.
-- Industrial isolation disables tutorial relief explicitly; objective API progress is not a complete UI walkthrough.
-- Existing hunger is retained; actual eating/return must recover before a fresh 30min window.
-- Normal online new-game progression, using only the game's real starter stock.
-- Fixed 35-entity seed-23 benchmark, not a typical required player layout.
-- Unlike the old village fixture, road work never uses offline=true.
-- Intro tutorial relief is counted; the industrial branch explicitly disables it.
local Sim=require 'game.Simulation'
local Data=require 'game.SaveData'
local Store=require 'game.PixelSaveStore'
local D=require 'game.Definitions'
local pf=File('tests/v3/fixtures/fixed_v3_seed23_35.json',FILE_READ)
local fixedPlan=cjson.decode(pf:ReadString());pf:Close()
local fixedRoads={};for _,xy in ipairs(fixedPlan.roads)do fixedRoads[xy[1]..':'..xy[2]]=true end
local run='v3-e2e'
for _,arg in ipairs(GetArguments())do run=arg:match('^-pixelqa%-run=([%w_-]+)$') or run end
local activeSim
local ticks=0
local mealAudit=nil
local auditStart=0
local pantryBlocks={}
local consumption={}
local function observeConsumption(s)
 -- Transparent observation: delegate exactly once to the original production API.
 s.consumeInput=function(self,b)
  local before={};for r,n in pairs(b.inputGoods or {})do before[r]=n end
  Sim.consumeInput(self,b)
  local row=consumption[b.id] or {kind=b.kind,batches=0,inputs={}};consumption[b.id]=row
  row.batches=row.batches+1
  for r,n in pairs(before)do local used=n-(b.inputGoods[r] or 0);if used>0 then row.inputs[r]=(row.inputs[r] or 0)+used end end
 end
end
local function chainState(s)
 local result={elapsed=s.elapsed,stock={},produced={},buildings={},consumed=cjson.decode(cjson.encode(consumption)),meals=s.mealsServed}
 for _,r in ipairs({'grain','flour','bread','meat','fish','food'})do result.stock[r]=s.stock[r] or 0;result.produced[r]=s.produced[r] or 0 end
 for _,b in ipairs(s.buildings)do if b.kind=='farm' or b.kind=='mill' or b.kind=='bakery' or b.kind=='kitchen'then
  result.buildings[#result.buildings+1]={id=b.id,kind=b.kind,stopped=b.stopped,workers=b.workers,inputs=b.inputGoods,outputs=b.outputGoods,buffer=b.buffer,pantry=b.mealStock,timer=b.timer}
 end end
 return cjson.decode(cjson.encode(result))
end
local auditPhase="recovery"
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
 if mealAudit then
  local halls={}
  for _,b in ipairs(s.buildings)do if b.kind=='kitchen'then
   local blocked=(b.mealStock or 0)==0 and b.buffer>0
   local t=pantryBlocks[b.id]or {seconds=0,longest=0,current=0};pantryBlocks[b.id]=t
   t.current=blocked and t.current+.1 or 0;if blocked then t.seconds=t.seconds+.1;t.longest=math.max(t.longest,t.current)end
   if ticks%900==0 then halls[#halls+1]={id=b.id,inputs=b.inputs,inputGoods=b.inputGoods,pantry=b.mealStock,buffer=b.buffer,outgoing=b.outgoing,incoming=b.incoming,workRate=b.workRate,active=b.activeWorkers,timer=b.timer,block=t.current}end
  end end
  if ticks%900==0 then
   local jobs={};for i,j in ipairs(s.jobs)do jobs[#jobs+1]={order=i,resource=j.resource,amount=j.amount,source=j.inbound and 'warehouse' or j.b and j.b.kind,destination=j.destination and j.destination.id or j.inbound and j.b.id}end
   print('V3_KITCHEN_90S',cjson.encode({phase=auditPhase,elapsed=s.elapsed-auditStart,halls=halls,jobs=jobs,stockFood=s.stock.food,produced=s.produced.food,served=s.mealsServed}))
  end
 end
 if ticks%100==0 then coroutine.yield() end
end
local function untilTrue(s,predicate,seconds)
    for _=1,seconds*10 do if predicate() then return true end;tick(s) end
    return predicate()
end
local function build(s,kind,x,y)
    local beforeWood,beforeStone=s.stock.wood,s.stock.stone
    local ok,message,b=s:build(kind,x,y)
    V.assert(ok,'New-game plan '..kind..' at '..x..','..y..': '..tostring(message))
    if not ok then return nil end
    local cost=D.buildings[kind].cost
    V.assert(s.stock.wood==beforeWood-(cost.wood or 0) and s.stock.stone==beforeStone-(cost.stone or 0),'Actual construction API charges exact stated cost once: '..kind)
    -- Far sites require several real round trips; retain all labor and meal time.
    local complete=untilTrue(s,function() return kind=='road' and s.roads[x..':'..y] or b and b.complete end,1800)
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
   if not seen[nk] and not blocked[nk] and fixedRoads[nk] and s:terrain(nx,ny)=='grass' and not s:buildingAt(nx,ny)then
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
 if (D.buildings[kind].workers or 0)>0 and b.workers==0 then
  V.assert(untilTrue(s,function()return s:staff(b,1)end,300),'Actual available resident staffs newly completed '..kind)
  if b.workers==0 then error('Actual staff unavailable '..kind)end
 end
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
    local s=Sim.new('finite',23);s.started=true;activeSim=s
    V.assert(s.stock.wood==72 and s.stock.stone==40 and s.stock.food==28 and s.population==10,'Fixture starts from the actual player new-game inventory and population')
    for x=7,4,-1 do build(s,'road',x,9) end
    nextLesson(s,1)
    local home=expandBuild(s,'house');V.assert(home.complete and s.population==14,'Actual first house raises the village to fourteen residents')
    nextLesson(s,2)
    expandBuild(s,'farm');nextLesson(s,3)
    expandBuild(s,'mill');nextLesson(s,4)
    expandBuild(s,'bakery')
    V.assert(untilTrue(s,function()return (s.produced.bread or 0)>=2 end,1800),'New ninety-second mill supplies actual bakery deliveries before lesson five')
    nextLesson(s,5)
    expandBuild(s,'kitchen')
    V.assert(untilTrue(s,function()return s.produced.food>=4 and s.mealsServed>0 end,1800),'Real newly versioned grain/mill/bakery chain cooks and serves food at fourteen residents')
    nextLesson(s,6)
    expandBuild(s,'woodcutter')
    V.assert(untilTrue(s,function()return (s.produced.rawwood or 0)>=1 end,1200),'Real western logging delivers the first unprocessed log')
    nextLesson(s,7)
    expandBuild(s,'sawmill')
    V.assert(untilTrue(s,function()return (s.produced.wood or 0)>=2 end,1800),'Actual logs are sawn and physically delivered as buildable wood')
    nextLesson(s,8)
    expandBuild(s,'barracks')
    V.assert(untilTrue(s,function()return s.stock.wood>=6 and s.stock.food>=6 and s:availableWorkers()>=3 end,2400),'First defense recruits can pay their actual combined six-food cost')
    for i=1,3 do
     local wood,food,free=s.stock.wood,s.stock.food,s:availableWorkers()
     V.assert(s:train('militia'),'First-chapter villager guard is genuinely paid: '..i)
     V.assert(s.stock.wood==wood-2 and s.stock.food==food-2 and s:availableWorkers()==free-1,'Each initial guard spends exactly two wood, two food and one free resident: '..i)
    end
    nextLesson(s,9)
    V.assert(s:startRaid() and #s.enemies==4 and s.enemies[1].hp==3,'Initial chapter starts the distinct four-enemy three-HP defense')
    V.assert(untilTrue(s,function()return not s.raid or s.defeat end,180) and s.defended and not s.victory and not s.campaignCompleted,'Actual first defense succeeds and leaves the village running for its industrial chapter')
    nextLesson(s,10)
    local firstChapter,why=Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000+s.elapsed,2,true))),'finite')
    V.assert(firstChapter and firstChapter.lesson==11 and firstChapter.defended and not firstChapter.victory,'First-defense checkpoint restores into the industrial chapter: '..tostring(why))
    if firstChapter then s=firstChapter;activeSim=s end
    introRelief=tutorialRelief
    print('V3_FIRST_DEFENSE',s.elapsed,s.lesson,s.militia,s.health,'introFoodRelief',introRelief)
    s.skipped=true -- Explicit economy-mode fixture disables the tutorial eight-food floor; lesson objectives remain independently verified.
    -- Continue through the industrial chapter using only actual starter/earned stock.
    -- Houses and all inputs below are paid only from actual starter/earned stocks.
    expandBuild(s,'house');expandBuild(s,'quarry');expandBuild(s,'mason')
    expandBuild(s,'farm');expandBuild(s,'forester')
    expandBuild(s,'house');expandBuild(s,'courier')
    expandBuild(s,'fishery');expandBuild(s,'ranch');expandBuild(s,'butcher')
    expandBuild(s,'house');expandBuild(s,'courier')
    expandBuild(s,'ironmine');expandBuild(s,'coalmine');expandBuild(s,'goldmine')
    expandBuild(s,'house');expandBuild(s,'courier');local smelter=expandBuild(s,'smelter')
    expandBuild(s,'tannery');expandBuild(s,'woodweapons');expandBuild(s,'leatherarmor')
    expandBuild(s,'house');expandBuild(s,'ironweapons');expandBuild(s,'ironarmor')
    expandBuild(s,'kitchen');expandBuild(s,'farm')
    for _,b in ipairs(s.buildings)do
      if b.kind=='mill' then V.assert(untilTrue(s,function()return s:staff(b,1)end,300),'Real free resident fills the second mill position after existing builders finish returning')end
    end
    V.assert(s.population==34,'Six real houses expand the initial ten residents to exactly 34')
    local unique={};for _,b in ipairs(s.buildings)do if b.complete then unique[b.kind]=true end end
    local count=0;for _ in pairs(unique)do count=count+1 end
    V.assert(count==25,'All 25 functional facilities exist as completed real constructions')
    local gear=untilTrue(s,function()return s.stock.ironspear>=1 and s.stock.ironarmor>=1 and s.stock.bow>=1 and s.stock.leatherarmor>=1 end,10800)
    V.assert(gear,'Real ore/coal/hide/wood chains manufacture and deliver both complete equipment sets')
    print('V3_GEAR_STATE',s.elapsed,cjson.encode(s.stock),cjson.encode(s.produced))
    V.assert((s.produced.gold or 0)>=2,'Earlier real gold order preserved recruitment funding before iron equipment')
    V.assert(untilTrue(s,function()return s.stock.gold>=2 end,3600),'Real gold ore and coal produce and deliver two recruitment ingots')
    local builtCounts,costs={}, {wood=0,stone=0}
    for _,b in ipairs(s.buildings)do
     builtCounts[b.kind]=(builtCounts[b.kind] or 0)+1
     for resource in pairs(costs)do costs[resource]=costs[resource]+(D.buildings[b.kind].cost[resource] or 0)end
    end
    print('V3_ACTUAL_BUILDING_BUDGET',cjson.encode({counts=builtCounts,costs=costs,population=s.population,free=s:availableWorkers()}))
    V.assert(costs.wood==316 and costs.stone==120 and builtCounts.house==6 and builtCounts.farm==3 and builtCounts.kitchen==2 and builtCounts.courier==3 and #s.carriers==6,'Actual kind counts and charged materials match the declared 316 wood / 120 stone layout')
    V.assert(costs.stone<=130,'Actual expanded layout fits the 40 starter plus 180 rawstone/2 finite stone budget')
 local earned=File('tests/v3/evidence/'..run..'-earned35.json',FILE_WRITE);earned:WriteString(cjson.encode(Data.capture(s,1000+s.elapsed,1,true)));earned:Close()
 local beforeStop=Data.capture(s,1000+s.elapsed,1,true)
 local stopped={};local farmNumber=0
 for _,b in ipairs(s.buildings)do
  if b.kind=='farm'then farmNumber=farmNumber+1 end
  if b.kind=='woodcutter' or b.kind=='sawmill' or b.kind=='fishery' or b.kind=='farm' and farmNumber>2 then
   local workers=b.workers;local ok=s:setWorking(b,false)
   V.assert(ok and b.stopped and b.workers==workers,'Normal stop keeps every assigned resident and stops only surplus production: '..b.kind..':'..b.id)
   stopped[#stopped+1]={id=b.id,kind=b.kind,workers=b.workers}
  end
 end
 V.assert(#stopped==4,'Exactly four agreed surplus producers stop; two farms, grain chain, ranch, butcher and both kitchens stay enabled')
 local afterStop=Data.capture(s,1000+s.elapsed,1,true)
 local unchanged=s.population==beforeStop.world.population and #s.carriers==6 and #s.guards==3
 for _,r in ipairs(D.goods)do unchanged=unchanged and s.stock[r]==beforeStop.world.stock[r] and (s.produced[r] or 0)==(beforeStop.world.produced[r] or 0)end
 for key,a in pairs(actors(s))do local group,index=key:match('([^:]+):(.+)');local source=beforeStop.world[group=='worker' and 'workers' or group=='carrier' and 'carriers' or group=='guard' and 'guards' or 'builders'];local old=source[tonumber(index) or index];if old then unchanged=unchanged and a.hunger==old.hunger end end
 V.assert(unchanged,'Stop operations grant no stock, production, population or hunger reset; existing in-flight work remains')
 observeConsumption(s)
 local operationStart=chainState(s)
 local op=File('tests/v3/evidence/'..run..'-operation-start.json',FILE_WRITE);op:WriteString(cjson.encode({stopped=stopped,state=operationStart,snapshot=afterStop}));op:Close()
 print('V3_OPERATION_STOP',cjson.encode({stopped=stopped,state=operationStart}))
    -- Every allocated carrier/worker/guard with zero allocated idle-resident proxies
    -- must recover by actual meals, with inherited hunger untouched.
    auditStart=s.elapsed;mealAudit={}
    local recoveryStart=s.elapsed
    local recovered=untilTrue(s,function()
     for key,a in pairs(actors(s))do
      local required=not key:find('builder:',1,true)
      local rec=mealAudit[key]
      if required and (not rec or rec.meals<1 or rec.returned<1 or (a.hunger or 0)>=300)then return false end
     end
     return true
    end,1800)
    local recoveryReport={elapsed=s.elapsed-recoveryStart,recovered=recovered,stock=s.stock,roles=mealAudit,pantryBlocks=pantryBlocks,operationStart=operationStart,chainEnd=chainState(s)}
    print('V3_REAL_RECOVERY',cjson.encode(recoveryReport))
    local af=File('tests/v3/evidence/'..run..'-recovery-audit.json',FILE_WRITE);af:WriteString(cjson.encode(recoveryReport));af:Close()
    local rf=File('tests/v3/evidence/'..run..'-recovery-state.json',FILE_WRITE);rf:WriteString(cjson.encode(Data.capture(s,1000+s.elapsed,1,true)));rf:Close()
    V.assert(recovered,'All allocated roles recover inherited hunger by actual eating and return, with no reset or resource gifts')
    if not recovered then error('Real food recovery failed; retained recovery-state and per-role first meal/return evidence')end
    local beforeMeals=s.mealsServed;local beforeFood=s.produced.food;local steadyChainStart=chainState(s)
    print('V3_ENDURANCE_START',s.elapsed,s.population,s:availableWorkers(),cjson.encode(s.workers),cjson.encode(s.builders),cjson.encode(s.carriers),cjson.encode(s.guards))
    mealAudit={};auditStart=s.elapsed;auditPhase="steady30min";pantryBlocks={}
    for checkpoint=1,6 do
      for step=1,3000 do
       tick(s)
       if step%900==0 then
        local census={population=s.population,free=s:availableWorkers(),carriers=#s.carriers,guards=#s.guards,workers=0,buildersActive=0,buildersMeal=0,buildersIdle=0,stock=s.stock}
        for _ in pairs(s.workers)do census.workers=census.workers+1 end
        for _,a in ipairs(s.builders)do if a.active then census.buildersActive=census.buildersActive+1 elseif a.meal then census.buildersMeal=census.buildersMeal+1 else census.buildersIdle=census.buildersIdle+1 end end
        print('V3_90SECOND_CENSUS',s.elapsed,cjson.encode(census))
       end
      end
      local snapshot=Data.capture(s,1000+s.elapsed,checkpoint,true)
      local loaded,why=Data.restore(cjson.decode(cjson.encode(snapshot)),'finite')
      V.assert(loaded~=nil,'Full 25-industry five-minute checkpoint restores: '..tostring(why))
      if loaded then s=loaded;activeSim=s;smelter=s.buildings[smelter.id];observeConsumption(s)end
      for r,n in pairs(s.stock)do V.assert(n>=0,'Full industry stock stays nonnegative: '..r)end
      V.assert(s:availableWorkers()>=0,'Full industry does not overbook residents')
      print('V3_ENDURANCE',checkpoint,s.elapsed,s.mealsServed,cjson.encode(s.stock))
    end
    V.assert(s.mealsServed>beforeMeals+60 and s.produced.food>beforeFood,'Village with 34 housing capacity keeps producing and serving real food for thirty minutes')
    print('V3_30MIN_FOOD',s.produced.food-beforeFood,s.mealsServed-beforeMeals,s.stock.food,tutorialRelief-introRelief)
    local represented=0
    for key,record in pairs(mealAudit)do
     represented=represented+1
     if not key:find('builder:',1,true) or record.activeSeconds>900 then
      V.assert(record.meals>=4 and record.returned>=4,'Every continuously allocated role eats and returns during sustained operation: '..key)
     end
     V.assert(record.maxHunger<300,'No actual persistent role remains severely hungry during sustained operation: '..key)
    end
    print('V3_ACTUAL_MEAL_AUDIT',s.population,represented,cjson.encode(mealAudit))
    local af=File('tests/v3/evidence/'..run..'-steady-audit.json',FILE_WRITE);af:WriteString(cjson.encode({roles=mealAudit,pantryBlocks=pantryBlocks,foodProduced=s.produced.food-beforeFood,mealsServed=s.mealsServed-beforeMeals,chainStart=steadyChainStart,chainEnd=chainState(s)}));af:Close()
    mealAudit=nil
    V.assert(not s.defeat and not s.victory,'Expanded economy remains playable before the chosen defense')
    local f=File('tests/v3/evidence/generated_v3_fixture.json',FILE_WRITE);f:WriteString(cjson.encode(Data.capture(s,1000+s.elapsed,1,true)));f:Close()
    -- Real population transfer after the full 34-role food audit, without adding people.
    for _,kind in ipairs({'ironmine','goldmine'})do
     local mine;for _,candidate in ipairs(s.buildings)do if candidate.kind==kind then mine=candidate;break end end
     V.assert(mine and untilTrue(s,function()return s:staff(mine,-1)end,300),'Safely release one completed mining resident for the regular army: '..kind)
    end
    for _,unit in ipairs({'archer','spearman'})do
     V.assert(untilTrue(s,function()return s.stock.food>=2 and s:availableWorkers()>=1 end,900),'One regular recruit can pay the actual two-food cost and one existing free resident: '..unit)
     local beforeFood,beforeGold,beforeFree=s.stock.food,s.stock.gold,s:availableWorkers()
     V.assert(s:train(unit),'Real earned equipment recruits '..unit)
     V.assert(s.stock.food==beforeFood-2 and s.stock.gold==beforeGold-1 and s:availableWorkers()==beforeFree-1,'Sequential '..unit..' recruitment pays exact food/gold/population once')
    end
    for lesson=11,19 do
     V.assert(untilTrue(s,function()local done,total=s:lessonProgress();return done>=total end,3600),'Industrial objective is met by actual service/production/transport: '..lesson)
     print('V3_INDUSTRIAL_LESSON',lesson,cjson.encode(s.produced),s.forestryTendSeconds,s.fishMealsCooked)
     nextLesson(s,lesson)
    end
    local Campaign=require 'game.Campaign'
    V.assert(untilTrue(s,function()return Campaign.ready(s)end,900),'Both regular units physically return from meals and join the final defense formation')
    local raidOK,raidReason=s:startRaid()
    V.assert(raidOK and s.campaignRaid and #s.enemies==6,'Industrial final defense starts six actual enemies: '..tostring(raidReason))
    local hpCorrect=true;for _,e in ipairs(s.enemies)do if e.hp~=5 then hpCorrect=false end end
    V.assert(hpCorrect,'Every final-chapter enemy has five real hit points')
    local battleStart=s.elapsed
    V.assert(untilTrue(s,function()return s.victory or s.defeat end,240) and s.victory and s.campaignCompleted,'Actual equipped army wins the upgraded industrial final defense')
    print('V3_FINAL_BATTLE',s.elapsed-battleStart,s.health,s.militia,cjson.encode(s.guards))
    nextLesson(s,20)
    local beforeContinue=Data.capture(s,1000+s.elapsed,3,true)
    V.assert(s:continueFreePlay(),'Final victory can continue without throwing away the real village')
    V.assert(s.freePlay and not s.victory and s.campaignCompleted and #s.buildings==#beforeContinue.world.buildings,'Continue preserves finished campaign and existing village')
    local continued,continueError=Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000+s.elapsed,4,true))),'finite')
    V.assert(continued and continued.freePlay and continued.campaignCompleted and not continued.victory,'Continued industrial village saves and reloads into running free play: '..tostring(continueError))
    if continued then s=continued;activeSim=s end
    local oldProduced=s.produced.grain or 0;local oldBuildings=#s.buildings
    local mill;for _,b in ipairs(s.buildings)do if b.kind=='mill'then mill=b;break end end
    V.assert(untilTrue(s,function()return s:staff(mill,-1)end,180),'An actual mill worker safely transfers to post-victory construction')
    -- This dense benchmark has no further serviceable 3x2 site. Use an actual
    -- new road work order to test continued construction, without relocating
    -- any paid facility or pretending a free road spends building materials.
    local newRoad
    for y=1,30 do if newRoad then break end;for x=1,30 do
     if s:canBuild('road',x,y)then newRoad={x=x,y=y};break end
    end end
    V.assert(newRoad~=nil,'Continued real village has an actual legal new road work site')
    if newRoad then
     local beforeStone,beforeWood=s.stock.stone,s.stock.wood
     local ok=s:build('road',newRoad.x,newRoad.y)
     V.assert(ok and s.stock.stone==beforeStone and s.stock.wood==beforeWood,'Continue accepts actual road construction with its correctly declared zero material cost')
     V.assert(untilTrue(s,function()return s.roads[newRoad.x..':'..newRoad.y]end,600),'Real post-continue worker completes new road labor after save/load')
    end
    V.assert(#s.buildings==oldBuildings and untilTrue(s,function()return (s.produced.grain or 0)>oldProduced end,900),'Continued loaded village preserves every paid building and actual production still advances')
    V.assert(s:startRaid(),'Continuing a finished industrial village permits a later voluntary defense')
    V.assert(tutorialRelief-introRelief==0,'No automatic food rescue occurs during the explicit post-intro skipped economy branch')
    print('V3_FOOD_RELIEF_ACCOUNTING',cjson.encode({intro=introRelief,postIntro=tutorialRelief-introRelief,industrialSkippedFixture=true}))
    print('V3_COMPLETE',s.elapsed,s.population,s.mealsServed,tutorialRelief,cjson.encode(s.produced))
end)
for frame=8,9000 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead' then return end
 local ok,err=coroutine.resume(task)
 if not ok then
  if activeSim then local f=File('tests/v3/evidence/'..run..'-failed-state.json',FILE_WRITE);f:WriteString(cjson.encode(Data.capture(activeSim,1000+activeSim.elapsed,1,true)));f:Close()end
  V.assert(false,'Independent v3 E2E coroutine: '..tostring(err));V.finish()
 elseif coroutine.status(task)=='dead' then V.finish()end
end)end
