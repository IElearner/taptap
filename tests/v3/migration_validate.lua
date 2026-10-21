local Data=require 'game.SaveData'
local D=require 'game.Definitions'
local E=require 'game.Economy'
local function load(name)
 local f=File('tests/v2/fixtures/'..name..'.json',FILE_READ);local v=cjson.decode(f:ReadString());f:Close();return v
end
local function roundtrip(s)return Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000,1,true))),'finite')end
local ticks=0
local function tick(s)s:update(.1);ticks=ticks+1;if ticks%100==0 then coroutine.yield()end end
local task=coroutine.create(function()
 for _,name in ipairs({'legacy_v3_fixture','v2_playable_fixture'})do
  local old=load(name);local s,err=Data.restore(old,'finite')
  V.assert(s~=nil,'Actual archived old village upgrades: '..name..' '..tostring(err))
  if s then
   V.assert(s.population==old.world.population and s.militia==old.world.militia and #s.buildings==#old.world.buildings,'Upgrade preserves real people, guards and buildings: '..name)
   local expectedLesson=old.version<4 and (({1,2,3,4,6,7,9,10,11})[old.world.lesson] or old.world.lesson) or old.world.lesson
   V.assert(s.mode==old.mode and s.lesson==expectedLesson and s.skipped==old.world.skipped,'Upgrade preserves mode and tutorial objective with documented old lesson mapping: '..name)
   for r,n in pairs(old.world.stock)do V.assert(s.stock[r]==n,'Old warehouse identity/quantity retained: '..name..' '..r)end
   for r in pairs(D.expandedGoods)do V.assert(s.stock[r]==0,'No retroactive gift of new resource: '..name..' '..r)end
   for _,b in ipairs(s.buildings)do
    local oldb=old.world.buildings[b.id]
    V.assert(b.x==oldb.x and b.y==oldb.y and b.complete==oldb.complete and b.progress==oldb.progress,'Existing construction state remains exact: '..name..' '..b.id)
    if b.kind=='butcher'then V.assert(E.outputAmount(b,'hide')==0,'Old butcher receives no retroactive skin for old livestock')end
   end
   for i,a in ipairs(s.carriers)do
    local before=old.world.carriers[i]
    V.assert(a.carrying==before.carrying and a.phase==before.phase,'Old carrier phase survives upgrade: '..name..' '..i)
    if a.job then V.assert(a.job.resource==before.job.resource and a.job.amount==before.job.amount,'In-flight cargo preserves its old resource and amount: '..name..' '..i)end
   end
   local r,why=roundtrip(s);V.assert(r~=nil,'Upgraded village serializes a second time: '..name..' '..tostring(why))
   if r then for _,resource in ipairs(D.goods)do V.assert(r.stock[resource]==s.stock[resource],'Second restore does not repeat conversion: '..resource)end end
  end
 end
 -- Controlled v4 boundary variant of the actual archived old village. It is
 -- explicitly a migration fixture, not claimed to be a fresh full playthrough.
 local old=load('legacy_v3_fixture');old.version=4;old.world.stock.rawwood=0;old.world.stock.bread=0
 local quarry=old.world.buildings[9]
 quarry.buffer=2;quarry.outgoing=true;quarry.workers=0;old.world.workers[quarry.id..':1']=nil
 old.world.buildings[8].legacyOutput='wood'
 old.world.jobs[#old.world.jobs+1]={building=quarry.id,inbound=false,resource='stone',amount=2,service=false,pickedUp=false,construction=false}
 local upgraded,err=Data.restore(old,'finite');V.assert(upgraded~=nil,'V4 quarry with queued cut-stone shelf upgrades: '..tostring(err))
 if upgraded then
  local q=upgraded.buildings[quarry.id]
  V.assert(upgraded:outputResource(q)=='stone' and E.outputAmount(q,'stone')==2 and E.outputAmount(q,'rawstone')==0,'V4 quarry shelf remains two finished stone, never two rawstone')
  local before=upgraded.stock.stone
  for _=1,1800 do if upgraded.stock.stone>=before+2 then break end;tick(upgraded)end
  V.assert(upgraded.stock.stone==before+2 and q.buffer==0,'Old quarry goods physically arrive in the finished-stone warehouse exactly once')
  V.assert(upgraded.stock.rawstone==0,'Old quarry shipping does not create rawstone as an extra copy')
  local again=roundtrip(upgraded);V.assert(again and again.stock.stone==upgraded.stock.stone and again.stock.rawstone==0,'Post-delivery v4 quarry migration cannot be repeated by reload')
 end
end)
for frame=8,300 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end
 local ok,err=coroutine.resume(task)
 if not ok then V.assert(false,'Migration coroutine: '..tostring(err));V.finish()
 elseif coroutine.status(task)=='dead'then V.finish()end
end)end
