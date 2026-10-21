-- Isolated ecology/logistics fixture, not an earned-resource economy.
-- Connected completed buildings and 500 food are provided only as scaffolding.
-- All felling, tree aging, worker travel, log delivery and sawing use full updates.
local Sim=require 'game.Simulation'
local Data=require 'game.SaveData'
local run='forest-real-cycles'
for _,arg in ipairs(GetArguments())do run=arg:match('^-pixelqa%-run=([%w_-]+)$')or run end
local ticks=0
local function tick(s)
 s:update(.1);ticks=ticks+1;if ticks%100==0 then coroutine.yield()end
end
local task=coroutine.create(function()
 local s=Sim.new('finite',23);s.started=true;s.skipped=true;s.stock.food=500
 local roads={}
 for x=13,17 do roads[#roads+1]={x,9}end
 for y=10,14 do roads[#roads+1]={17,y}end
 for y=10,13 do roads[#roads+1]={8,y}end
 roads[#roads+1]={7,13}
 for _,p in ipairs(roads)do
  V.assert(s:terrain(p[1],p[2])=='grass','Scaffold road lies on actual grass')
  s.roads[p[1]..':'..p[2]]=true
 end
 s.roadCount=#roads
 V.assert(s:canBuild('woodcutter',17,8),'Controlled camp uses a legal original-world site')
 local camp=s:addBuilding('woodcutter',17,8,true);camp.workers=1
 V.assert(s:canBuild('sawmill',16,13),'Controlled sawmill uses a legal original-world site')
 local saw=s:addBuilding('sawmill',16,13,true);saw.workers=1
 s.roads['16:14']=true;s.roadCount=s.roadCount+1
 local hall=s:addBuilding('kitchen',7,12,true);hall.workers=0
 V.assert(s:connected(camp) and s:connected(saw) and s:connected(hall),'Actual road graph connects the two-tree camp, sawmill and meal hall')
 V.assert(s:treeCount(camp,6)==2,'The original eastern forest has exactly two eligible mature trees')
 local events,history,previous={}, {}, {}
 local completed=false
 for step=1,30000 do
  tick(s)
  local keys={}
  for k in pairs(previous)do keys[k]=true end
  for k in pairs(s.felledTrees)do keys[k]=true end
  for k in pairs(keys)do
   local fallen=s.felledTrees[k]==true
   local row=history[k]or {cuts=0,regrowths=0};history[k]=row
   if fallen and not previous[k]then
    row.cuts=row.cuts+1;row.lastCut=s.elapsed
    local a=s.workers[camp.id..':1']
    V.assert(a and a.treeX..':'..a.treeY==k and a.loadAmount==1 and a.woodPhase=='felling','Every observed tree fall comes from the real assigned logger and creates exactly one log')
    events[#events+1]={kind='cut',key=k,time=s.elapsed,count=row.cuts,phase=a and a.woodPhase,amount=a and a.loadAmount}
   elseif not fallen and previous[k]then
    row.regrowths=row.regrowths+1
    V.assert(s.elapsed-row.lastCut>=719.9 and s.elapsed-row.lastCut<=720.1,'The same harvested tree waits the full natural 720 seconds before maturity')
    events[#events+1]={kind='mature',key=k,time=s.elapsed,count=row.regrowths,wait=s.elapsed-row.lastCut}
   end
   previous[k]=fallen
   if row.cuts>=3 and row.regrowths>=2 then completed=true end
  end
  if step==10000 then
   local restored,why=Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000+s.elapsed,1,true))),'finite')
   V.assert(restored~=nil,'Real partially renewed logging loop survives JSON restore: '..tostring(why))
   if restored then s=restored;camp=s.buildings[camp.id];saw=s.buildings[saw.id];hall=s.buildings[hall.id]end
  end
  if completed and (s.produced.wood or 0)>=8 then break end
 end
 V.assert(completed,'One original tree completes at least two full real felling/regrowth/reharvest cycles')
 V.assert((s.produced.rawwood or 0)>=4 and (s.produced.wood or 0)>=8,'Actually harvested logs are transported, sawn and delivered as construction wood')
 local report={elapsed=s.elapsed,history=history,events=events,stock=s.stock,produced=s.produced,regrownTrees=s.regrownTrees}
 print('V3_REAL_FOREST_CYCLES',cjson.encode(report))
 local f=File('tests/v3/evidence/'..run..'-cycles.json',FILE_WRITE);f:WriteString(cjson.encode(report));f:Close()
end)
for frame=8,330 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end
 local ok,why=coroutine.resume(task)
 if not ok then V.assert(false,'Real forest cycles: '..tostring(why));V.finish()
 elseif coroutine.status(task)=='dead'then V.finish()end
end)end
