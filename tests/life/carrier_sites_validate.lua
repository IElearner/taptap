-- Independent C acceptance. Explicit controlled material/geometry scaffold;
-- all worker and carrier phases below arise from actual Simulation.update.
local f=File('tests/life/support.lua',FILE_READ);local H=assert(load(f:ReadString(),'@tests/life/support.lua'))();f:Close()
local run='carrier-sites';for _,v in ipairs(GetArguments())do run=v:match('^-pixelqa%-run=([%w_-]+)$')or run end
local records={};local realTake=H.E.take;local current
H.E.take=function(b,r,n)
 if current and b.id==current.id and r==current.resource then
  local caller
  for i,c in ipairs(current.sim.carriers)do if c.job and c.job.b==b and c.job.resource==r and c.sitePickup and c.sitePickup.phase=='loading'then caller={index=i,x=c.x,y=c.y,phase=c.sitePickup.phase,pickedUp=c.job.pickedUp,clock=c.sitePickup.clock};break end end
  current.takes[#current.takes+1]={time=current.sim.elapsed,amount=n,before=H.E.outputAmount(b,r),caller=caller}
 end
 return realTake(b,r,n)
end
local task=coroutine.create(function()
 for _,kind in ipairs({'fishery','ironmine','coalmine','goldmine','quarry','mason'})do
  local s,b=H.setup(kind);local id=b.id;local r=H.D.buildings[kind].output;local initial=kind=='mason'and 1 or H.D.buildings[kind].amount
  current={sim=s,id=id,resource=r,takes={}}
  local seen={};local good,noJump,newFlag=true,true,true;local previous={};local snapshots={}
  for tick=1,12000 do
   H.step(s);b=s.buildings[id]
   local total=kind=='mason'and H.goods(s,'rawstone')/2+H.goods(s,'stone')or H.Dep.source(s,b,r).remaining+H.goods(s,r)
   if total~=initial or not H.holds(s,b)then good=false end
   local reload
   for index,c in ipairs(s.carriers)do
    local j=c.job;local visit=c.sitePickup
    if j and j.b==b and not j.inbound and j.resource==r then
     if j.sitePickup~=true then newFlag=false end
     local old=previous[index]
     if old and ((c.x-old.x)^2+(c.y-old.y)^2)^.5>.2 then noJump=false end
     previous[index]={x=c.x,y=c.y}
     if visit then
      local label=visit.phase..(visit.phase=='loading'and(j.pickedUp and '-picked'or '-unpicked')or '')
      if not seen[label]then
       seen[label]=true;seen[visit.phase]=true
       snapshots[#snapshots+1]={time=s.elapsed,phase=visit.phase,x=c.x,y=c.y,target=visit.target,pickedUp=j.pickedUp,carrying=c.carrying,buffer=b.buffer}
       reload=label
      end
     end
    else previous[index]=nil end
   end
   if reload then
    local restored,why=H.restore(s);V.assert(restored~=nil,kind..' actual private carrier '..reload..' survives JSON: '..tostring(why));assert(restored,why)
    s=restored;b=s.buildings[id];current.sim=s
   end
   if s.stock[r]==initial then break end
  end
  local pickAtSite=true;local amount=0;local target=H.Sites.pickupPoint(b)
  for _,take in ipairs(current.takes)do
   amount=amount+take.amount;local c=take.caller
   if not c or c.pickedUp or math.abs(c.x-target.x)>.001 or math.abs(c.y-target.y)>.001 then pickAtSite=false end
  end
  V.assert(good and s.stock[r]==initial,kind..' source/input→worker→shelf→carrier→warehouse conserved')
  V.assert(newFlag and seen.approach and seen.loading and seen['return'],kind..' NEW job visits actual storage and returns by private path')
  V.assert(#current.takes==1 and amount==initial and pickAtSite,kind..' instrumented E.take exactly once at actual tank/stack before pickedUp')
  V.assert(seen['loading-unpicked']and seen['loading-picked'],kind..' save/load observed both sides of the actual loading midpoint')
  V.assert(noJump,kind..' carrier movement has no teleport across private/public path transitions')
  records[#records+1]={kind=kind,seen=seen,snapshots=snapshots,takes=current.takes,stock=s.stock[r]};current=nil
 end
end)
for frame=8,1200 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end
 local ok,err=coroutine.resume(task)
 if not ok then H.E.take=realTake;V.assert(false,'Private carrier independent case: '..tostring(err));V.finish()
 elseif coroutine.status(task)=='dead'then H.E.take=realTake;local out=File('tests/life/evidence/'..run..'-sites.json',FILE_WRITE);out:WriteString(cjson.encode(records));out:Close();V.finish()end
end)end
