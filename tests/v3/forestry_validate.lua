-- Independent ecology boundary suite; controlled tree-event fixtures are explicit.
-- Real chopping/whole-economy sustainability are separate end-to-end tests.
local Sim=require 'game.Simulation'
local Data=require 'game.SaveData'
local F=require 'game.Forestry'
local Offline=require 'game.Offline'
local ticks=0
local function pulse(s,dt,whole)
 if whole then s:update(dt)else F.update(s,dt)end
 ticks=ticks+1;if ticks%100==0 then coroutine.yield()end
end
local function advance(s,seconds,whole)
 for _=1,math.floor(seconds*10+.5)do pulse(s,.1,whole)end
end
local function fixture(x,y)
 local s=Sim.new('finite',23);s.started=true;s.skipped=true
 V.assert(s:standingTree(x,y),'Ecology fixture starts on a real original mature forest tree')
 s.felledTrees[x..':'..y]=true;s.timber=0;F.fell(s,x,y)
 return s,x..':'..y
end
local function roundtrip(s)
 return Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000,1,true))),'finite')
end
local task=coroutine.create(function()
 V.assert(F.stumpSeconds==180 and F.growthSeconds==540,'Locked natural ecology parameters are 180 plus 540 seconds')
 local s,k=fixture(2,5)
 advance(s,179.9)
 V.assert(s.treeGrowth[k].phase=='stump' and not s:standingTree(2,5),'179.9 seconds still shows a non-harvestable stump')
 pulse(s,.1)
 V.assert(s.treeGrowth[k].phase=='sapling' and math.abs(s.treeGrowth[k].age)<.00001,'At 180 seconds the stump becomes a zero-age sapling')
 V.assert(not s:standingTree(2,5) and (s.produced.rawwood or 0)==0,'A sapling is not a mature tree and has produced no rawwood')
 advance(s,539.9)
 V.assert(s.treeGrowth[k] and s.treeGrowth[k].phase=='sapling' and not s:standingTree(2,5),'719.9 seconds remains non-harvestable')
 pulse(s,.1)
 V.assert(not s.treeGrowth[k] and not s.felledTrees[k] and s:standingTree(2,5),'At 720 seconds the same original tree becomes harvestable again')
 V.assert(s.timber==1 and s.stock.rawwood==0 and s.stock.wood==72,'Maturity restores one tree allowance, never grants physical rawwood or construction wood')
 advance(s,30)
 V.assert(s.timber==1 and s.regrownTrees==1,'Continuing after maturity cannot repeatedly grant tree allowance')
 for _,phase in ipairs({'stump','sapling'})do
  local q,qk=fixture(2,5);advance(q,phase=='stump' and 95 or 420)
  local before=q.treeGrowth[qk];local p,a=before.phase,before.age
  local r,err=roundtrip(q);V.assert(r~=nil,'Ecology phase restores: '..phase..' '..tostring(err))
  if r then
   V.assert(r.treeGrowth[qk].phase==p and math.abs(r.treeGrowth[qk].age-a)<.00001,'Phase and partial age are preserved, not reset: '..phase)
   local second=roundtrip(r);V.assert(second and second.treeGrowth[qk].phase==p and math.abs(second.treeGrowth[qk].age-a)<.00001,'Repeated restore does not advance or duplicate ecology: '..phase)
  end
 end
 local online,okey=fixture(2,5);local offline,fkey=fixture(2,5)
 advance(online,400)
 local elapsed=offline.elapsed
 local settlement=Offline.new(offline,1000,1400,true)
 while not settlement:step(100)do coroutine.yield()end
 V.assert(offline.elapsed==elapsed,'Offline ecology does not advance the frozen combat/survival clock')
 V.assert(offline.treeGrowth[fkey].phase==online.treeGrowth[okey].phase and math.abs(offline.treeGrowth[fkey].age-online.treeGrowth[okey].age)<.0001,'400 seconds of online ecology and actual offline settlement reach the same phase and age')
 local blocked,bk=fixture(2,5);advance(blocked,710);blocked.roads[bk]=true
 advance(blocked,20)
 V.assert(not blocked:standingTree(2,5) and blocked.treeGrowth[bk] and blocked.treeGrowth[bk].phase=='stump' and blocked.treeGrowth[bk].age==0,'Road occupation cancels near-mature growth instead of pausing it at the finish line')
 local loaded=roundtrip(blocked)
 V.assert(not loaded or (loaded.treeGrowth[bk].age==0 and not loaded:standingTree(2,5)),'Invalid occupied-forest fixture is rejected or remains suppressed after restore')
 blocked.roads[bk]=nil;advance(blocked,10)
 V.assert(blocked.treeGrowth[bk].phase=='stump' and math.abs(blocked.treeGrowth[bk].age-10)<.0001,'Releasing occupied ground starts from a fresh stump age')
 local invalid=Sim.new('finite',23);invalid.started=true
 for _,xy in ipairs({{10,10},{20,8}})do
  local ik=xy[1]..':'..xy[2];invalid.felledTrees[ik]=true;F.fell(invalid,xy[1],xy[2]);advance(invalid,721)
  V.assert(not invalid:standingTree(xy[1],xy[2]),'Ordinary grass/water cannot grow a mature tree')
 end
 for _,obstacle in ipairs({'building','blueprint','planned-road'})do
  local z,zk=fixture(2,5);advance(z,710)
  if obstacle=='planned-road'then z.roadPlanIndex[zk]={x=2,y=5,progress=0}
  else z.buildingIndex[zk]={complete=obstacle=='building'}end
  advance(z,20)
  V.assert(z.treeGrowth[zk].cancelled and z.treeGrowth[zk].age==0 and not z:standingTree(2,5),'Ecology cancels maturity under controlled '..obstacle..' occupancy')
 end
 local care,ck=fixture(3,5)
 for _,xy in ipairs({{8,8},{8,7},{8,6},{8,5},{7,5},{6,5},{7,9},{6,9}})do care.roads[xy[1]..':'..xy[2]]=true end
 care.roadCount=0;for _ in pairs(care.roads)do care.roadCount=care.roadCount+1 end
 local b=care:addBuilding('forester',6,4,true);b.workers=1
 local second=care:addBuilding('forester',6,8,true);second.workers=1
 local reached=false
 for _=1,600 do
  pulse(care,.1,true)
  local a=care.workers[b.id..':1']
  if a and a.forestryPhase=='tend' then reached=true;break end
 end
 V.assert(reached,'A real assigned forester walks to the tree before providing care')
 if reached then
  local age=care.treeGrowth[ck].age;pulse(care,.1)
  V.assert(math.abs(care.treeGrowth[ck].age-age-.2)<.0001,'A forester actually at the target advances stump age at exactly 2x')
  local claims=0;for _,a in pairs(care.workers)do if a.forestryTarget==ck then claims=claims+1 end end
  V.assert(claims==1,'Two available forestry buildings do not duplicate the same claimed tree task')
  local actor=care.workers[b.id..':1'];actor.meal={phase='eat'}
  age=care.treeGrowth[ck].age;pulse(care,.1)
  V.assert(math.abs(care.treeGrowth[ck].age-age-.1)<.0001,'Forester eating reverts tree growth to the natural 1x rate')
  actor.meal=nil;care.treeGrowth[ck].phase='sapling';care.treeGrowth[ck].age=0
  pulse(care,.1)
  V.assert(math.abs(care.treeGrowth[ck].age-.2)<.0001,'Actual care also applies 2x to the sapling stage')
  local saved,why=roundtrip(care)
  V.assert(saved~=nil,'Actually tending forester and target roundtrip together: '..tostring(why))
  if saved then
   local a=saved.workers[b.id..':1'];local before=saved.treeGrowth[ck].age
   pulse(saved,.1)
   V.assert(a and a.forestryTarget==ck and math.abs(saved.treeGrowth[ck].age-before-.2)<.0001,'Restored actual care continues once without losing or duplicating the target')
  end
  V.assert(care:setWorking(b,false),'Actual pause-work API pauses the forestry building')
  age=care.treeGrowth[ck].age;pulse(care,.1)
  V.assert(math.abs(care.treeGrowth[ck].age-age-.1)<.0001 and actor.forestryPhase=='return','Stopping actual forestry immediately returns to natural rate and sends the worker home')
  care:setWorking(b,true)
  local returned=false
  local tendingActor,tendingBuilding
  for _=1,600 do
   pulse(care,.1,true)
   for _,candidate in pairs(care.workers)do
    if candidate.forestryTarget==ck and candidate.forestryPhase=='tend'then returned=true;tendingActor=candidate;tendingBuilding=care.buildings[candidate.building];break end
   end
   if returned then break end
  end
  print('FORESTRY_RESUME_ACTUAL',cjson.encode({first=care.workers[b.id..':1'],second=care.workers[second.id..':1'],tree=care.treeGrowth[ck]}))
  V.assert(returned,'A legitimate forester resumes actual care after the first worker returns; the second may take the released claim')
  if returned then
   care.roads[tendingBuilding.x..':'..(tendingBuilding.y+1)]=nil;care.roadCount=care.roadCount-1
   age=care.treeGrowth[ck].age;pulse(care,.1)
   V.assert(math.abs(care.treeGrowth[ck].age-age-.1)<.0001,'Disconnecting the real doorway cancels acceleration immediately')
  end

 end
end)
for frame=8,700 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end
 local ok,err=coroutine.resume(task)
 if not ok then V.assert(false,'Ecology coroutine: '..tostring(err));V.finish()
 elseif coroutine.status(task)=='dead'then V.finish()end
end)end
