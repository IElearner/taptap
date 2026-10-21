local Sim=require 'game.Simulation'
local Data=require 'game.SaveData'
local D=require 'game.Definitions'
local steps=0
local function tick(s) s:update(.1);steps=steps+1;if steps%100==0 then coroutine.yield() end end
local function untilTrue(s,p,seconds)for _=1,seconds*10 do if p()then return true end;tick(s)end;return p()end
local task=coroutine.create(function()
 local count=0
 for kind,def in pairs(D.buildings)do if kind~='road' then
  count=count+1
  local s=Sim.new('finite',23);s.started,s.skipped=true,true;s.stock.wood,s.stock.stone,s.stock.food=500,500,500;s.population=40
  if kind=='store' then V.assert(s.buildings[1].complete and s.buildings[1].kind=='store','Initial warehouse exists as an actual complete building')
  else
   local wood,stone=s.stock.wood,s.stock.stone
   local ok,msg,b=s:build(kind,8,8)
   V.assert(ok,'Catalog building can be legitimately placed: '..kind..' '..tostring(msg))
   if ok then
    V.assert(s.stock.wood==wood-(def.cost.wood or 0) and s.stock.stone==stone-(def.cost.stone or 0),'Construction reserves exact displayed cost once: '..kind)
    V.assert(not s:canBuild(kind,8,8),'Overlapping duplicate construction is rejected: '..kind)
    V.assert(untilTrue(s,function()return b.complete end,500),'Real phased crew completes catalog building: '..kind)
    local r,err=Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000,1,true))),'finite')
    V.assert(r~=nil,'Completed building with returning crew restores: '..kind..' '..tostring(err))
    if kind=='house' then V.assert(s.population==44 and r and r.population==44,'Housing adds four population exactly once across save/load')end
    if kind=='sawmill' or kind=='bakery'then V.assert(#D.cells(b)==(kind=='sawmill' and 12 or 9),'New workshop has its specified full footprint')end
   end
  end
 end end
 V.assert(count==13,'The runtime catalog contains exactly thirteen buildings excluding roads')
 local s=Sim.new('finite');s.started,s.skipped=true,true;s.stock.rawwood=0;s.stock.food=200
 local saw=s:addBuilding('sawmill',8,8,true);saw.workers=1;saw.inputs=1;saw.inputGoods.rawwood=1
 s.roads['8:9']=nil;s.roadCount=s.roadCount+1
 for _=1,100 do tick(s)end
 V.assert(saw.timer==0 and saw.inputs==1 and saw.buffer==0 and #s.jobs==0,'A disconnected new workshop neither processes nor receives or ships goods')
 s.roads['8:9']=true;s.roadCount=s.roadCount+1
 V.assert(untilTrue(s,function()return (s.produced.wood or 0)>=2 end,150),'Reconnecting the same workshop restores real processing and physical delivery')
 local food=Sim.new('finite');food.started,food.skipped=true,true;food.stock.food=200
 local hall=food:addBuilding('kitchen',8,8,true);hall.workers=1;hall.inputs=2;hall.inputGoods={bread=1,meat=1}
 V.assert(untilTrue(food,function()return food.produced.food>=4 end,60),'Either real bread or meat cooks into meals')
 V.assert(hall.inputs==1 and (hall.inputGoods.bread or 0)+(hall.inputGoods.meat or 0)==1,'A cooking batch consumes one alternative, never bread and meat together')
 local n=Sim.new('finite');n.started,n.skipped=true,true;n.stock.rawwood=0
 local b=n:addBuilding('sawmill',8,8,true);b.workers=0;b.inputs=1;b.inputGoods.rawwood=1
 for _=1,100 do tick(n)end
 V.assert(b.timer==0 and b.inputs==1,'A zero-staff workshop preserves raw material and does not progress')
 b.workers=1;b.buffer=8
 for _,c in ipairs(n.carriers)do c.job=false end
 n.carriers={};n.jobs={}
 for _=1,100 do tick(n)end
 V.assert(b.timer==0 and b.inputs==1 and b.buffer==8,'A full output shelf pauses production without deleting input')
 local cap=Sim.new('finite');cap.started,cap.skipped=true,true
 local farm=cap:addBuilding('farm',8,8,true);farm.buffer=3
 local mill=cap:addBuilding('mill',12,8,true);mill.inputs=3;mill.inputGoods.grain=3
 cap:enqueue(farm,false)
 V.assert(cap.jobs[1] and cap.jobs[1].destination==mill and cap.jobs[1].amount==1,'A nearly full destination reserves only its remaining input capacity')
 V.assert(farm.buffer==3 and mill.inputs==3,'Queued outbound shipment stays physically on source shelf until pickup')
end)
for frame=8,600 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end
 local ok,err=coroutine.resume(task)
 if not ok then V.assert(false,'Systems coroutine: '..tostring(err));V.finish()
 elseif coroutine.status(task)=='dead'then V.finish()end
end)end
