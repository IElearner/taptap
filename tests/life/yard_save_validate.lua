-- Geometry/migration boundaries are controlled setup, not gameplay earning.
local helperFile=File('tests/life/support.lua',FILE_READ)
local helperSource=helperFile:ReadString();helperFile:Close()
local H=assert(load(helperSource,'@tests/life/support.lua'))()
local Sim=require 'game.Simulation'
local Data=H.Data
local function copy(v)return cjson.decode(cjson.encode(v))end
local function same(a,b)
 if type(a)~=type(b)then return false end
 if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end
 return true
end
local task=coroutine.create(function()
 local s,b=H.setup('fishery')
 V.assert(b.site and b.site.version==2 and #b.site.yardCells>0,'New legal fishery records explicit functional yard cells')
 local site=b.site
 V.assert(s:terrain(site.shoreCell.x,site.shoreCell.y)=='grass' and s:terrain(site.waterCell.x,site.waterCell.y)=='water' and math.abs(site.shoreCell.x-site.waterCell.x)+math.abs(site.shoreCell.y-site.waterCell.y)==1,'Real assigned shore is dry and cardinally adjacent to actual water')
 V.assert(H.Sites.path(s,site.door.x,site.door.y,site.shoreCell.x,site.shoreCell.y,b)~=nil,'Actual entrance has a walkable route to its assigned shore')
 for _,p in ipairs(site.yardCells)do
  V.assert(H.Sites.owner(s,p.x,p.y)==b and not s:buildingAt(p.x,p.y),'Functional yard has its own reservation without falsifying structure footprint')
  local ok,why=s:canBuild('road',p.x,p.y)
  V.assert(not ok and why:find('院落',1,true)~=nil,'New road rejects occupied work yard with a specific reason')
 end
 local restored,why=H.restore(s)
 V.assert(restored and same(restored.buildings[b.id].site,site),'New functional site survives JSON exactly: '..tostring(why))
 local x,y=site.yardCells[1].x,site.yardCells[1].y
 V.assert(restored and H.Sites.owner(restored,x,y)==restored.buildings[b.id],'Reload rebuilds the actual yard ownership index')
 local far=Sim.new('finite',23);far.started=true;far.stock.wood,far.stock.stone=1000,1000
 local checked=false
 for py=3,16 do for px=3,14 do
  local clear=true
  for _,c in ipairs(H.D.cells('fishery'))do if far:terrain(px+c.x,py+c.y)~='grass' or far:buildingAt(px+c.x,py+c.y)or far.roads[(px+c.x)..':'..(py+c.y)]then clear=false end end
  if clear and not H.Dep.water(far,{x=px,y=py}) and far:terrain(px,py+1)=='grass'then
   local ok,reason=far:canBuild('fishery',px,py)
   if not ok and(reason:find('水',1,true)or reason:find('岸',1,true))then checked=true;break end
  end
 end;if checked then break end end
 V.assert(checked,'Physically clear but distant-from-water fishery is actually rejected with water/bank feedback')
 local f=File('tests/life/fixtures/schema8_earned35.json',FILE_READ);local old=cjson.decode(f:ReadString());f:Close()
 V.assert(old.version==8,'Migration fixture is the immutable actual schema-eight earned village')
 local legacy,err=Data.restore(old,'finite');V.assert(legacy~=nil,'Actual old35 village loads under schema9: '..tostring(err));if not legacy then error(err)end
 local masks,coordinates={},{}
 for i,v in ipairs(old.world.buildings)do masks[i]=copy(v.footprintCells);coordinates[i]={v.x,v.y}end
 local roads=copy(old.world.roads)
 for _=1,10 do H.step(legacy)end
 local conserved=true
 for i,v in ipairs(legacy.buildings)do
  if v.x~=coordinates[i][1]or v.y~=coordinates[i][2]or not same(v.footprintCells,masks[i])then conserved=false end
  if v.site and v.site.version==1 and #v.site.yardCells~=0 then conserved=false end
 end
 V.assert(conserved and same(legacy.roads,roads),'Deriving compact legacy work points never moves old structures/masks/doors/roads or reserves old neighbor land')
 local again,e=H.restore(legacy)
 V.assert(again and same(again.roads,roads)and #again.buildings==35,'Old village survives schema9 save/reload after real work-site derivation: '..tostring(e))
 -- Actual reservation is acquired normally before malformed-save rejection.
 s,b=H.setup('fishery');local id=b.id
 local reserved=false
 for _=1,3000 do H.step(s);local a=s.workers[id..':1'];if a and a.life and a.life.reservation then reserved=true;break end end
 V.assert(reserved,'Real life reservation exists before malformed-save tests')
 if not reserved then error('Reservation prerequisite')end
 local good=Data.capture(s,1000+s.elapsed,1,true)
 local broken=copy(good);broken.world.buildings[id].lifeOutputHeld=0
 V.assert(Data.restore(broken,'finite')==nil,'Corrupt output reservation accounting is rejected instead of duplicating capacity')
 broken=copy(good);broken.world.workers[id..':1'].life.load=copy(broken.world.workers[id..':1'].life.reservation)
 V.assert(Data.restore(broken,'finite')==nil,'A malformed worker cannot hold reserved and already-caught copies of the same goods')
 local round=Data.restore(copy(good),'finite')
 V.assert(round and H.holds(round,round.buildings[id]),'Unmodified genuine reservation remains accepted after rejected malformed copies')
end)
for frame=8,450 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end
 local ok,err=coroutine.resume(task)
 if not ok then V.assert(false,'Life yard/save test: '..tostring(err));V.finish()elseif coroutine.status(task)=='dead'then V.finish()end
end)end
