-- Authoritative engine geometry boundary; Forced completion of roads/buildings and
-- ample inventory are explicit fixtures, NOT construction/economic evidence.
local Sim=require 'game.Simulation'
local D=require 'game.Definitions'
local Deposits=require 'game.Deposits'
V.atFrame(8,function()
 local seed=23;for _,arg in ipairs(GetArguments())do if arg:find('7319',1,true)then seed=7319 end end
 local f=File('tests/v3/fixtures/fixed_v3_seed'..seed..'.json',FILE_READ);local plan=cjson.decode(f:ReadString());f:Close()
 local s=Sim.new('finite',plan.seed);s.started=true;s.skipped=true
 s.stock.wood,s.stock.stone=10000,10000
 V.assert(s.map.worldSize==plan.worldSize and s.map.seed==plan.seed,'Geometry plan matches actual new finite map size and seed')
 for _,xy in ipairs(plan.roadBuildOrder)do
  local beforeWood,beforeStone=s.stock.wood,s.stock.stone
  local ok,reason=s:build('road',xy[1],xy[2])
  V.assert(ok,'Engine accepts adjacent free-road geometry in BFS order '..xy[1]..':'..xy[2]..': '..tostring(reason))
  V.assert(s.stock.wood==beforeWood and s.stock.stone==beforeStone,'Actual planned road charges no hidden stone or wood')
  s.pendingRoads={};s.roads[xy[1]..':'..xy[2]]=true;s.roadCount=s.roadCount+1
 end
 local counts,costs={}, {wood=0,stone=0}
 for _,p in ipairs(plan.buildings)do
  if p.kind~='store'then
   local beforeWood,beforeStone=s.stock.wood,s.stock.stone
   local ok,why,b=s:build(p.kind,p.x,p.y)
   V.assert(ok,'Actual engine accepts fixed complete footprint '..p.id..': '..tostring(why))
   local cost=D.buildings[p.kind].cost
   V.assert(s.stock.wood==beforeWood-(cost.wood or 0) and s.stock.stone==beforeStone-(cost.stone or 0),'Actual fixed blueprint deducts its exact one-time cost: '..p.id)
   if not b then error('Rejected fixed building '..p.id)end
   b.complete=true;b.progress=1 -- Explicit geometry-only completion, not labor evidence.
   V.assert(s:connected(b) and s:path(10,9,b.x,b.y+1)~=nil,'Actual engine finds warehouse-to-door route for '..p.id)
   if D.buildings[p.kind].deposit then V.assert(Deposits.stock(s,b,D.buildings[p.kind].deposit)>0,'Fixed resource building reaches its actual finite deposit: '..p.id)end
   if p.kind=='woodcutter'then V.assert(s:treeCount(b,6)>=4,'Fixed logging camp has actual accessible mature woodland')end
   if p.kind=='house'then s.population=s.population+4 end -- Explicit precompleted geometry fixture.
  end
  counts[p.kind]=(counts[p.kind] or 0)+1
  for r in pairs(costs)do costs[r]=costs[r]+(D.buildings[p.kind].cost[r] or 0)end
 end
 local unique=0;for _ in pairs(counts)do unique=unique+1 end
 V.assert(#s.buildings==33 and unique==25 and s.population==34,'Whole fixed geometry fits all 25 facilities and all six houses')
 V.assert(costs.wood==296 and costs.stone==116,'Fixed whole-layout definition costs match 296 wood and 116 stone')
 local totalRoads=0;for _ in pairs(s.roads)do totalRoads=totalRoads+1 end
 V.assert(s.roadCount==#plan.roadBuildOrder and totalRoads==#plan.roads,'Actual road cells contain five original plus declared additions, while roadCount records added network changes')
 print('V3_FIXED_GEOMETRY',cjson.encode({buildings=#s.buildings,counts=counts,costs=costs,roads=s.roadCount,population=s.population}))
 V.finish()
end)
