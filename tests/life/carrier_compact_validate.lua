-- Controlled schema8 compatibility fixture derived from a legal fresh building.
-- Existing footprint/door/roads are preserved verbatim; this does not replace
-- the separate immutable earned35 migration case.
local f=File('tests/life/support.lua',FILE_READ);local H=assert(load(f:ReadString(),'@tests/life/support.lua'))();f:Close()
local C=require 'game.CarrierLife'
local function same(a,b)
 if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local task=coroutine.create(function()
 for _,kind in ipairs({'fishery','ironmine','mason'})do
  local original,b=H.setup(kind);local id=b.id
  local data=H.Data.capture(original,1000,1,true);data.version=8
  for _,building in ipairs(data.world.buildings)do building.site=nil;building.lifeEnabled=nil;building.lifeOutputHeld=nil;building.lifeInputHeld=nil end
  local mask=cjson.decode(cjson.encode(data.world.buildings[id].footprintCells));local roads=cjson.decode(cjson.encode(data.world.roads));local bx,by=b.x,b.y
  local s,why=H.Data.restore(data,'finite');V.assert(s~=nil,kind..' explicit schema8 compatibility fixture loads: '..tostring(why));assert(s,why);b=s.buildings[id]
  H.step(s);V.assert(b.site and b.site.version==1 and #b.site.yardCells==0,kind..' missing old site derives compact non-reserving stations')
  V.assert(b.x==bx and b.y==by and same(b.footprintCells,mask)and same(s.roads,roads),kind..' deriving compact storage leaves old geometry unchanged')
  local eligible=C.eligible(s,b);V.assert(eligible~=nil and eligible~=false,kind..' compact fixture storage is truly reachable')
  local seen=false;local delivered=false;local resource=H.D.buildings[kind].output
  for i=1,10000 do
   H.step(s)
   for _,c in ipairs(s.carriers)do
    if c.job and c.job.b==b and c.sitePickup then
     V.assert(c.job.sitePickup==true,kind..' NEW job at reachable compact site opts into private pickup')
     seen=true;local nextSim,err=H.restore(s);V.assert(nextSim~=nil,kind..' compact private visit JSON: '..tostring(err));assert(nextSim,err);s,b=nextSim,nextSim.buildings[id];break
    end
   end
   if s.stock[resource]>=H.D.buildings[kind].amount then delivered=true;break end
   if seen then -- Avoid repeating hundreds of identical JSON assertions.
    for j=1,6000 do H.step(s);if s.stock[resource]>=H.D.buildings[kind].amount then delivered=true;break end end
    break
   end
  end
  V.assert(seen and delivered,kind..' actual old compact station supports new true pickup and warehouse delivery')
 end
end)
for frame=8,1200 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end
 local ok,e=coroutine.resume(task);if not ok then V.assert(false,'Compact pickup: '..tostring(e));V.finish()elseif coroutine.status(task)=='dead'then V.finish()end
end)end
