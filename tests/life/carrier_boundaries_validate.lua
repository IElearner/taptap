-- C boundary fixtures: real phases; controlled road removal/temporary shelf
-- withdrawal and explicit legacy flag absence are declared interventions.
local f=File('tests/life/support.lua',FILE_READ);local H=assert(load(f:ReadString(),'@tests/life/support.lua'))();f:Close()
local function wait(s,b,p,seconds)
 for i=1,(seconds or 400)*10 do
  for _,c in ipairs(s.carriers)do if c.job and c.job.b==b and p(c)then return c end end
  H.step(s)
 end
 error('Required actual carrier boundary not reached')
end
local function restored(s,b,label)
 local x,why=H.restore(s);V.assert(x~=nil,label..' JSON: '..tostring(why));assert(x,why);return x,x.buildings[b.id]
end
local task=coroutine.create(function()
 -- A captured pre-C job remains a legacy public-door pickup after JSON.
 do
  local s,b=H.setup('fishery');local c=wait(s,b,function(c)return not c.job.pickedUp and not c.sitePickup end)
  c.job.sitePickup=nil -- Explicit old-job fixture, never reinterpret as a new job.
  s,b=restored(s,b,'Legacy queued/assigned flag absence');local anyPrivate=false
  for i=1,6000 do
   H.step(s)
   for _,a in ipairs(s.carriers)do if a.job and a.job.b==b and a.sitePickup then anyPrivate=true end end
   if s.stock.fish==2 then break end
  end
  V.assert(not anyPrivate and s.stock.fish==2,'Old nil-flag job keeps legacy packing and delivers exactly its original amount')
 end
 -- Real load must stay owned while its public return route is unavailable.
 do
  local s,b=H.setup('fishery');wait(s,b,function(c)return c.sitePickup and c.sitePickup.phase=='return'and c.job.pickedUp end)
  local roads={};for k,v in pairs(s.roads)do roads[k]=v end
  s.roads={};s.roadCount=s.roadCount+1 -- controlled public-road outage, local yard remains intact
  local c=wait(s,b,function(c)return c.sitePickup and c.sitePickup.phase=='waitingRoute'end,100)
  V.assert(c.carrying and c.job.pickedUp and H.goods(s,'fish')==2,'Missing public return route retains the one real carried batch')
  s,b=restored(s,b,'Loaded waitingRoute');for i=1,100 do H.step(s)end
  V.assert(s.stock.fish==0 and H.goods(s,'fish')==2,'Waiting does not teleport delivery or duplicate held fish')
  s.roads=roads;s.roadCount=s.roadCount+1
  for i=1,6000 do H.step(s);if s.stock.fish==2 then break end end
  V.assert(s.stock.fish==2 and H.goods(s,'fish')==2,'Restored road completes the saved private pickup exactly once')
 end
 -- Empty shelf at loading cannot fabricate goods; restoring those same held
 -- test goods lets the same job finish. No new source or output is created.
 do
  local s,b=H.setup('fishery');local c=wait(s,b,function(c)return c.sitePickup and c.sitePickup.phase=='loading'and not c.job.pickedUp end)
  local held=H.E.outputAmount(b,'fish');H.E.take(b,'fish',held)
  for i=1,30 do H.step(s)end
  V.assert(not c.job.pickedUp and not c.carrying and s.stock.fish==0,'Empty loading shelf cannot mark pickedUp or manufacture a load')
  H.E.add(b,'fish',held);s,b=restored(s,b,'Same real goods returned to waiting shelf')
  s:setWorking(b,false)
  for i=1,6000 do H.step(s);if s.stock.fish==2 then break end end
  V.assert(s.stock.fish==2 and H.goods(s,'fish')==2,'Stopped source still releases already produced goods via the existing job')
 end
 -- Two workers share the one physical station, then the carrier claims its
 -- own private visit; finishing worker and carrier must eventually settle.
 do
  local s,b=H.setup('fishery',2);local source=H.Dep.source(s,b,'fish');s.minerals[source.id]=6
  local sawPrivate,sawWorkerWait,exclusive=false,false,true;local complete=false
  for i=1,12000 do
   H.step(s);local claimed=0
   for _,c in ipairs(s.carriers)do
    if c.job and c.job.b==b and c.sitePickup then
     local p=c.sitePickup.phase
     if p=='approach'or p=='loading'or p=='return'then claimed=claimed+1;sawPrivate=true end
    end
   end
   if claimed>1 then exclusive=false end
   for _,a in pairs(s.workers)do if a.building==b.id and a.life and a.life.load and claimed>0 then sawWorkerWait=true end end
   if H.Dep.source(s,b,'fish').remaining+H.goods(s,'fish')~=6 then exclusive=false end
   if s.stock.fish==6 then complete=true;break end
  end
  V.assert(sawPrivate and exclusive and complete,'Shared worker/carrier site finishes all six real fish without overlapping carrier claims or deadlock')
  print('C_SITE_CONTENTION_OBSERVATION',sawWorkerWait and 'worker load overlapped actual private claim'or 'no overlap in this scheduling sample')
 end
end)
for frame=8,1200 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end
 local ok,e=coroutine.resume(task);if not ok then V.assert(false,'C boundary: '..tostring(e));V.finish()elseif coroutine.status(task)=='dead'then V.finish()end
end)end
