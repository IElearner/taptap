-- Exact native failed checkpoint from d186; real one-ULP success plus malformed
-- boundary rejection. Coordinates alone get tiny tolerance; no cargo/ID tolerance.
local f=File('tests/life/compound_support.lua',FILE_READ);local C=assert(load(f:ReadString(),'@tests/life/compound_support.lua'))();f:Close()
local H=C.H;local run=C.runName('compound-pickup-save')
V.atFrame(8,function()
 local file=File('tests/life/evidence/d186-woodrack-diagnostic-failed-save.json',FILE_READ);local original=cjson.decode(file:ReadString());file:Close()
 local index;for i,a in ipairs(original.world.carriers)do if a.sitePickup then index=i;break end end;assert(index,'Actual archived private carrier')
 local restored,why=H.Data.restore(C.copy(original),'finite');V.assert(restored~=nil,'Original d186 one-ULP native failure checkpoint now loads: '..tostring(why));assert(restored,why)
 local old=original.world.carriers[index];local a=restored.carriers[index]
 V.assert(C.same(a.path,old.path)and a.index==old.index and a.job.amount==old.job.amount and a.job.resource==old.job.resource and a.job.pickedUp==old.job.pickedUp,'Recovery keeps original path/index/exact unpicked job amount/resource')
 local records={}
 for _,test in ipairs({
  {name='target x outside tolerance',change=function(c)c.sitePickup.target.x=c.sitePickup.target.x+1e-5 end},
  {name='target y outside tolerance',change=function(c)c.sitePickup.target.y=c.sitePickup.target.y+1e-5 end},
  {name='public door fractional mismatch',change=function(c)c.sitePickup.door.y=c.sitePickup.door.y+1e-10 end},
  {name='building identity mismatch',change=function(c)c.sitePickup.building=c.sitePickup.building+1 end},
  {name='picked flag inconsistent with approach',change=function(c)c.job.pickedUp=true end},
  {name='carrying inconsistent with approach',change=function(c)c.carrying=true end},
  {name='invalid private phase',change=function(c)c.sitePickup.phase='invented' end},
  {name='negative cargo amount',change=function(c)c.job.amount=-1 end}
 })do
  local data=C.copy(original);test.change(data.world.carriers[index]);local z,e=H.Data.restore(data,'finite')
  V.assert(z==nil,'Coordinate fix still rejects '..test.name);records[#records+1]={name=test.name,rejected=z==nil,reason=e}
 end
 local starting=H.goods(restored,'rawwood')
 for i=1,5 do local z,e=H.restore(restored);V.assert(z~=nil,'Repeated native JSON private approach restore '..i..': '..tostring(e));assert(z,e);restored=z end
 V.assert(H.goods(restored,'rawwood')==starting and restored.carriers[index].job.amount==old.job.amount,'Repeated load leaves exact wood total and reservation amount unchanged')
 C.write('tests/life/evidence/'..run..'-complete.json',{complete=true,sourceCheckpoint='d186-woodrack-diagnostic-failed-save.json',records=records,restores=5});V.finish()
end)
