-- Two actual assigned outdoor workers, declared two-batch input fixture.
-- No work phase, path, finished load or actor hunger is assigned.
local f=File('tests/life/support.lua',FILE_READ);local H=assert(load(f:ReadString(),'@tests/life/support.lua'))();f:Close()
local Sim=require 'game.Simulation'
local run='life-dual';for _,v in ipairs(GetArguments())do run=v:match('^-pixelqa%-run=([%w_-]+)$')or run end
local records={}
local task=coroutine.create(function()
 for _,kind in ipairs({'mill','bakery','butcher','sawmill','smelter','tannery','woodweapons','leatherarmor','ironweapons','ironarmor'})do
  local s=Sim.new('finite',23);s.started,s.skipped=true,true;s.stock.wood,s.stock.stone,s.stock.food=1000,1000,500
  local b=H.add(s,kind);local hall=H.add(s,'kitchen');hall.mealStock=8;hall.inputGoods.bread=4;hall.inputs=4
  for _,r in ipairs(H.D.goods)do if r~='food'then s.stock[r]=0 end end
  assert(s:staff(b,1));assert(s:staff(b,1));if H.D.buildings[kind].recipes then assert(s:setRecipe(b,1))end
  local recipe=H.E.recipe(b);local inputs=recipe and recipe.inputs or {[H.D.buildings[kind].input]=1};local out={};for r,n in pairs(H.E.outputs(b))do out[r]=n*2 end
  for r,n in pairs(inputs)do b.inputGoods[r]=n*2;b.inputs=b.inputs+n*2 end
  local dual=false;local separate=true;local held=true;local finished=false;local captured=false;local phase1,phase2={},{};local stowOverlap=false
  for i=1,13000 do
   H.step(s);local a=s.workers[b.id..':1'];local c=s.workers[b.id..':2']
   if a and a.breaks then phase1[a.breaks.phase]=true end;if c and c.breaks then phase2[c.breaks.phase]=true end
   if a and c and a.breaks and c.breaks and a.breaks.phase=='work'and c.breaks.phase=='work'then
    dual=true;if math.abs(a.x-c.x)<.2 then separate=false end
    if not captured then local id=b.id;local z,why=H.restore(s);V.assert(z~=nil,kind..' two real in-position workers save/read: '..tostring(why));assert(z,why);s=z;b=s.buildings[id];captured=true end
   end
   if a and c and a.breaks and c.breaks and a.breaks.phase=='stow'and c.breaks.phase=='stow'and math.abs(a.x-c.x)<.05 and math.abs(a.y-c.y)<.05 then stowOverlap=true end
   local n=0;for _,w in pairs(s.workers)do if w.building==b.id and w.workLoad then for _,v in pairs(w.workLoad.goods)do n=n+v end end end
   if n~=(b.workOutputHeld or 0)or n+b.buffer>H.E.capacity(b)then held=false end
   local done=true;for r,v in pairs(out)do if s.stock[r]~=v then done=false end end
   if done then finished=true;break end
  end
  V.assert(dual and separate,kind..' both actually work at distinct registered left/right work points')
  V.assert(held and finished,kind..' concurrent real batches conserve typed worker-held goods and warehouse output')
  V.assert(phase1.finish and phase1.toStorage and phase1.stow and phase2.work,kind..' real finish/carry/stow occurs with the second worker still represented')
  records[#records+1]={kind=kind,dual=dual,separate=separate,held=held,finished=finished,phase1=phase1,phase2=phase2,stowOverlap=stowOverlap}
 end
end)
for frame=8,2000 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end;local ok,e=coroutine.resume(task);if not ok then V.assert(false,'Outdoor dual worker: '..tostring(e));V.finish()elseif coroutine.status(task)=='dead'then local o=File('tests/life/evidence/'..run..'-dual.json',FILE_WRITE);o:WriteString(cjson.encode(records));o:Close();V.finish()end
end)end
