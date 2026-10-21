-- One-unit output-shelf fixtures exercise actual courier movement/serialization.
-- Deposit validity and earning these goods are verified in separate E2E suites.
local Sim=require 'game.Simulation'
local Data=require 'game.SaveData'
local E=require 'game.Economy'
local A=require 'game.PixelAssets'
local Actors=require 'game.PixelActors'
local cases={{'quarry','rawstone'},{'ironmine','ironore'},{'coalmine','coal'},{'goldmine','goldore'},{'smelter','iron'},{'smelter','gold'},{'fishery','fish'},{'butcher','hide'},{'tannery','leather'},{'woodweapons','bow'},{'leatherarmor','leatherarmor'},{'ironweapons','ironspear'},{'ironarmor','ironarmor'}}
local ticks=0
local task=coroutine.create(function()
 for _,case in ipairs(cases)do
  local kind,resource=case[1],case[2]
  local s=Sim.new('finite',23);s.started=true;s.skipped=true
  s.roads['13:9']=true;s.roads['14:9']=true;s.roadCount=2
  local b=s:addBuilding(kind,14,8,true);E.add(b,resource,1)
  s:enqueue(b,false,resource)
  V.assert(b.buffer==1 and #s.jobs==1,'Outgoing reservation leaves uncollected physical shelf intact: '..resource)
  local c=s.carriers[1];local seen={};local valid=true;local cargo=false
  for step=1,1200 do
   s:updateCarrier(c,.1,false);s.elapsed=s.elapsed+.1
   local total=s.stock[resource]+E.outputAmount(b,resource)
   for _,j in ipairs(s.jobs)do if j.resource==resource and j.pickedUp then total=total+j.amount end end
   if c.job and c.job.resource==resource and c.job.pickedUp and not c.handedOff then total=total+c.job.amount end
   if total~=1 then valid=false end
   local marker=(c.phase or 'idle')..(c.handedOff and ':handed' or '')..(c.carrying and ':carrying' or '')
   if c.job and not seen[marker]then
    seen[marker]=true
    local restored,err=Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000+step,1,true))),'finite')
    V.assert(restored~=nil,'New actual outbound cargo roundtrips at '..resource..' '..marker..': '..tostring(err))
    if restored then s=restored;c=s.carriers[1];b=s.buildings[2]end
   end
   if c.carrying then
    for _,p in ipairs(Actors.collect(s,{}))do if p.key=='carrier1'then
     cargo=cargo or p.cargo==resource and A.goods[p.cargo]~=nil
    end end
   end
   ticks=ticks+1;if ticks%100==0 then coroutine.yield()end
   if not c.job and #s.jobs==0 then break end
  end
  V.assert(valid,'Every real pickup/movement/handoff conserves exactly one '..resource)
  V.assert(cargo,'Actual carried projection uses the corresponding new cargo identity: '..resource)
  V.assert(seen.packing and seen['travel:carrying'] and seen['unload:carrying'] and seen['unload:handed'],'Observed loading, actual loaded travel, unloading, and exactly-once handoff: '..resource)
  V.assert(s.stock[resource]==1 and b.buffer==0 and not c.job,'Final resumed output delivers exactly one new resource: '..resource)
 end
end)
for frame=8,500 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end
 local ok,err=coroutine.resume(task)
 if not ok then V.assert(false,'New-cargo coroutine: '..tostring(err));V.finish()elseif coroutine.status(task)=='dead'then V.finish()end
end)end
