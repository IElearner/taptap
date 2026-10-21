-- Controlled eligibility/battle integration fixture. Industrial milestones and
-- stocks below are explicit boundary setup, NOT proof of earned industries.
-- Qualification, actual automatic waves, combat, JSON restore and next-wave
-- scheduling use production APIs with no mocked Campaign.ready or battle code.
local Sim=require 'game.Simulation'
local Data=require 'game.SaveData'
local D=require 'game.Definitions'
local C=require 'game.Campaign'
local base
local function clone(v)return cjson.decode(cjson.encode(v))end
local function restore(v)
 local s,why=Data.restore(clone(v),'infinite')
 V.assert(s~=nil,'Infinite campaign fixture restores via real schema: '..tostring(why));return s
end
local steps=0
local function tick(s)
 s:update(.1);steps=steps+1;if steps%50==0 then coroutine.yield()end
end
local function wait(s,predicate,seconds)
 for _=1,seconds*10 do if predicate()then return true end;tick(s)end;return predicate()
end
local function arm(s)
 s.nextRaid=0;tick(s)
 V.assert(s.raid and s.wave==4 and #s.enemies==7,'Actual automatic fourth wave spawns seven enemies')
 local hp=true;for _,e in ipairs(s.enemies)do hp=hp and e.hp==5 end
 V.assert(hp,'Actual fourth-wave profile gives every enemy five HP')
end
local task=coroutine.create(function()
 local s=Sim.new('infinite',23);s.started=true;s.skipped=true;s.map.expansion=4
 for _,r in ipairs(D.goods)do s.stock[r]=1000;s.produced[r]=10 end
 local order={'woodcutter','ironmine','coalmine','goldmine','fishery'}
 for _,kind in ipairs(D.order)do if kind~='road' then local found=false;for _,k in ipairs(order)do if k==kind then found=true end end;if not found then order[#order+1]=kind end end end
 for _,kind in ipairs(order)do
  local chosen
  for y=1,54 do if chosen then break end;for x=1,54 do if s:canBuild(kind,x,y)then chosen={x,y};break end end end
  V.assert(chosen~=nil,'Controlled prerequisite fixture has a legal nonoverlapping '..kind)
  if not chosen then error('Cannot place '..kind)end
  local b=s:addBuilding(kind,chosen[1],chosen[2],true)
  if kind=='courier'then s.carriers[1].courier=b.id;s.carriers[1].deliveryCount=1 end
 end
 s.forestryTendSeconds=5;s.fishMealsCooked=1
 for _,unit in ipairs({'militia','militia','militia','militia','archer','spearman'})do V.assert(s:train(unit),'Boundary fixture recruits a real '..unit..' by paying its defined costs')end
 s.wave=3;s.lesson=20
 V.assert(C.ready(s),'All explicit prerequisite boundaries and real equipped formation qualify at wave start')
 base=Data.capture(s,1000,1,true)
 arm(s)
 V.assert(s.milestoneEligible and s.campaignMilestoneWave==4,'Eligibility is captured at the real automatic-wave boundary')
 s=restore(Data.capture(s,1001,2,true))
 V.assert(s and s.raid and s.milestoneEligible and s.campaignMilestoneWave==4 and #s.enemies==7,'Mid-wave JSON reload preserves the qualification snapshot and living enemies')
 local displaced=false
 for _=1,1200 do
  local alive=0;for _,e in ipairs(s.enemies)do if e.hp>0 then alive=alive+1 end end
  if alive==0 and s.raid then for _,g in ipairs(s.guards)do g.x,g.y=14,9 end;displaced=true end
  tick(s);if not s.raid then break end
 end
 V.assert(displaced and s.campaignCompleted and not s.victory and not s.raid,'Real victory honors start qualification despite survivors being away from their starting formation')
 V.assert(s.nextRaid>0 and not s.milestoneEligible,'Milestone clears the one-wave eligibility and schedules another automatic raid')
 V.assert(s:lessonProgress()==1,'Infinite lesson twenty reads the actually completed milestone')
 V.assert(s:nextLesson() and s.lesson==21,'Infinite lesson twenty can advance after real milestone victory')
 local previous=s.elapsed
 V.assert(wait(s,function()return s.wave==5 and s.raid end,190),'A real automatic fifth wave starts after the milestone without manual start')
 V.assert(s.elapsed>previous and #s.enemies==8 and not s.victory,'Infinite simulation stays running and fifth-wave size follows the existing formula')
 print('INFINITE_QUALIFIED_RESULT',s.wave,s.campaignCompleted,s.victory,s.nextRaid,#s.enemies)
 local bad=restore(base);bad.forestryTendSeconds=0;arm(bad)
 V.assert(not bad.milestoneEligible,'Missing industrial care at wave start refuses milestone qualification')
 bad.forestryTendSeconds=5
 V.assert(wait(bad,function()return not bad.raid end,120) and not bad.campaignCompleted,'Completing a missing goal during an ineligible wave cannot retroactively qualify that victory')
 -- The later wave must independently snapshot the now-complete requirements.
 for _,g in ipairs(bad.guards)do g.x,g.y=10,9;g.meal=false end
 bad.nextRaid=0;tick(bad)
 V.assert(bad.wave==5 and bad.milestoneEligible and bad.campaignMilestoneWave==5,'A later qualified wave independently takes a new eligibility snapshot')
 V.assert(wait(bad,function()return not bad.raid end,120) and bad.campaignCompleted and not bad.victory,'Actual fifth-wave win can earn the milestone after an ineligible fourth wave')
 local casualty=restore(base);arm(casualty)
 for i,g in ipairs(casualty.guards)do if g.unit=='archer'then table.remove(casualty.guards,i);casualty.militia=casualty.militia-1;break end end
 V.assert(wait(casualty,function()return not casualty.raid or casualty.defeat end,120) and not casualty.campaignCompleted,'Losing a required regular unit invalidates completion even when the start snapshot qualified')
 local old=clone(base);old.version=7;old.world.milestoneEligible=nil;old.world.campaignMilestoneWave=nil
 local migrated=restore(old)
 V.assert(migrated and not migrated.milestoneEligible and migrated.campaignMilestoneWave==0 and migrated.forestryTendSeconds==5 and migrated.fishMealsCooked==1,'Schema seven upgrade defaults only new eligibility fields and preserves industrial progress')
end)
for frame=8,550 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end
 local ok,err=coroutine.resume(task)
 if not ok then V.assert(false,'Independent infinite campaign case: '..tostring(err));V.finish()
 elseif coroutine.status(task)=='dead'then V.finish()end
end)end
