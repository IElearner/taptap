-- Real cart motion and material accounting on the planner's shared rail route.
local f=File('tests/life/compound_support.lua',FILE_READ);local C=assert(load(f:ReadString(),'@tests/life/compound_support.lua'))();f:Close()
local H=C.H;local run=C.runName('compound-rail');local done=false;local rows={}
local function distance(p,rail)
 local best=math.huge
 for i=2,#rail do
  local a,b=rail[i-1],rail[i];local dx,dy=b.x-a.x,b.y-a.y;local length=dx*dx+dy*dy
  local t=length>0 and math.max(0,math.min(1,((p.x-a.x)*dx+(p.y-a.y)*dy)/length))or 0
  best=math.min(best,math.sqrt((p.x-a.x-t*dx)^2+(p.y-a.y-t*dy)^2))
 end
 return best
end
local task=coroutine.create(function()
 for _,kind in ipairs({'quarry','ironmine','coalmine','goldmine'})do
  local s=C.new();local b=C.add(s,kind);local id=b.id;local hall=C.add(s,'kitchen');hall.mealStock=8
  assert(s:staff(b,1));local resource=H.D.buildings[kind].output
  local initial=H.Dep.source(s,b,resource).remaining+H.goods(s,resource)
  local seen,events={},{};local stopped=false;local onRail=true;local conserved=true;local maxStep=0;local previous;local delivered=false
  for i=1,12000 do
   H.step(s);b=s.buildings[id];local a=s.workers[id..':1'];local l=a and a.life
   if a then
    if previous then maxStep=math.max(maxStep,math.sqrt((a.x-previous.x)^2+(a.y-previous.y)^2))end
    previous={x=a.x,y=a.y}
   end
   if l then
    if l.phase=='rideIn'or l.phase=='rideOut'then
     if distance(a,b.site.railRoute)>1e-5 then onRail=false end
    end
    if l.load and not stopped then assert(s:setWorking(b,false));stopped=true end -- Normal safe stop after genuine extraction.
    if not seen[l.phase]then
     seen[l.phase]=true;events[#events+1]={phase=l.phase,time=s.elapsed,x=a.x,y=a.y,path=C.copy(a.path),load=C.copy(l.load or {}),pool=H.Dep.source(s,b,resource).remaining}
     if l.phase=='rideIn'or l.phase=='mine'or l.phase=='rideOut'or l.phase=='toTank'or l.phase=='stow'then
      local old={path=C.copy(a.path),index=a.index,life=C.copy(l),site=C.copy(b.site),goods=H.goods(s,resource)}
      local z,why=H.restore(s);V.assert(z~=nil,kind..' actual '..l.phase..' saves: '..tostring(why));assert(z,why)
      local za=z.workers[id..':1']
      V.assert(C.same(za.path,old.path)and za.index==old.index and C.same(za.life,old.life)and C.same(z.buildings[id].site,old.site)and H.goods(z,resource)==old.goods,kind..' JSON preserves exact rail progress/load/compound without recomputing a path')
      s=z;b=s.buildings[id]
     end
    end
   end
   if H.Dep.source(s,b,resource).remaining+H.goods(s,resource)~=initial then conserved=false end
   if stopped and s.stock[resource]>=H.D.buildings[kind].amount and l and l.phase=='rest'then delivered=true;break end
  end
  V.assert(seen.rideIn and seen.mine and seen.rideOut and seen.stow,kind..' naturally traverses rail in, mine, rail out, storage')
  V.assert(onRail and maxStep<=.2,kind..' real cart follows the shared rail without teleport or off-track movement')
  V.assert(stopped and delivered and conserved,kind..' safe stop retains real load, stows and delivers once with finite-pool conservation')
  rows[#rows+1]={kind=kind,events=events,onRail=onRail,maxStep=maxStep,source=b.site.compound.source,rail=b.site.railRoute,controlledMaterials=true,controlledCompletion=true}
 end
 C.write('tests/life/evidence/'..run..'-complete.json',{complete=true,rows=rows});done=true
end)
for frame=8,1800 do V.atFrame(frame,function()
 if done or coroutine.status(task)=='dead'then return end;local ok,e=coroutine.resume(task)
 if not ok then V.assert(false,'Integrated rail: '..tostring(e));done=true;V.finish()elseif coroutine.status(task)=='dead'then V.finish()end
end)end
V.atFrame(1810,function()if not done then V.assert(false,'Rail coroutine incomplete');V.finish()end end)
