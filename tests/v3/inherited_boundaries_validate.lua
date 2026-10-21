-- Evidence gaps inherited from the 13-facility gate; independent pure simulation.
local Sim=require 'game.Simulation'
local Data=require 'game.SaveData'
local ticks=0
local function tick(s)
 s:update(.1);ticks=ticks+1;if ticks%100==0 then coroutine.yield()end
end
local function untilTrue(s,predicate,seconds)
 for _=1,seconds*10 do if predicate()then return true end;tick(s)end
 return predicate()
end
local function roundtrip(s)
 return Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000,1,true))),s.mode)
end
local function road(s,x,y)
 local ok,msg=s:build('road',x,y);V.assert(ok,'Legitimate access road '..x..','..y..': '..tostring(msg))
 if ok then V.assert(untilTrue(s,function()return s.roads[x..':'..y]end,500),'Real crew completes access road')end
end
local task=coroutine.create(function()
 local s=Sim.new('finite',23);s.started=true;s.skipped=true
 local ok,msg,house=s:build('house',7,5)
 V.assert(ok,'Unconnected house can remain a real blueprint: '..tostring(msg))
 if house then
  local wood,stone=s.stock.wood,s.stock.stone
  for _=1,500 do tick(s)end
  V.assert(not house.complete and house.progress==0,'Unconnected blueprint does not invent construction progress')
  local r,err=roundtrip(s);V.assert(r~=nil,'Disconnected paid blueprint restores: '..tostring(err))
  if r then s=r;house=s:buildingAt(7,5)end
  road(s,8,8);road(s,8,7);road(s,8,6);road(s,7,6)
  V.assert(untilTrue(s,function()return house.complete end,600),'Existing blueprint automatically resumes after its actual road is built')
  V.assert(s.stock.wood==wood and s.stock.stone==stone,'Connecting and completing a reserved blueprint does not charge materials again')
  V.assert(s.population==14,'Connected blueprint adds exactly four residents on completion')
 end
 local r=Sim.new('finite',23);r.started=true;r.skipped=true
 V.assert(r:build('road',9,10),'New-game road can be planned for an in-flight save')
 for _=1,10 do tick(r)end
 V.assert(not r.roads['9:10'] and r:roadSiteAt(9,10)~=nil,'Road save is genuinely taken before completion')
 local wood,stone=r.stock.wood,r.stock.stone
 local resumed,err=roundtrip(r);V.assert(resumed~=nil,'Pending road and real crew restore: '..tostring(err))
 if resumed then
  V.assert(untilTrue(resumed,function()return resumed.roads['9:10']end,500),'Resumed road completes through ordinary crew updates')
  V.assert(resumed.stock.wood==wood and resumed.stock.stone==stone,'Road roundtrip does not charge prepaid material twice')
  V.assert(resumed:roadSiteAt(9,10)==nil,'Completed restored road has no orphan construction site')
 end
 local army=Sim.new('finite',23);army.started=true;army.skipped=true
 army:addBuilding('barracks',13,8,true);army.roads['13:9']=true;army.roadCount=army.roadCount+1
 local before={wood=army.stock.wood,food=army.stock.food,pop=army.population,free=army:availableWorkers(),militia=army.militia}
 V.assert(army:train(),'An actual available resident trains as a base militia')
 V.assert(army.stock.wood==before.wood-2 and army.stock.food==before.food-2,'A base militia charges exactly two wood and two rations')
 V.assert(army.population==before.pop and army:availableWorkers()==before.free-1 and army.militia==before.militia+1,'Training allocates one existing resident without generating/deleting population')
 army.stock.wood=1;before={wood=army.stock.wood,food=army.stock.food,militia=army.militia,free=army:availableWorkers()}
 local trained,reason=army:train()
 V.assert(not trained and type(reason)=='string' and #reason>0,'Insufficient training material is refused with a reason')
 V.assert(army.stock.wood==before.wood and army.stock.food==before.food and army.militia==before.militia and army:availableWorkers()==before.free,'Rejected training does not partially spend or allocate a resident')
 local f=File('tests/v2/fixtures/legacy_v3_fixture.json',FILE_READ);local old=cjson.decode(f:ReadString());f:Close()
 local migrated=Data.restore(old,'finite');local hall=migrated.buildings[2]
 V.assert(hall.kind=='kitchen' and hall.inputGoods.flour==4 and hall.processingResource=='flour','Actual v3 fixture has four flour and a half-complete old flour batch')
 -- Resume the saved production module with one worker; suppress unrelated
 -- resident movement so this is a precise legacy recipe accounting test.
 hall.activeWorkers=1;hall.workRate=1
 local mealBefore=(hall.mealStock or 0)+hall.buffer
 for _=1,600 do if (hall.inputGoods.flour or 0)<4 then break end;require('game.Production').update(migrated,.1)end
 local consumed=(hall.inputGoods.flour or 0)<4
 V.assert(consumed and hall.inputGoods.flour==3,'Actual old flour batch consumes precisely one preserved flour')
 V.assert(hall.buffer+(hall.mealStock or 0)==mealBefore+4 and (hall.inputGoods.bread or 0)==0 and (hall.inputGoods.meat or 0)==0,'Old flour actually becomes four rations without stealing modern alternative inputs')
 local again,why=roundtrip(migrated)
 V.assert(again and again.buildings[2].inputGoods.flour==3 and again.buildings[2].buffer==hall.buffer and again.buildings[2].mealStock==hall.mealStock,'Consumed legacy flour and produced rations survive another save without replay: '..tostring(why))
end)
for frame=8,450 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end
 local ok,err=coroutine.resume(task)
 if not ok then V.assert(false,'Inherited boundary coroutine: '..tostring(err));V.finish()
 elseif coroutine.status(task)=='dead'then V.finish()end
end)end
