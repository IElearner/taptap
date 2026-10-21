-- Hungry actual forester offline regression. Controlled original-tree felling
-- fixture; no forestry phase/path/target is assigned by the test.
local f=File('tests/life/support.lua',FILE_READ);local H=assert(load(f:ReadString(),'@tests/life/support.lua'))();f:Close()
local Sim=require 'game.Simulation';local F=require 'game.Forestry';local Offline=require 'game.Offline'
local task=coroutine.create(function()
 local s=Sim.new('finite',23);s.started=true;s.skipped=true;s.stock.wood,s.stock.stone,s.stock.food=1000,1000,500
 local b=s:addBuilding('forester',6,8,true);H.connect(s,b);local hall=H.add(s,'kitchen');hall.mealStock=8 -- declared completed geometry, not build-cost evidence
 local target
 for y=1,30 do for x=1,30 do if not target and s:standingTree(x,y)and math.abs(x-b.x)+math.abs(y-b.y)<=5 then target={x=x,y=y};s.felledTrees[x..':'..y]=true;F.fell(s,x,y)end end end
 assert(target,'Forester fixture needs original tree within care radius');assert(s:staff(b,1));local id=b.id
 local reached=false
 for i=1,3000 do H.step(s);local a=s.workers[id..':1'];if a and a.forestryPhase=='tend'then reached=true;break end end
 V.assert(reached,'Assigned forester actually walks to its original forest stump before offline');assert(reached)
 local a=s.workers[id..':1'];a.hunger=600 -- explicit hunger edge, no phase changes
 local k=a.forestryTarget;local age=s.treeGrowth[k].age;local tend=s.forestryTendSeconds;local meals=s.mealsServed;local food=s.stock.food;local elapsed=s.elapsed
 local restored,why=H.restore(s);V.assert(restored~=nil,'Hungry real tending state survives save: '..tostring(why));assert(restored,why);s=restored;b=s.buildings[id];a=s.workers[id..':1']
 local off=Offline.new(s,1000,1010,true);while not off:step(20)do coroutine.yield()end
 V.assert(not a.meal and a.forestryPhase=='tend','Offline hungry forester continues actual care rather than entering mealReady')
 V.assert(math.abs(s.forestryTendSeconds-tend-10)<.0001,'Ten offline seconds records ten real tending seconds')
 V.assert(s.treeGrowth[k]and math.abs(s.treeGrowth[k].age-age-20)<.0001,'Actual tending advances stump age twice as fast during offline')
 V.assert(a.hunger==600 and s.mealsServed==meals and s.stock.food==food,'Offline care neither feeds actor nor creates a new meal or lowers hunger')
 V.assert(s.elapsed==elapsed,'Offline tending leaves online clock unchanged')
 local q=assert(H.restore(s));V.assert(math.abs(q.treeGrowth[k].age-s.treeGrowth[k].age)<.0001 and q.forestryTendSeconds==s.forestryTendSeconds,'Reload does not reapply the ten seconds of tending')
 print('FORESTRY_OFFLINE_ACTUAL',cjson.encode({building=id,target=k,ageBefore=age,ageAfter=s.treeGrowth[k].age,tendBefore=tend,tendAfter=s.forestryTendSeconds,hunger=a.hunger}))
end)
for frame=8,300 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end;local ok,e=coroutine.resume(task);if not ok then V.assert(false,'Hungry forestry offline: '..tostring(e));V.finish()elseif coroutine.status(task)=='dead'then V.finish()end
end)end
