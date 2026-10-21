-- Stop an actual in-flight logger from the immutable earned checkpoint.
-- No inventory, hunger, task, position or population is granted or reset.
local Sim=require 'game.Simulation'
local Data=require 'game.SaveData'
local run='stopped-logger'
for _,arg in ipairs(GetArguments())do run=arg:match('^-pixelqa%-run=([%w_-]+)$') or run end
local function restored()
 local f=File('tests/v3/fixtures/earned242_after_failed_endurance.json',FILE_READ);local raw=cjson.decode(f:ReadString());f:Close()
 return Data.restore(raw,'finite')
end
local s,b,a,initial
V.atFrame(8,function()
 s=restored();b=s.buildings[7];a=s.workers['7:1']
 initial={x=a.x,y=a.y,hunger=a.hunger,phase=a.woodPhase,load=a.loadAmount,pop=s.population,workers=b.workers,stock=cjson.encode(s.stock),produced=cjson.encode(s.produced)}
 V.assert(b.kind=='woodcutter' and a.woodPhase=='toCamp' and a.carrying and a.loadAmount==1,'Immutable earned logger is really carrying one rawwood toward camp')
 V.assert(s:setWorking(b,false),'Actual player stops the logger building')
 V.assert(b.workers==initial.workers and s.population==initial.pop and a.hunger==initial.hunger and a.x==initial.x and a.y==initial.y and cjson.encode(s.stock)==initial.stock and cjson.encode(s.produced)==initial.produced,'Stop neither unstaffs nor resets/grants/moves the carrying logger')
 s=Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000,1,true))),'finite');b=s.buildings[7];a=s.workers['7:1']
 V.assert(b.stopped and a.carrying and a.woodPhase=='toCamp' and a.loadAmount==1,'Stopped but carrying logger survives JSON restore without losing its load')
 local deliveries=0;local last=a.carrying
 for i=1,600 do
  s:update(.1);a=s.workers['7:1']
  if last and not a.carrying then deliveries=deliveries+1 end;last=a.carrying
 end
 V.assert(not a.carrying and a.woodPhase~='toCamp' and deliveries==1,'Stopped logger completes its existing trip and handoff exactly once through real updates')
 V.assert(b.stopped and not a.woodPhase,'Stopped logger does not select a new tree after finishing existing work')
 local f=File('tests/v3/evidence/'..run..'-state.json',FILE_WRITE);f:WriteString(cjson.encode({initial=initial,actor=a,building=b,deliveredTransitions=deliveries,snapshot=Data.capture(s,1060,2,true)}));f:Close()
 V.finish()
end)
