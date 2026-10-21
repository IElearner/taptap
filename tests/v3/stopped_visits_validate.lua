-- Explicit legacy carrying/ranch-phase fixtures for stop-settlement boundaries.
-- These controlled states are not earned-resource or whole-village evidence.
local Data=require 'game.SaveData'
local Ranch=require 'game.RanchCycle'
local function raw()
 local f=File('tests/v2/fixtures/legacy_v3_fixture.json',FILE_READ);local v=cjson.decode(f:ReadString());f:Close();return v
end
local ticks=0
local function tick(s)
 s:update(.1);ticks=ticks+1;if ticks%100==0 then coroutine.yield()end
end
local task=coroutine.create(function()
 local old=raw();local a=old.world.workers['8:1'];a.carrying=true;a.woodPhase='toCamp';a.loadAmount=1;a.x,a.y=5,5;a.path={{x=6,y=5}};a.index=1;a.meal=false
 local s=Data.restore(old,'finite');local b=s.buildings[8];a=s.workers['8:1']
 V.assert(s:outputResource(b)=='wood' and a.carrying,'Controlled v3 in-flight load restores as old finished wood, not rawwood')
 s:setWorking(b,false)
 local oldOutput=s:outputResource(b);local delivered=0;local previous=a.carrying
 for _=1,400 do tick(s);a=s.workers['8:1'];if previous and not a.carrying then delivered=delivered+1 end;previous=a.carrying end
 V.assert(oldOutput=='wood' and delivered==1 and not a.carrying and not a.woodPhase,'Stopped migrated old-wood carrying task finishes once and does not restart harvesting')
 for _,phase in ipairs({'exit','feed','return'})do
  local q=raw();local r=q.world.buildings[4]
  r.ranchPhase=phase;r.ranchClock=1.4;r.feedClock=phase=='feed' and 1.8 or 0;r.feedRemaining=12;r.timer=49;r.feedVisits=3
  local w=Data.restore(q,'finite');r=w.buildings[4]
  local worker=w.workers['4:1'];local beforeVisits=r.feedVisits;local beforeGrain=r.inputGoods.grain
  V.assert(w:setWorking(r,false),'Actual stop API accepts controlled existing ranch '..phase)
  w=Data.restore(cjson.decode(cjson.encode(Data.capture(w,1000,1,true))),'finite');r=w.buildings[4]
  local elapsed=0;while Ranch.busy(r) and elapsed<10 do tick(w);elapsed=elapsed+.1 end
  V.assert(not Ranch.busy(r),'Stopped ranch finishes existing physical '..phase..' visit after JSON restore')
  V.assert(r.timer==49 and r.feedRemaining==12 and r.feedVisits==beforeVisits,'Stopped ranch preserves paid growth/feed budget and starts no new visit: '..phase)
  V.assert(r.inputGoods.grain==beforeGrain,'Stopped ranch does not consume another grain during visit cleanup: '..phase)
  local ate=false;local returned=false
  for _=1,3600 do
   tick(w);worker=w.workers['4:1']
   if worker.meal and worker.meal.phase=='eat'then ate=true end
   if ate and not worker.meal then returned=true;break end
  end
  V.assert(ate and returned and r.stopped and r.workers==1,'Stopped ranch resident remains employed, really eats, and returns after '..phase..' cleanup')
 end
end)
for frame=8,200 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end
 local ok,err=coroutine.resume(task)
 if not ok then V.assert(false,'Stop visit probe: '..tostring(err));V.finish()elseif coroutine.status(task)=='dead'then V.finish()end
end)end
