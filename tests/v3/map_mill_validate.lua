-- Map/mill version boundaries, independent controlled production tests.
local Sim=require 'game.Simulation'
local Data=require 'game.SaveData'
local E=require 'game.Economy'
local P=require 'game.Production'
local ticks=0
local function pulse(s,b)b.activeWorkers=1;b.workRate=1;P.update(s,.1);ticks=ticks+1;if ticks%100==0 then coroutine.yield()end end
local function roundtrip(s)return Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000,1,true))),s.mode)end
local task=coroutine.create(function()
 local s=Sim.new('finite',23);s.started=true
 local f=File('tests/v2/fixtures/legacy_v3_fixture.json',FILE_READ);local old=cjson.decode(f:ReadString());f:Close()
 local legacy,err=Data.restore(old,'finite');V.assert(legacy~=nil,'Actual old 22-cell village restores: '..tostring(err))
 V.assert(s.map.worldSize==30 and select(2,s.map:bounds())==30,'New finite map has actual 30x30 bounds')
 V.assert(legacy.map.worldSize==22 and select(2,legacy.map:bounds())==22 and legacy:terrain(23,10)=='edge','Missing-size old save remains exactly 22x22 with its old edge')
 local unchanged=true
 for x=1,22 do for y=1,22 do if s:terrain(x,y)~=legacy:terrain(x,y)then unchanged=false end end end
 V.assert(unchanged,'All 484 old valley tiles remain identical in the new finite map')
 s.minerals['fish:valley']=123;s.minerals['ironore:8:15']=77
 local r=roundtrip(s);local q=roundtrip(legacy)
 V.assert(r and r.map.worldSize==30 and r.map.seed==23 and r.minerals['fish:valley']==123 and r.minerals['ironore:8:15']==77,'New map size, seed and depleted reserve identities survive actual save/load')
 V.assert(q and q.map.worldSize==22 and q:terrain(23,10)=='edge' and #q.buildings==#legacy.buildings,'Repeated old save stays 22 and preserves all buildings')
 local infinite=Sim.new('infinite',23);V.assert(infinite.map.worldSize==22 and select(2,infinite.map:bounds())==22,'Infinite mode retains original 22 starter footprint before expansion')
 for _,version in ipairs({1,2})do
  local v=Sim.new('finite',23);v.started=true;v.roads['13:9']=true;v.roadCount=1
  local b=v:addBuilding('mill',13,8,true);b.workers=1;b.recipeVersion=version;b.inputGoods={grain=version};b.inputs=version
  local period=version==1 and 6 or 90
  V.assert(E.period(b)==period and E.recipe(b).inputs.grain==version,'Per-building recipe exposes the exact versioned mill ratio/period: '..version)
  for _=1,math.floor(period*10)-1 do pulse(v,b)end
  V.assert(b.buffer==0 and b.inputs==version,'No mill version consumes or produces before its actual full work period: '..version)
  pulse(v,b);pulse(v,b)
  V.assert(E.outputAmount(b,'flour')==2 and b.inputs==0 and b.inputGoods.grain==0,'Mill completes exactly two flour from its exact versioned input: '..version)
  local saved=roundtrip(v);V.assert(saved and saved.buildings[b.id].recipeVersion==version and E.outputAmount(saved.buildings[b.id],'flour')==2,'Versioned mill and finished batch survive save/load without replay: '..version)
 end
 local oldmill
 for _,b in ipairs(legacy.buildings)do if b.kind=='mill'then oldmill=b end end
 V.assert(oldmill and oldmill.recipeVersion==1 and E.period(oldmill)==6,'Real migrated old mill keeps the six-second legacy recipe')
 local fresh=s:addBuilding('mill',13,8,true)
 V.assert(fresh.recipeVersion==2 and E.period(fresh)==90,'A genuinely new mill receives the ninety-second recipe by construction API')
end)
for frame=8,200 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end
 local ok,err=coroutine.resume(task)
 if not ok then V.assert(false,'Map/mill coroutine: '..tostring(err));V.finish()elseif coroutine.status(task)=='dead'then V.finish()end
end)end
