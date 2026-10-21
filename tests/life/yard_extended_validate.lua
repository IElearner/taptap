-- Explicit controlled occupancy boundaries; no pretending these were earned.
local f=File('tests/life/support.lua',FILE_READ);local H=assert(load(f:ReadString(),'@tests/life/support.lua'))();f:Close()
local Sim=require 'game.Simulation'
local task=coroutine.create(function()
 for _,kind in ipairs({'mill','bakery','butcher','sawmill','smelter','tannery','woodweapons','leatherarmor','ironweapons','ironarmor'})do
  local s=Sim.new('finite',23);s.started,s.skipped=true,true;s.stock.wood,s.stock.stone=1000,1000
  local b=H.add(s,kind);local site=b.site
  V.assert(site and site.version==2 and site.workCell and site.storageCell and #site.idleCells==2,kind..' new outdoor plot records work/storage/two distinct idle cells')
  local keys={};local unique=true
  for _,p in ipairs(site.yardCells)do
   local k=p.x..':'..p.y;if keys[k]or s:buildingAt(p.x,p.y)or s.roads[k]then unique=false end;keys[k]=true
   V.assert(H.Sites.owner(s,p.x,p.y)==b,kind..' yard cell has correct owner independent of structural cells')
   local ok,why=s:canBuild('road',p.x,p.y);V.assert(not ok and why:find('院落',1,true),kind..' functional plot refuses intersecting new road with reason')
  end
  V.assert(unique,kind..' work, storage and idle reservations are distinct and outside structure/road')
  local point=H.Sites.pickupPoint(b);local scratch={x=b.x,y=b.y+1,path={},index=1}
  V.assert(H.Sites.route(s,scratch,b,point),kind..' actual public doorway reaches fractional storage contact')
  local z,why=H.restore(s);V.assert(z~=nil,kind..' new site roundtrips: '..tostring(why));assert(z,why)
  V.assert(z.buildings[b.id].site.storageCell.x==site.storageCell.x and z.buildings[b.id].site.storageCell.y==site.storageCell.y,kind..' storage is not silently relocated on save/read')
 end
 -- Find a naturally valid fishery, then occupy every candidate dry bank cell
 -- with explicit independent-neighbor yard reservations. Structure/door/water
 -- stay untouched: nearby water alone cannot bypass actual shoreline access.
 local s=Sim.new('finite',23);s.started,s.skipped=true,true;s.stock.wood,s.stock.stone=1000,1000
 local found
 for y=2,29 do for x=2,29 do if not found then local ok,_,site=s:canBuild('fishery',x,y);if ok and site then found={x=x,y=y,site=site}end end end end
 assert(found,'Need legal near-water baseline');local blocked={};local occupied={}
 for _,p in ipairs(H.D.cells('fishery'))do occupied[(found.x+p.x)..':'..(found.y+p.y)]=true end
 s.activityIndex=s.activityIndex or {};local dirs={{1,0},{-1,0},{0,1},{0,-1}};local dummy={id=999,kind='house'}
 for y=1,30 do for x=1,30 do
  local k=x..':'..y
  if s:terrain(x,y)=='grass'and not occupied[k]and not(x==found.x and y==found.y+1)then
   local bank=false;for _,d in ipairs(dirs)do local wx,wy=x+d[1],y+d[2];if s:terrain(wx,wy)=='water'and math.abs(wx-found.x)+math.abs(wy-found.y)<=3 then bank=true end end
   if bank then s.activityIndex[k]=dummy;blocked[#blocked+1]=k end
  end
 end end
 V.assert(#blocked>0 and H.Dep.water(s,found),'Water remains nearby while all dry candidate shore points are unavailable')
 local ok,why=s:canBuild('fishery',found.x,found.y)
 V.assert(not ok and why:find('岸',1,true),'Near water but no accessible dry working shore refuses construction with bank feedback')
 for _,k in ipairs(blocked)do s.activityIndex[k]=nil end
 V.assert(s:canBuild('fishery',found.x,found.y),'Removing only controlled bank obstacles restores same-anchor construction validity')
 print('SHORE_BLOCKED_DECLARED',cjson.encode({anchor=found,blocked=blocked,reason=why}))
end)
for frame=8,600 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end;local ok,e=coroutine.resume(task);if not ok then V.assert(false,'New outdoor yards / unreachable shore: '..tostring(e));V.finish()elseif coroutine.status(task)=='dead'then V.finish()end
end)end
