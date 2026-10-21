local Sim=require 'game.Simulation'
local Data=require 'game.SaveData'
local Meals=require 'game.Meals'
V.atFrame(8,function()
 local s=Sim.new('finite',23);s.started=true
 local b=s:addBuilding('mill',13,8,true);b.workers=1
 s.roads['13:9']=true;s.roadCount=s.roadCount+1
 s:update(.1)
 V.assert(s.workers[b.id..':1']~=nil,'Fixture contains a real worker')
 V.assert(s:staff(b,-1),'Player reduces mill staffing through actual API')
 local saved=Data.capture(s,1000,1,true)
 local restored,err=Data.restore(saved,'finite')
 V.assert(restored~=nil,'Immediate save after decreasing staff must restore: '..tostring(err))
 local q=Sim.new('finite',23);q.started=true
 local w=q:addBuilding('woodcutter',17,8,true);w.workers=1
 for x=13,17 do q.roads[x..':9']=true end;q.roadCount=5
 q:update(.1)
 local a=q.workers[w.id..':1']
 a.woodPhase='toCamp';a.treeX=19;a.treeY=8;a.woodClock=0;a.carrying=true;a.path={{x=17,y=9}};a.index=1
 q.felledTrees['19:8']=true;q.timber=q.timber-1
 local reduced,message=q:staff(w,-1)
 V.assert(not reduced and type(message)=='string' and #message>0,'Loaded logger retirement is refused with an actionable explanation')
 q:update(.1)
 V.assert(q.workers[w.id..':1']~=nil or w.buffer==1 or q.stock.wood==73,'Removing a carrying logger conserves the felled log')
end)
V.atFrame(25,function() V.finish() end)
