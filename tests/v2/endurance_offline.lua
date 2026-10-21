local Data=require 'game.SaveData'
local Offline=require 'game.Offline'
local Store=require 'game.PixelSaveStore'
local D=require 'game.Definitions'
local sim,initial,steps,healthy,reason=nil,nil,0,true,''
local function fixture()
 local f=File('tests/v2/fixtures/v2_playable_fixture.json',FILE_READ)
 local v=cjson.decode(f:ReadString());f:Close()
 return Data.restore(v,'finite')
end
V.atFrame(8,function()
 sim=fixture();V.assert(sim~=nil,'Actual newly built v2 village fixture restores')
 sim.skipped=true
 initial={elapsed=sim.elapsed,food=sim.produced.food,bread=sim.produced.bread,meals=sim.mealsServed}
end)
for frame=9,188 do V.atFrame(frame,function()
 for _=1,100 do sim:update(.1);steps=steps+1 end
 for r,n in pairs(sim.stock)do if n<0 or n~=n then healthy=false;reason='negative '..r end end
 for _,b in ipairs(sim.buildings)do
  if b.inputs<0 or b.buffer<0 or b.inputs>4 or b.mealStock<0 then healthy=false;reason='invalid stocks '..b.kind end
 end
 if sim:availableWorkers()<0 then healthy=false;reason='workforce oversubscribed' end
 if steps%3000==0 then
  local restored,err=Data.restore(cjson.decode(cjson.encode(Data.capture(sim,1000+steps/10,1,true))),'finite')
  V.assert(restored~=nil,'Busy v2 5-minute checkpoint restores: '..tostring(err))
  if restored then sim=restored end
 end
end)end
V.atFrame(189,function()
 V.assert(steps==18000 and math.abs(sim.elapsed-initial.elapsed-1800)<.001,'Thirty minutes advance through ordinary online updates')
 V.assert(healthy,'Thirty-minute stocks, inputs, workforce remain valid: '..reason)
 V.assert(not sim.defeat and not sim.victory,'Thirty-minute village remains playable')
 V.assert(sim.produced.food>initial.food and sim.produced.bread>initial.bread,'Actual wheat/bakery/kitchen chain continues producing during thirty minutes')
 V.assert(sim.mealsServed>initial.meals+20,'Workers repeatedly eat and return to work without tutorial food grants')
 print('V2_ENDURANCE_RESULT',sim.elapsed,sim.mealsServed,cjson.encode(sim.produced))
 local s=fixture();s.skipped=true;s.raid=true;s.enemies={{x=10,y=9,hp=10}};s.combatClock=1.19
 local now=1000;local files={}
 local backend={now=function()return now end,read=function(k)return files[k]end,write=function(k,v)files[k]=v;return true end}
 V.assert(Store.new(backend):save(s,true),'Offline fixture saves through real pixel encoder')
 now=1120
 local bundle;Store.new(backend):load('finite',function(v)bundle=v end)
 s=Data.restore(bundle,'finite')
 local before={elapsed=s.elapsed,health=s.health,hp=s.enemies[1].hp,wood=s.produced.wood or 0,bread=s.produced.bread or 0}
 local cap=Offline.new(s,0,999999,true)
 V.assert(cap.seconds==28800,'Offline accrual is capped at exactly eight hours')
 V.assert(Offline.new(s,1200,1120,true).seconds==0,'Future timestamp never accrues negative time')
 V.assert(Offline.new(s,1000,1120,false).seconds==0,'Disabled offline accrual remains zero')
 local off=Offline.new(s,bundle.savedAt,now,true)
 V.assert(off.seconds==120,'Offline load accrues exactly the unclaimed duration')
 while not off:step(512) do end
 V.assert(s.elapsed==before.elapsed and s.health==before.health and s.enemies[1].hp==before.hp and s.raid,'Offline processing never advances an active battle or survival records')
 V.assert((s.produced.wood or 0)>before.wood and (s.produced.bread or 0)>before.bread,'Actual new sawmill and bakery process goods during offline settlement')
 V.assert(Store.new(backend):save(s,true),'Settled state and timestamp commit together')
 local again;Store.new(backend):load('finite',function(v)again=v end)
 local final=Data.restore(again,'finite');local repeated=Offline.new(final,again.savedAt,now,true)
 V.assert(repeated.seconds==0,'Immediate reread cannot claim the same offline interval twice')
 for _,r in ipairs(D.goods)do V.assert(final.stock[r]==s.stock[r],'Offline repeated read conserves '..r)end
 V.finish()
end)
