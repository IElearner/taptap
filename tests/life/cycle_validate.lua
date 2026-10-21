-- Actual same-worker complete cycles; controlled isolated starting materials.
-- Never force animation/phase, manufacture carried goods, or invoke commit.
local helperFile=File('tests/life/support.lua',FILE_READ)
local helperSource=helperFile:ReadString();helperFile:Close()
local H=assert(load(helperSource,'@tests/life/support.lua'))()
local run='life-cycle'
for _,a in ipairs(GetArguments())do run=a:match('^-pixelqa%-run=([%w_-]+)$')or run end
local records={}
local task=coroutine.create(function()
 for _,kind in ipairs({'fishery','ironmine','coalmine','goldmine','quarry','mason'})do
  local s,b=H.setup(kind);local id=b.id;local resource=H.D.buildings[kind].output
  local initial=kind=='mason'and 1 or H.D.buildings[kind].amount
  local seen,phases,lastPhase={}, {},nil
  local validHolds,validConservation,validMovement,seenCarry,seenPickup=true,true,true,false,false
  local maxJump=0;local lastPosition
  for step=1,9000 do
   H.step(s)
   b=s.buildings[id];local a=s.workers[id..':1'];local life=a and a.life
   if a and lastPosition then local jump=math.sqrt((a.x-lastPosition.x)^2+(a.y-lastPosition.y)^2);maxJump=math.max(maxJump,jump);if jump>.2 then validMovement=false end end
   if a then lastPosition={x=a.x,y=a.y}end
   validHolds=validHolds and H.holds(s,b)
   local total
   if kind=='mason'then total=H.goods(s,'rawstone')/2+H.goods(s,'stone')
   else total=H.Dep.source(s,b,resource).remaining+H.goods(s,resource)end
   if total~=initial then validConservation=false end
   if life then
    if kind=='mason' and life.phase=='stow' then V.assert(math.abs(a.x-b.site.stackCell.x)<.001 and math.abs(a.y-b.site.stackCell.y)<.001,'Mason stow occurs at the actual separate stack cell')end
    seenCarry=seenCarry or life.load~=nil and a.carrying==true
    if life.phase~=lastPhase then
     lastPhase=life.phase;phases[#phases+1]={phase=life.phase,time=s.elapsed,x=a.x,y=a.y,reservation=life.reservation,load=life.load,buffer=b.buffer,held=b.lifeOutputHeld,pool=kind~='mason'and H.Dep.source(s,b,resource).remaining or nil}
    end
    if not seen[life.phase]then
     seen[life.phase]=true
     local r,why=H.restore(s);V.assert(r~=nil,kind..' real '..life.phase..' JSON roundtrip: '..tostring(why))
     if not r then error('Cannot restore actual lifecycle')end;s=r;b=s.buildings[id]
    end
   end
   for _,c in ipairs(s.carriers)do local j=c.job;if j and j.b==b and j.resource==resource and j.pickedUp and c.carrying then seenPickup=true end end
   if s.stock[resource]>=initial and a and a.life and a.life.phase=='rest' then break end
  end
  V.assert(seen.rest and seen.rise and seen.stow and seen.toChair,'Actual '..kind..' shares a real chair/rise/stow/return sequence')
  if kind=='fishery'then V.assert(seen.toShore and seen.cast and seen.fish and seen.reel and seen.toTank,'Actual fisherman walks to bank, casts, waits, reels and carries to tank')
  elseif kind=='mason'then V.assert(seen.toBench and seen.cut,'Actual mason walks to bench and cuts real reserved rawstone')
  else V.assert(seen.rideIn and seen.mine and seen.rideOut and seen.toTank,'Actual miner takes cart into mine and returns loaded to storage')end
  V.assert(validHolds,'Every '..kind..' phase preserves exact input/output/shared-pool reservation bounds')
  V.assert(validConservation,'Every '..kind..' tick preserves physical material conservation')
  V.assert(validMovement,'Same '..kind..' worker moves continuously without phase teleport; largest step '..maxJump)
  V.assert(seenCarry and seenPickup,'Profession really carries its new output to storage, then ordinary carrier really picks it up: '..kind)
  V.assert(s.stock[resource]==initial and b.buffer==0 and (b.lifeOutputHeld or 0)==0,'Exactly one earned '..kind..' batch arrives at warehouse without phantom duplicate production')
  records[#records+1]={kind=kind,resource=resource,amount=initial,phases=phases,elapsed=s.elapsed,maxJump=maxJump,stock=s.stock[resource],source='controlled cycle fixture'}
 end
 local f=File('tests/life/evidence/'..run..'-cycles.json',FILE_WRITE);f:WriteString(cjson.encode(records));f:Close()
end)
for frame=8,850 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end
 local ok,err=coroutine.resume(task)
 if not ok then V.assert(false,'Life cycle test: '..tostring(err));V.finish()elseif coroutine.status(task)=='dead'then V.finish()end
end)end
