-- Controlled complete-building fixture fills all ten original resident slots.
-- No population, food or worker is gifted; the initial 28 meals fund the test.
local Sim=require 'game.Simulation'
local Data=require 'game.SaveData'
local paidRestore=false
local s,minFree,builderMeals,maxConsumers= nil,0,0,0
local seen={}
V.atFrame(8,function()
 s=Sim.new('finite',23);s.started=true;s.skipped=true
 for _,xy in ipairs({{7,9},{13,9},{8,10},{8,11},{8,12},{8,13},{7,13},{11,10},{11,11},{11,12},{11,13},{12,13},{13,13}})do s.roads[xy[1]..':'..xy[2]]=true end
 s.roadCount=0;for _ in pairs(s.roads)do s.roadCount=s.roadCount+1 end
 local a=s:addBuilding('kitchen',7,8,true);a.workers=1
 a=s:addBuilding('farm',13,8,true);a.workers=2
 a=s:addBuilding('farm',7,12,true);a.workers=2
 a=s:addBuilding('mill',13,12,true);a.workers=0
 V.assert(s.population==10 and s:availableWorkers()==2,'Three carriers and five actual positions leave exactly two original residents free')
end)
for frame=9,32 do V.atFrame(frame,function()
 for _=1,50 do
  s:update(.1);minFree=math.min(minFree,s:availableWorkers())
  local consumers=#s.carriers+#s.guards
  for _ in pairs(s.workers)do consumers=consumers+1 end
  for i,a in ipairs(s.builders)do
   if a.active or a.meal then consumers=consumers+1 end
   if a.meal and a.meal.phase=='eat' and not seen[i]then seen[i]=true;builderMeals=builderMeals+1 end
  end
  maxConsumers=math.max(maxConsumers,consumers)
  if not paidRestore then
   for i,a in ipairs(s.builders)do if a.meal and a.meal.phase=='eat' then
    local beforeFood=s.stock.food
    local restored,why=Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000+s.elapsed,1,true))),'finite')
    V.assert(restored and restored.builders[i].meal and restored.builders[i].meal.phase=='eat','An actually paid idle resident meal survives save/load: '..tostring(why))
    V.assert(restored and restored.stock.food==beforeFood and restored:availableWorkers()>=0,'Restoring a paid meal neither charges twice nor invents an extra resident')
    if restored then s=restored end;paidRestore=true;break
   end end
  end
 end
end)end
V.atFrame(33,function()
 local hungrySlots=0
 for _,a in ipairs(s.builders)do if (a.hunger or 0)>1 then hungrySlots=hungrySlots+1 end end
 V.assert(minFree>=0 and maxConsumers<=s.population,'Two free residents never become four simultaneous allocated builders')
 V.assert(paidRestore and builderMeals<=2,'Natural 120-second run feeds at most the two real free residents, including paid-meal reload')
 V.assert(hungrySlots<=2,'Only the two actual unassigned residents accrue idle-builder hunger, not all four pool slots')
 print('PARTIAL_BUILDER_IDENTITY',hungrySlots,cjson.encode(s.builders))
 print('BUILDER_POPULATION_DIAGNOSTIC',cjson.encode({population=s.population,minFree=minFree,maxConsumers=maxConsumers,idleBuildersAte=builderMeals,meals=s.mealsServed,stock=s.stock.food}))
 V.finish()
end)
