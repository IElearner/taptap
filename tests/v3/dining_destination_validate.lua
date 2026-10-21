-- Minimal two-hall boundary: near hall is empty, reachable farther hall has
-- eight already cooked meals. No production or tutorial rescue is enabled.
local Sim=require 'game.Simulation'
local Data=require 'game.SaveData'
local s,near,far,a
V.atFrame(8,function()
 s=Sim.new('finite',23);s.started=true;s.skipped=true;s.stock.food=0
 for x=7,13 do s.roads[x..':9']=true end;s.roadCount=2
 near=s:addBuilding('kitchen',7,8,true);far=s:addBuilding('kitchen',13,8,true)
 near.workers,far.workers=0,0;near.mealStock,far.mealStock=0,8
 a=s.carriers[1];a.x,a.y,a.hunger=8,9,0
 V.assert(s:path(8,9,7,9)~=nil and s:path(8,9,13,9)~=nil,'Both near empty and farther stocked dining halls have actual road paths')
end)
for frame=9,38 do V.atFrame(frame,function()for _=1,50 do s:update(.1)end end)end
V.atFrame(39,function()
 print('TWO_HALL_DESTINATION',cjson.encode({nearStock=near.mealStock,farStock=far.mealStock,carrier=a,meals=s.mealsServed,warehouse=s.stock.food}))
 V.assert(a.hunger<90 or a.meal and a.meal.target==far.id and (a.meal.phase=='enter' or a.meal.phase=='eat' or a.meal.phase=='exit'),'Naturally hungry carrier obtains reachable cooked food instead of repeatedly preferring an empty nearby hall')
 V.assert(s.mealsServed>0 and far.mealStock<8,'Existing cooked meals at the farther connected hall are actually consumed')
 V.assert(s.stock.food==0,'Two-hall recovery uses existing meal stock and does not invent warehouse food')
 local loaded,why=Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000,1,true))),'finite')
 V.assert(loaded and loaded.buildings[far.id].mealStock==far.mealStock,'Dining choice retains actual food balance through save/load: '..tostring(why))
 V.finish()
end)
