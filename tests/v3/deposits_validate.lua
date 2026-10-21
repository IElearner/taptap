-- Finite reserve identities and shared ownership, independent from art/production.
local Sim=require 'game.Simulation'
local Data=require 'game.SaveData'
local P=require 'game.Deposits'
local function roundtrip(s)
 return Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000,1,true))),s.mode)
end
V.atFrame(8,function()
 local s=Sim.new('finite',23);s.started=true;s.skipped=true
 local counts={ironore=0,coal=0,goldore=0}
 for x=1,22 do for y=1,22 do local d=P.at(s,x,y);if d then counts[d.resource]=counts[d.resource]+1 end end end
 for resource,n in pairs(counts)do V.assert(n>=2,'Initial valley has at least two distinct finite deposits: '..resource)end
 for _,case in ipairs({{resource='ironore',x=8,y=15,capacity=120,batch=2},{resource='coal',x=16,y=6,capacity=160,batch=2},{resource='goldore',x=5,y=10,capacity=60,batch=1}})do
  local mine={x=case.x,y=case.y};local other={x=case.x+1,y=case.y}
  V.assert(P.stock(s,mine,case.resource)==case.capacity,'Deposit starts at its declared finite capacity: '..case.resource)
  local total=0
  for i=1,case.capacity/case.batch do total=total+P.extract(s,i%2==0 and mine or other,case.resource,case.batch)end
  V.assert(total==case.capacity and P.stock(s,mine,case.resource)==0 and P.stock(s,other,case.resource)==0,'Competing mine entrances share exactly one depleted reserve: '..case.resource)
  V.assert(P.extract(s,{x=case.x,y=case.y},case.resource,case.batch)==0,'Rebuilding/revisiting a depleted mine does not recreate ore: '..case.resource)
 end
 local fish={x=17,y=8};local second={x=17,y=9}
 V.assert(P.water(s,fish)~=nil and P.stock(s,fish,'fish')==360,'A real valley shoreline begins with the shared 360-fish pool')
 local total=0
 for i=1,180 do total=total+P.extract(s,i%2==0 and fish or second,'fish',2)end
 V.assert(total==360 and P.stock(s,fish,'fish')==0 and P.stock(s,second,'fish')==0,'Two fishing entrances consume one valley reserve, not 360 each')
 V.assert(P.extract(s,{x=17,y=8},'fish',2)==0,'Rebuilding a fishing lodge cannot recreate the shared fish pool')
 V.assert(P.water(s,{x=8,y=8})==nil and P.extract(s,{x=8,y=8},'fish',2)==0,'An inland lodge cannot extract fish without a valid shoreline')
 local restored,err=roundtrip(s);V.assert(restored~=nil,'All depleted reserve identities survive serialization: '..tostring(err))
 if restored then
  V.assert(P.stock(restored,fish,'fish')==0 and P.stock(restored,{x=8,y=15},'ironore')==0,'Reloading depleted pools does not mistake zero for uninitialized capacity')
  V.assert(P.extract(restored,second,'fish',2)==0,'Repeated post-load extraction cannot duplicate fish')
 end
 local q=Sim.new('infinite',23);q.started=true;q.skipped=true
 local before=0
 for x=-7,30 do for y=-7,30 do
  if q:terrain(x,y)=='fog' and P.nearest(q,'ironore',x,y,0)then before=before+1 end
 end end
 V.assert(before==0,'Undiscovered fog has no accessible ore through the public nearest query')
 q.map:expand()
 local found
 for x=-7,30 do for y=-7,30 do
  if (x<1 or x>22 or y<1 or y>22) and q:terrain(x,y)~='fog' then
   local d=P.at(q,x,y);if d then found=d;break end
  end
 end;if found then break end end
 V.assert(found~=nil,'Actual map expansion reveals at least one deterministic new deposit')
 if found then
  local point={x=found.x,y=found.y};local cap=P.stock(q,point,found.resource)
  local n=P.extract(q,point,found.resource,1);local r,why=roundtrip(q)
  V.assert(n==1 and r~=nil,'A newly explored deposit can be used and saved: '..tostring(why))
  if r then V.assert(P.stock(r,point,found.resource)==cap-1,'Expansion/load/redetection keeps the same depleted identity instead of creating a new deposit')end
 end
end)
V.atFrame(28,function()V.finish()end)
