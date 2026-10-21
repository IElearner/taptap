-- Natural scheduling from declared initial road position and old timer credit.
-- No phase/path/load/job assignment. Geometry/material amounts controlled.
local f=File('tests/life/support.lua',FILE_READ);local H=assert(load(f:ReadString(),'@tests/life/support.lua'))();f:Close()
local run='life-claim';for _,v in ipairs(GetArguments())do run=v:match('^-pixelqa%-run=([%w_-]+)$')or run end
local logs={}
local function claim(s,b)
 for _,c in ipairs(s.carriers)do local p=c.sitePickup and c.sitePickup.phase;if c.job and c.job.b==b and(p=='approach'or p=='loading'or p=='return')then return c end end
end
local task=coroutine.create(function()
 for _,case in ipairs({{x=2,y=14,timer=50,name='carrier-first'},{x=2,y=14,timer=55,name='worker-first'}})do
  local s,b=H.setup('fishery');b.timer=case.timer;H.E.add(b,'fish',2);local source=H.Dep.source(s,b,'fish');s.minerals[source.id]=8
  local path=assert(H.path(s,case.x,case.y));for _,p in ipairs(path)do s.roads[p.x..':'..p.y]=true;s.roadCount=s.roadCount+1 end
  for _,c in ipairs(s.carriers)do assert(not c.job and not c.carrying);c.x,c.y=case.x,case.y end
  local rows={};local overlap=false;local unsafe=false;local workerFirst=false;local latest;local valid=true;local json=false
  for i=1,11000 do
   local prior=s.workers[b.id..':1'];local before=prior and prior.life and prior.life.phase;local beforeClaim=claim(s,b)~=nil
   H.step(s);local a=s.workers[b.id..':1'];local l=a and a.life;local c=claim(s,b)
   if l then
    local state=l.phase..':'..tostring(c and c.sitePickup.phase)
    if state~=latest then latest=state;rows[#rows+1]={time=s.elapsed,worker=l.phase,x=a.x,y=a.y,load=l.load,carrier=c and{phase=c.sitePickup.phase,target=c.sitePickup.target,x=c.x,y=c.y}}end
    if l.load and c then overlap=true end
    if beforeClaim and before=='reel'and l.phase=='toTank'then unsafe=true end
    for _,other in ipairs(s.carriers)do if other.job and other.job.b==b and other.sitePickup and other.sitePickup.phase=='waiting'and(l.phase=='toTank'or l.phase=='stow')then workerFirst=true end end
    if overlap and not json then
     local total=H.goods(s,'fish');local z,why=H.restore(s);V.assert(z~=nil,case.name..' genuine overlap serializes: '..tostring(why));assert(z,why);s=z;b=s.buildings[b.id];json=true
     V.assert(H.goods(s,'fish')==total,case.name..' actual claim/load JSON preserves all goods')
    end
   end
   if H.Dep.source(s,b,'fish').remaining+H.goods(s,'fish')~=10 then valid=false end
   if s.stock.fish==10 then break end
  end
  V.assert(valid and s.stock.fish==10,case.name..' completes ten real fish without duplication or deadlock')
  if case.name=='carrier-first'then
   V.assert(overlap,'Actual returning picker overlaps new caught worker load')
   V.assert(not unsafe,'Worker cannot begin route into storage cell while an earlier actual picker still claims that cell')
  else V.assert(workerFirst,'Actual carrier waits publicly while an earlier worker finishes putting goods into storage')end
  logs[#logs+1]={case=case.name,initial={timer=case.timer,shelf=2,pool=8,carriersAt={case.x,case.y}},overlap=overlap,unsafe=unsafe,workerFirst=workerFirst,valid=valid,stock=s.stock.fish,events=rows}
 end
end)
for frame=8,800 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end;local ok,e=coroutine.resume(task);if not ok then V.assert(false,'Private station claim: '..tostring(e));V.finish()elseif coroutine.status(task)=='dead'then local o=File('tests/life/evidence/'..run..'-claim.json',FILE_WRITE);o:WriteString(cjson.encode(logs));o:Close();V.finish()end
end)end
