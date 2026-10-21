-- Explicit controlled intervention tests. No artificial life phase or output commit.
local helperFile=File('tests/life/support.lua',FILE_READ)
local helperSource=helperFile:ReadString();helperFile:Close()
local H=assert(load(helperSource,'@tests/life/support.lua'))()
local Life=require 'game.WorkLife'
local function untilState(s,id,test,seconds)
 for i=1,(seconds or 300)*10 do
  local b=s.buildings[id];local a=s.workers[id..':1']
  if a and a.life and test(a,b)then return true,a,b end
  H.step(s)
 end
 local b=s.buildings[id];local a=s.workers[id..':1'];return a and a.life and test(a,b)or false,a,b
end
local function requireState(s,id,test,label,seconds)
 local ok,a,b=untilState(s,id,test,seconds);V.assert(ok,label)
 if not ok then error('Required actual state not reached: '..label)end
 return a,b
end
local task=coroutine.create(function()
 for _,kind in ipairs({'fishery','ironmine','mason'})do
  local s,b=H.setup(kind);local id=b.id;local r=H.D.buildings[kind].output
  local a=requireState(s,id,function(a)return Life.working(a)end,'Actual reserved production begins before cancellation: '..kind)
  local stockBefore=H.goods(s,r);local sourceBefore=kind~='mason'and H.Dep.source(s,b,r).remaining or b.inputGoods.rawstone
  V.assert(not s:staff(b,-1),'Busy reserved '..kind..' cannot be deleted by staff reduction')
  V.assert(s:setWorking(b,false),'Normal stop accepted while real '..kind..' work is reserved')
  a,b=requireState(s,id,function(a)return not a.life.reservation and not a.life.load and a.life.phase=='rest'end,'Stopped reserved '..kind..' releases holds and returns physically')
  V.assert(H.holds(s,b)and (b.lifeOutputHeld or 0)==0 and H.goods(s,r)==stockBefore,'Pre-commit stop produces no '..r..' and releases capacity exactly once')
  local sourceAfter=kind~='mason'and H.Dep.source(s,b,r).remaining or b.inputGoods.rawstone
  V.assert(sourceBefore==sourceAfter,'Pre-commit stop does not consume real pool/input: '..kind)
  V.assert(s:staff(b,-1) and b.workers==0,'Safe returned stopped worker can be released normally: '..kind)
 end
 -- A physically caught load must finish, including hunger and stop requests.
 for _,kind in ipairs({'fishery','ironmine','mason'})do
  local s,b=H.setup(kind);local id=b.id;local r=H.D.buildings[kind].output
  local a=requireState(s,id,function(a)return a.life.load~=nil end,'Actual '..kind..' commit creates carried goods')
  local amount=a.life.load.amount;local before=H.goods(s,r)
  V.assert(a.carrying and not a.life.reservation,'Commit converts reservation to exactly one real carried load: '..kind)
  V.assert(not s:staff(b,-1),'Carried '..kind..' load prevents destructive staff removal')
  s:setWorking(b,false)
  a.hunger=95 -- Controlled meal-request edge, never used as sustainability evidence.
  local loaded,why=H.restore(s);V.assert(loaded~=nil,'Stopped hungry carried '..kind..' survives JSON: '..tostring(why));if not loaded then error(why)end
  s=loaded;b=s.buildings[id]
  local sawEat=false;local same=true
  for i=1,5000 do
   H.step(s);a=s.workers[id..':1']
   if H.goods(s,r)~=before or not H.holds(s,b)then same=false end
   if a.meal and a.meal.phase=='eat'then sawEat=true end
   if s.stock[r]>=amount and sawEat and not a.meal and not a.carrying then break end
  end
  V.assert(same,'Stop and meal request never lose or duplicate committed '..r)
  V.assert(s.stock[r]==amount and not a.carrying and not a.life.load and (b.lifeOutputHeld or 0)==0,'Actual stopped worker stows once and ordinary carrier delivers '..r)
  V.assert(sawEat and not a.meal,'Same stopped '..kind..' worker eats and returns after settling its load')
 end
 -- Disconnect before/after commitment: local return must not depend on warehouse road.
 for _,committed in ipairs({false,true})do
  local s,b=H.setup('fishery');local id=b.id
  local a=requireState(s,id,function(a)return committed and a.life.load~=nil or not committed and Life.working(a)end,'Actual fish stage before road interruption')
  local door=b.x..':'..(b.y+1);local pool=H.Dep.source(s,b,'fish').remaining
  s.roads[door]=nil;s.roadCount=s.roadCount+1
  a,b=requireState(s,id,function(a)return not a.life.reservation and not a.life.load and a.life.phase=='rest'end,'Interrupted fisher settles and returns without teleport',300)
  V.assert(H.Dep.source(s,b,'fish').remaining==pool,'Disconnect never performs an additional fish-pool commit')
  V.assert(committed and H.goods(s,'fish')==2 or not committed and H.goods(s,'fish')==0,'Only an already-caught fish load survives interruption')
  s.roads[door]=true;s.roadCount=s.roadCount+1;s:setWorking(b,false)
  if committed then requireState(s,id,function()return s.stock.fish==2 end,'Restored service road lets carrier deliver the real settled fish')end
 end
 -- Two separate fisheries compete for the same finite last batch.
 local s,b=H.setup('fishery');s.stock.wood,s.stock.stone=1000,1000
 local other=H.add(s,'fishery');s.stock.wood,s.stock.stone=0,0;assert(s:staff(other,1))
 local src=H.Dep.source(s,b,'fish');local second=H.Dep.source(s,other,'fish')
 V.assert(src.id==second.id,'Two actual valley fisheries reference one shared pool')
 s.minerals[src.id]=2
 local valid=true
 for i=1,6500 do
  H.step(s)
  if H.Dep.reserved(s,src.id)>H.Dep.source(s,b,'fish').remaining or H.Dep.source(s,b,'fish').remaining+H.goods(s,'fish')~=2 then valid=false end
  if s.stock.fish==2 then break end
 end
 V.assert(valid and s.stock.fish==2 and H.Dep.source(s,b,'fish').remaining==0,'Competing actual fisheries deliver only the real last shared batch')
 local before=H.goods(s,'fish');for i=1,1500 do H.step(s)end
 V.assert(H.goods(s,'fish')==before and H.Dep.reserved(s,src.id)==0,'Exhausted shared fish pool cannot reserve or duplicate another catch')
 -- Full output blocks starting a new real phase even if raw input/pool exists.
 for _,kind in ipairs({'fishery','ironmine','mason'})do
  s,b=H.setup(kind);local id=b.id
  local a=requireState(s,id,function(a)return a.life.phase=='rest'end,'Actual chair rest before output-capacity boundary')
  local r=H.D.buildings[kind].output;H.E.add(b,r,H.E.capacity(b))
  -- Isolated WorkLife component ticks: carriers deliberately not advanced here.
  for i=1,100 do Life.step(s,a,b,.1);s.elapsed=s.elapsed+.1 end
  V.assert(a.life.phase=='rest'and not a.life.reservation and (b.lifeOutputHeld or 0)==0,'Full physical shelf blocks new '..kind..' reservation and work')
 end
end)
for frame=8,1600 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end
 local ok,err=coroutine.resume(task)
 if not ok then V.assert(false,'Life boundary test: '..tostring(err));V.finish()elseif coroutine.status(task)=='dead'then V.finish()end
end)end
