local Data=require 'game.SaveData'
local Store=require 'game.PixelSaveStore'
local function clone(x)return cjson.decode(cjson.encode(x)) end
local function check(a,b,label)
 V.assert(cjson.encode(a)==cjson.encode(b),label)
end
V.atFrame(8,function()
 local f=File('tests/v2/fixtures/legacy_v3_fixture.json',FILE_READ)
 local old=cjson.decode(f:ReadString());f:Close()
 V.assert(old.version==3,'Fixture was captured from the actual previous schema')
 local s,err=Data.restore(old,'finite')
 V.assert(s~=nil,'Actual v3 village migrates: '..tostring(err));if not s then return end
 V.assert(s.population==old.world.population and #s.buildings==#old.world.buildings,'Migration preserves population and building count')
 for r,n in pairs(old.world.stock) do V.assert(s.stock[r]==n,'Migration preserves warehouse '..r) end
 V.assert(s.stock.rawwood==0 and s.stock.bread==0,'New goods default to zero without conversion')
 for i,b in ipairs(s.buildings) do
  local before=old.world.buildings[i]
  V.assert(b.kind==before.kind and b.x==before.x and b.y==before.y and b.progress==before.progress,'Migration preserves building and progress '..i)
  V.assert(b.inputs==before.inputs and b.buffer==before.buffer and b.mealStock==before.mealStock,'Migration preserves shelf and food stock '..i)
  if b.kind=='kitchen' then V.assert((b.inputGoods.flour or 0)==(before.inputGoods.flour or 0),'Old kitchen flour remains flour') end
  if b.kind=='woodcutter' and b.buffer>0 then V.assert(s:outputResource(b)=='wood','Old logs already on shelf remain construction wood') end
 end
 V.assert(#s.jobs==#old.world.jobs and #s.carriers==#old.world.carriers,'Migration preserves all queued jobs and carriers')
 for i,c in ipairs(s.carriers) do
  local before=old.world.carriers[i]
  V.assert(c.carrying==before.carrying and c.phase==before.phase and c.handedOff==before.handedOff,'Carrier phase preserved '..i)
  if c.job then V.assert(c.job.resource==before.job.resource and c.job.amount==before.job.amount and c.job.pickedUp==before.job.pickedUp,'Carrier cargo identity preserved '..i) end
 end
 local saved=Data.capture(s,1001,8,true)
 local twice,reason=Data.restore(cjson.decode(cjson.encode(saved)),'finite')
 V.assert(twice~=nil,'Migrated village roundtrip remains valid: '..tostring(reason))
 for r,n in pairs(s.stock) do V.assert(twice.stock[r]==n,'Second save does not repeat migration '..r) end
 -- A separate legitimate legacy snapshot catches a log between tree and camp.
 local loaded=clone(old)
 local woodId
 for _,b in ipairs(loaded.world.buildings)do if b.kind=='woodcutter' then woodId=b.id;b.buffer=0;b.outgoing=false end end
 loaded.world.jobs={}
 for _,c in ipairs(loaded.world.carriers)do c.job=false;c.phase='idle';c.carrying=false;c.handedOff=false end
 local a=loaded.world.workers[woodId..':1']
 a.woodPhase='toCamp';a.woodClock=0;a.treeX=4;a.treeY=3;a.carrying=true;a.path={{x=6,y=5}};a.index=1;a.x=6;a.y=5
 local logger,logErr=Data.restore(loaded,'finite')
 V.assert(logger~=nil,'Legacy carrying logger is a valid saved phase: '..tostring(logErr))
 if logger then
  local w=logger.buildings[woodId]
  for _=1,100 do logger:update(.1) end
  local woodDelivered=logger.stock.wood-loaded.world.stock.wood
  local heldWood=w.buffer>0 and logger:outputResource(w)=='wood'
  local inTransit=false
  for _,j in ipairs(logger.jobs)do if j.resource=='wood' and j.b.id==woodId then inTransit=true end end
  for _,c in ipairs(logger.carriers)do if c.job and c.job.resource=='wood' and c.job.b.id==woodId then inTransit=true end end
  V.assert(heldWood or inTransit or woodDelivered>=1,'Old carrying logger delivers wood rather than silently converting it into rawwood')
 end
end)
V.atFrame(25,function()V.finish()end)
