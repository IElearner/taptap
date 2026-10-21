-- Controlled complete-building fixture fills all ten original resident slots.
-- No population, food or worker is gifted; the initial 28 meals fund the test.
local Sim=require 'game.Simulation'
local s,minFree,builderMeals,maxConsumers= nil,0,0,0
local seen={}
V.atFrame(8,function()
 s=Sim.new('finite',23);s.started=true;s.skipped=true
 for _,xy in ipairs({{7,9},{13,9},{8,10},{8,11},{8,12},{8,13},{7,13},{11,10},{11,11},{11,12},{11,13},{12,13},{13,13}})do s.roads[xy[1]..':'..xy[2]]=true end
 s.roadCount=0;for _ in pairs(s.roads)do s.roadCount=s.roadCount+1 end
 local a=s:addBuilding('kitchen',7,8,true);a.workers=1
 a=s:addBuilding('farm',13,8,true);a.workers=2
 a=s:addBuilding('farm',7,12,true);a.workers=2
 a=s:addBuilding('mill',13,12,true);a.workers=2
 V.assert(s.population==10 and s:availableWorkers()==0,'Three carriers and seven actual positions exhaust the original ten-person budget')
end)
for frame=9,48 do V.atFrame(frame,function()
 for _=1,50 do
  s:update(.1);minFree=math.min(minFree,s:availableWorkers())
  local consumers=#s.carriers+#s.guards
  for _ in pairs(s.workers)do consumers=consumers+1 end
  for i,a in ipairs(s.builders)do
   if a.active or a.meal then consumers=consumers+1 end
   if a.meal and a.meal.phase=='eat' and not seen[i]then seen[i]=true;builderMeals=builderMeals+1 end
  end
  maxConsumers=math.max(maxConsumers,consumers)
 end
end)end
V.atFrame(49,function()
 V.assert(minFree>=0,'Idle construction actors cannot occupy nonexistent spare residents when all ten are assigned')
 V.assert(maxConsumers<=s.population,'Simultaneously allocated actual consumers never exceed the population ledger')
 V.assert(builderMeals==0,'Unassigned idle construction placeholders do not consume meals as extra residents')
 print('BUILDER_POPULATION_DIAGNOSTIC',cjson.encode({population=s.population,minFree=minFree,maxConsumers=maxConsumers,idleBuildersAte=builderMeals,meals=s.mealsServed,stock=s.stock.food}))
 V.finish()
end)
