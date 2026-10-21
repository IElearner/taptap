-- Synthetic schema1..9 opening-save compatibility plus actual archived v3/v4/v8
-- suites run separately. Never claims synthetic versions are historical captures.
local Sim=require 'game.Simulation';local Data=require 'game.SaveData';local D=require 'game.Definitions'
local function clone(v)return cjson.decode(cjson.encode(v))end
local function same(a,b)
 if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end;return true
end
V.atFrame(8,function()
 for version=1,9 do
  local original=Sim.new('finite',23);original.started=true;original.skipped=true
  local bundle=Data.capture(original,1000,1,true);bundle.version=version
  if version<6 then bundle.worldSize=nil end
  local b0=bundle.world.buildings[1];local roads=clone(bundle.world.roads);local stock=clone(bundle.world.stock)
  local s,why=Data.restore(clone(bundle),'finite')
  V.assert(s~=nil,'Explicit synthetic schema'..version..' startup fixture accepted by schema10: '..tostring(why))
  if s then
   V.assert(s.population==original.population and #s.buildings==1 and s.buildings[1].x==b0.x and s.buildings[1].y==b0.y and same(s.roads,roads),'Schema'..version..' preserves population/building/roads')
   local goods=true;for r,n in pairs(stock)do if s.stock[r]~=n then goods=false end end
   V.assert(goods,'Schema'..version..' migration grants no material or duplicated stock')
   V.assert(s.map.worldSize==(version<6 and 22 or 30),'Schema'..version..' world-size compatibility retains documented default')
   local out=Data.capture(s,1000,1,true);V.assert(out.version==10,'Schema'..version..' resaves in schema10')
   local again,err=Data.restore(clone(out),'finite')
   V.assert(again and same(again.stock,s.stock)and same(again.roads,s.roads),'Schema'..version..' repeated JSON migration is idempotent: '..tostring(err))
  end
 end
 V.finish()
end)
