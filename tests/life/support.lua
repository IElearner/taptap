-- Independent controlled test scaffold. Geometry/complete buildings and material
-- fixtures are explicit; this helper never sets a.life phase or commits goods.
local Sim=require 'game.Simulation'
local D=require 'game.Definitions'
local E=require 'game.Economy'
local Data=require 'game.SaveData'
local Sites=require 'game.WorkSites'
local Dep=require 'game.Deposits'
local H={ticks=0}
local dirs={{1,0},{-1,0},{0,1},{0,-1}}
local function key(x,y)return x..':'..y end
function H.path(s,tx,ty,blocked)
 blocked=blocked or {}
 local q,seen,parent={},{},{};local head=1
 for k in pairs(s.roads)do local x,y=k:match('(-?%d+):(-?%d+)');q[#q+1]={x=tonumber(x),y=tonumber(y)};seen[k]=true end
 while not seen[key(tx,ty)]and q[head]do
  local p=q[head];head=head+1
  for _,d in ipairs(dirs)do local x,y=p.x+d[1],p.y+d[2];local k=key(x,y)
   if not seen[k]and not blocked[k]and s:terrain(x,y)=='grass'and not s:buildingAt(x,y)and not Sites.owner(s,x,y)then seen[k]=true;parent[k]=key(p.x,p.y);q[#q+1]={x=x,y=y}end
  end
 end
 if not seen[key(tx,ty)]then return end
 local path={};local k=key(tx,ty)
 while not s.roads[k]do local x,y=k:match('(-?%d+):(-?%d+)');table.insert(path,1,{x=tonumber(x),y=tonumber(y)});k=parent[k]end
 return path
end
function H.connect(s,b)
 local path=H.path(s,b.x,b.y+1);assert(path,'Fixture has no legal service road')
 -- Controlled completed road fixture, not a construction/time-cost acceptance.
 for _,p in ipairs(path)do s.roads[key(p.x,p.y)]=true;s.roadCount=s.roadCount+1 end
 return path
end
function H.add(s,kind,facing)
 local candidates={}
 for y=2,29 do for x=2,29 do candidates[#candidates+1]={x=x,y=y,score=math.abs(x-10)+math.abs(y-8)}end end
 table.sort(candidates,function(a,b)if a.score~=b.score then return a.score<b.score end;if a.y~=b.y then return a.y<b.y end;return a.x<b.x end)
 local best
 for _,p in ipairs(candidates)do
  local ok,_,site=s:canBuild(kind,p.x,p.y)
  if ok and facing then
   local vectors={n={0,-1},s={0,1},e={1,0},w={-1,0}};local d=vectors[facing]
   ok=d and site and site.shoreCell and site.waterCell and site.waterCell.x-site.shoreCell.x==d[1]and site.waterCell.y-site.shoreCell.y==d[2]
  end
  if ok then
   local blocked={};for _,c in ipairs(D.cells(kind))do blocked[key(p.x+c.x,p.y+c.y)]=true end
   for _,c in ipairs(site and site.yardCells or {})do blocked[key(c.x,c.y)]=true end
   if H.path(s,p.x,p.y+1,blocked)then best=p;break end
  end
 end
 assert(best,'No legal controlled fixture location: '..kind)
 local ok,msg,b=s:build(kind,best.x,best.y);assert(ok,msg)
 b.complete=true;b.progress=1
 H.connect(s,b)
 return b
end
function H.setup(kind,workers,facing)
 local s=Sim.new('finite',23);s.started=true;s.skipped=true
 s.stock.wood,s.stock.stone,s.stock.food=1000,1000,500
 local b=H.add(s,kind,facing)
 local hall=H.add(s,'kitchen');hall.mealStock=8;hall.inputGoods.bread=4;hall.inputs=4 -- No chef: full pantry prevents test fish being routed here instead of warehouse.
 s.stock.wood,s.stock.stone=0,0 -- Construction scaffold ends; keep resource-cycle totals unambiguous.
 for i=1,workers or 1 do assert(s:staff(b,1),'Fixture staff allocation')end
 if kind=='mason'then assert(s:setRecipe(b,1));b.inputGoods.rawstone=2;b.inputs=2
 else
  local source=Dep.source(s,b,D.buildings[kind].output);assert(source,'Fixture source')
  if source.id=='rawstone:valley'then s.rock=D.buildings[kind].amount else s.minerals[source.id]=D.buildings[kind].amount end
 end
 return s,b,hall
end
function H.step(s,dt)
 s:update(dt or .1);H.ticks=H.ticks+1
 if H.ticks%100==0 then coroutine.yield()end
end
function H.restore(s)
 return Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000+s.elapsed,1,true))),'finite')
end
function H.goods(s,resource)
 local total=s.stock[resource]or 0
 for _,b in ipairs(s.buildings)do total=total+(b.inputGoods[resource]or 0)+E.outputAmount(b,resource)end
 for _,a in pairs(s.workers)do
  local l=a.life and a.life.load;if l and l.resource==resource then total=total+l.amount end
  if a.workLoad and a.workLoad.goods then total=total+(a.workLoad.goods[resource]or 0)end
 end
 for _,j in ipairs(s.jobs)do if j.resource==resource and (j.inbound or j.pickedUp)then total=total+j.amount end end
 for _,a in ipairs(s.carriers)do local j=a.job;if j and not a.handedOff and j.resource==resource and(j.inbound or j.pickedUp)then total=total+j.amount end end
 return total
end
function H.holds(s,b)
 local held,inputs=0,0
 for _,a in pairs(s.workers)do if a.building==b.id and a.life then
  local r=a.life.reservation or a.life.load
  if r then held=held+r.amount end
  if a.life.reservation and a.life.reservation.inputs then inputs=inputs+a.life.reservation.inputs.rawstone end
 end end
 return held==(b.lifeOutputHeld or 0)and b.buffer+held<=E.capacity(b)and inputs<=(b.inputGoods.rawstone or 0)
end
H.D,H.E,H.Data,H.Dep,H.Sites=D,E,Data,Dep,Sites
return H
