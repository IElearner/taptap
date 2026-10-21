-- Independent tail-pool and same-building station contention. Controlled material.
local f=File('tests/life/support.lua',FILE_READ);local H=assert(load(f:ReadString(),'@tests/life/support.lua'))();f:Close()
local Life=require 'game.WorkLife'
local task=coroutine.create(function()
 for _,tail in ipairs({0,1,2,5})do
  local s,b=H.setup('fishery',2);local id=b.id;local source=H.Dep.source(s,b,'fish');s.minerals[source.id]=tail
  local maxBusy,valid,seats=0,true,{};local delivered=false
  for i=1,9000 do
   H.step(s);local busy=0
   for slot=1,2 do local a=s.workers[id..':'..slot];if a and a.life then
    local l=a.life
    if l.reservation or l.load then busy=busy+1 end
    if l.phase=='rest' then seats[slot]={x=a.x,y=a.y}end
   end end
   maxBusy=math.max(maxBusy,busy)
   if H.Dep.source(s,b,'fish').remaining+H.goods(s,'fish')~=tail or not H.holds(s,b)then valid=false end
   if i%1700==0 then local restored,why=H.restore(s);V.assert(restored~=nil,'Two-worker tail '..tail..' ongoing JSON: '..tostring(why));assert(restored);s=restored;b=s.buildings[id]end
   if i>150 and s.stock.fish==tail and H.Dep.source(s,b,'fish').remaining==0 then delivered=true;break end
  end
  V.assert(valid and delivered and s.stock.fish==tail,'Actual shared station catches exactly tail '..tail..' and real carrier delivers it')
  V.assert(maxBusy<=1,'One physical shore station never has two simultaneous reservation/load owners: tail '..tail)
  V.assert(seats[1]and seats[2]and (seats[1].x~=seats[2].x or seats[1].y~=seats[2].y),'Two staffed workers wait at distinct actual positions: tail '..tail)
  local old=H.goods(s,'fish');for _=1,200 do H.step(s)end
  V.assert(H.goods(s,'fish')==old and H.Dep.reserved(s,source.id)==0,'Empty pool remains empty without ghost fish: tail '..tail)
 end
end)
for frame=8,700 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end
 local ok,err=coroutine.resume(task)
 if not ok then V.assert(false,'Tail/station probe: '..tostring(err));V.finish()elseif coroutine.status(task)=='dead'then V.finish()end
end)end
