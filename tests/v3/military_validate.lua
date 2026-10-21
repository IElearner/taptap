-- Isolated cost/rejection tests. These stock fixtures are NOT E2E earned gear.
local Sim=require 'game.Simulation'
local Data=require 'game.SaveData'
local D=require 'game.Definitions'
local M=require 'game.Military'
local function setup()
 local s=Sim.new('finite',23);s.started=true;s.skipped=true
 s:addBuilding('barracks',13,8,true);s.roads['13:9']=true;s.roadCount=s.roadCount+1
 return s
end
V.atFrame(8,function()
 for _,unit in ipairs({'archer','spearman'})do
  local cost=M.units[unit].cost;local s=setup()
  for _,resource in ipairs(D.goods)do s.stock[resource]=0 end
  for resource,n in pairs(cost)do s.stock[resource]=n end
  local free,pop=s:availableWorkers(),s.population
  local ok,msg=s:train(unit);V.assert(ok,'Explicit equipped unit training succeeds: '..unit..' '..tostring(msg))
  V.assert(s.militia==1 and #s.guards==1 and s.guards[1].unit==unit,'Training creates one real guard of the requested unit type: '..unit)
  V.assert(s.population==pop and s:availableWorkers()==free-1,'Training allocates exactly one existing free resident: '..unit)
  for resource in pairs(cost)do V.assert(s.stock[resource]==0,'Training consumes exact declared cost: '..unit..' '..resource)end
  for resource,n in pairs(M.units[unit].equipment)do V.assert(s.guards[1].equipment[resource]==n,'Actual guard carries its unique consumed equipment: '..unit..' '..resource)end
  local r,err=Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000,1,true))),'finite')
  V.assert(r and #r.guards==1 and r.guards[1].unit==unit,'Equipped guard survives real save/load: '..unit..' '..tostring(err))
  if r then for resource,n in pairs(M.units[unit].equipment)do V.assert(r.guards[1].equipment[resource]==n and r.stock[resource]==0,'Reload does not duplicate equipped inventory: '..unit..' '..resource)end end
  for missing in pairs(cost)do
   local poor=setup();for _,resource in ipairs(D.goods)do poor.stock[resource]=0 end
   for resource,n in pairs(cost)do poor.stock[resource]=n end;poor.stock[missing]=cost[missing]-1
   local before=cjson.encode(poor.stock);local available=poor:availableWorkers()
   local trained,reason=poor:train(unit)
   V.assert(not trained and type(reason)=='string' and #reason>0,'Missing ingredient rejects equipped training with feedback: '..unit..' '..missing)
   V.assert(cjson.encode(poor.stock)==before and poor.militia==0 and #poor.guards==0 and poor:availableWorkers()==available,'Rejected equipped training is atomic: '..unit..' '..missing)
  end
 end
end)
V.atFrame(28,function()V.finish()end)
