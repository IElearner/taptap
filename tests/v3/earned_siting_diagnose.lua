-- Diagnose extension space in the paid 33-building benchmark. This does not
-- certify all 30x30 layouts or alter any road, terrain, resource or resident.
local Data=require 'game.SaveData'
V.atFrame(8,function()
 local f=File('tests/v3/fixtures/earned242_after_failed_endurance.json',FILE_READ)
 local s=Data.restore(cjson.decode(f:ReadString()),'finite');f:Close()
 for _=1,3000 do if s:availableWorkers()>0 then break end;s:update(.1)end
 V.assert(s:availableWorkers()>0,'A real resident has returned before testing courier population eligibility')
 local results={}
 for _,kind in ipairs({'courier','house','kitchen'})do
  local r={legal={},rejected={},tested=0}
  for y=1,30 do for x=1,30 do
   local ok,why=s:canBuild(kind,x,y);r.tested=r.tested+1
   if ok then r.legal[#r.legal+1]={x=x,y=y,connected=s:path(10,9,x,y+1)~=nil}
   else r.rejected[why]=(r.rejected[why]or 0)+1 end
  end end
  results[kind]=r
  V.assert(r.tested==900,'Actual engine checks every finite anchor for '..kind)
 end
 local file=File('tests/v3/evidence/d3-earned-siting.json',FILE_WRITE)
 file:WriteString(cjson.encode({sourceFixture='earned242_after_failed_endurance.json',population=s.population,free=s:availableWorkers(),results=results}));file:Close()
 print('V3_ACTUAL_EXTENSION_SITES',cjson.encode(results))
 V.finish()
end)
