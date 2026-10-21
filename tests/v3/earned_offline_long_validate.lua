-- One-hour diagnostic extension of the retained fifteen-minute run.
-- A multi-input far workshop may wait behind existing logistics; do not
-- erase the original shorter run or infer a product defect from timing alone.
-- Real earned 25-facility checkpoint; only raid flags are controlled to test
-- offline combat exclusion. Restarting mine orders uses normal player APIs.
local Data=require 'game.SaveData'
local Offline=require 'game.Offline'
local Store=require 'game.PixelSaveStore'
local D=require 'game.Definitions'
local run='earned-offline-long'
for _,arg in ipairs(GetArguments())do run=arg:match('^-pixelqa%-run=([%w_-]+)$')or run end
local sim,bundle,off,before,backend,now
local files={}
V.atFrame(8,function()
 local f=File('tests/v3/fixtures/earned242_33buildings.json',FILE_READ);local raw=cjson.decode(f:ReadString());f:Close()
 sim=Data.restore(raw,'finite')
 V.assert(sim~=nil and #sim.buildings==33,'Offline integration restores the actual earned all-facility checkpoint')
 for _,b in ipairs(sim.buildings)do if b.kind=='ironmine' or b.kind=='coalmine' or b.kind=='smelter'then V.assert(sim:setWorking(b,true),'Normal player action resumes offline industry: '..b.kind)end end
 sim.raid=true;sim.enemies={{x=10,y=9,hp=10}};sim.combatClock=1.19
 now=1000;backend={now=function()return now end,read=function(k)return files[k]end,write=function(k,v)files[k]=v;return true end}
 V.assert(Store.new(backend):save(sim,true),'Earned industrial state saves through the actual pixel encoder')
 now=4600;Store.new(backend):load('finite',function(v)bundle=v end);sim=Data.restore(bundle,'finite')
 before={elapsed=sim.elapsed,health=sim.health,hp=sim.enemies[1].hp,nextRaid=sim.nextRaid,wood=sim.produced.wood or 0,bread=sim.produced.bread or 0,ironore=sim.produced.ironore or 0,coal=sim.produced.coal or 0,iron=sim.produced.iron or 0,food=sim.produced.food,regrown=sim.regrownTrees}
 V.assert(Offline.new(sim,0,999999,true).seconds==28800,'Expanded economy retains the exact eight-hour offline cap')
 V.assert(Offline.new(sim,2000,1900,true).seconds==0 and Offline.new(sim,1000,1900,false).seconds==0,'Future timestamps and disabled accrual produce zero settlement')
 off=Offline.new(sim,bundle.savedAt,now,true)
 V.assert(off.seconds==3600,'Actual saved timestamp accrues precisely one unclaimed hour')
end)
for frame=9,65 do V.atFrame(frame,function()if off.remaining>0 then off:step(256)end end)end
V.atFrame(66,function()
 V.assert(off.remaining==0,'Actual offline update loop finishes its bounded industrial settlement')
 V.assert(sim.elapsed==before.elapsed and sim.health==before.health and sim.enemies[1].hp==before.hp and sim.nextRaid==before.nextRaid and sim.raid,'Offline industry never advances battle, defense HP, elapsed record or next-wave clock')
 V.assert((sim.produced.wood or 0)>before.wood and (sim.produced.bread or 0)>before.bread,'Actual wood and ninety-second flour/bread chains still deliver during offline settlement')
 V.assert((sim.produced.ironore or 0)>before.ironore and (sim.produced.coal or 0)>before.coal,'Actual finite iron/coal reserves feed newly resumed offline deliveries')
 V.assert((sim.produced.iron or 0)>before.iron,'Actual two-input smelter consumes newly delivered ore and coal offline')
 V.assert(sim.regrownTrees>=before.regrown,'Offline forest state remains valid alongside the real industrial logistics')
 V.assert(Store.new(backend):save(sim,true),'Settled world and claimed timestamp commit together')
 local reread;Store.new(backend):load('finite',function(v)reread=v end)
 local final=Data.restore(reread,'finite');local repeated=Offline.new(final,reread.savedAt,now,true)
 V.assert(repeated.seconds==0,'Immediate actual store reload cannot claim the same hour twice')
 for _,r in ipairs(D.goods)do V.assert(final.stock[r]==sim.stock[r] and (final.produced[r] or 0)==(sim.produced[r] or 0),'Offline repeated reload neither duplicates nor drops '..r)end
 print('V3_EARNED_OFFLINE',cjson.encode({before=before,after={wood=sim.produced.wood,bread=sim.produced.bread,ironore=sim.produced.ironore,coal=sim.produced.coal,iron=sim.produced.iron,food=sim.produced.food,regrown=sim.regrownTrees}}))
 local state=File('tests/v3/evidence/'..run..'-settled-state.json',FILE_WRITE);state:WriteString(cjson.encode(Data.capture(sim,now,2,true)));state:Close()
 V.finish()
end)
