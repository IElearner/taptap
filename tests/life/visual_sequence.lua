-- Controlled scene with real autonomous WorkLife/meal/carrier updates.
-- Each screenshot holds the actual simulation state for >=3 rendered frames.
-- No animation phase, body position, carried goods or output is assigned.
local helperFile=File('tests/life/support.lua',FILE_READ)
local helperSource=helperFile:ReadString();helperFile:Close()
local H=assert(load(helperSource,'@tests/life/support.lua'))()
local Game=require 'network.Standalone'
local Store=require 'game.PixelSaveStore'
local Actors=require 'game.PixelActors'
local A=require 'game.PixelAssets'
local run='life-visual-fishery'
for _,arg in ipairs(GetArguments())do run=arg:match('^-pixelqa%-run=([%w_-]+)$')or run end
local kind=run:match('visual%-([%w]+)')or 'fishery'
local facing=run:match('fishery%-([nesw])')
local s,view,hud,b,id,pending=nil,nil,nil,nil,nil,nil
local records,seen,counts,seenPhase,history={},{},{},{},{}
local trace,clipFrames={},{}
local renderCount,clipIndex,previousRenderState=0,0,nil
local clip=run:find("clip",1,true)~=nil
local heldFrames,shotNumber,mealSeen,mealReturned,carrierSeen=0,0,false,false,false
local lastBuffer=0
local lastCaptureAt={}
local function record(label,p)
 local a=s.workers[id..':1'];local l=a and a.life
 shotNumber=shotNumber+1
 local row={path='tests/life/evidence/visual/'..run..'-'..string.format('%03d',shotNumber)..'-'..label..'.png',label=label,kind=kind,time=s.elapsed,building=id,site=b.site,inputs=b.inputGoods,output=b.outputGoods,buffer=b.buffer,held=b.lifeOutputHeld,actor=a,phase=l and l.phase,meal=a and a.meal,sprite=p and A.actorSprite(p,s.elapsed),projection=p and {x=p.x,y=p.y,action=p.action,direction=p.direction,walking=p.walking}}
 if kind~='mason'then row.source=H.Dep.source(s,b,H.D.buildings[kind].output)end
 local shelf=b.site.stackCell or b.site.storageCell or b.site.tankCell
 if label:find('shelf%-count')and shelf then view.focus(shelf.x,shelf.y-.4)
 elseif a and l and l.phase~='mine'then view.focus(a.x,a.y-.5)else view.focus(b.x,b.y-.3)end
 if b.site.waterCell then local x,y=view.worldToScreen(b.site.waterCell.x,b.site.waterCell.y);row.waterScreen={x=x,y=y}end
 if b.site.shoreCell then local x,y=view.worldToScreen(b.site.shoreCell.x,b.site.shoreCell.y);row.shoreScreen={x=x,y=y}end
 if p then local x,y=view.worldToScreen(p.x,p.y);row.actorScreen={x=x,y=y}end
 pending=cjson.decode(cjson.encode(row));heldFrames=3
end
function CaptureLifeSequence()
 renderCount=renderCount+1
 local wantClip=clip and s and s.elapsed<=160 and renderCount%2==0
 local wantShot=pending and heldFrames<=0
 if wantClip or wantShot then
  local im=Image()
  if graphics:TakeScreenShot(im)then
   if wantShot then im:SavePNG(pending.path);records[#records+1]=pending;pending=nil end
   if wantClip then
    clipIndex=clipIndex+1
    local path='tests/life/evidence/visual/'..run..'-frames/'..string.format('%05d',clipIndex)..'.png'
    im:SavePNG(path);clipFrames[#clipFrames+1]={path=path,render=renderCount,previousRender=previousRenderState}
   end
  end
 end
 if s and b then local a=s.workers[id..':1'];previousRenderState=a and {time=s.elapsed,x=a.x,y=a.y,phase=a.life and a.life.phase,meal=a.meal and a.meal.phase,buffer=b.buffer}or nil end
end
V.atFrame(6,function()
 local setup,target=H.setup(kind,1,facing);id=target.id
 if kind=='mason'then setup.stock.rawstone=20;target.inputGoods.rawstone=4;target.inputs=4
 else local source=H.Dep.source(setup,target,H.D.buildings[kind].output);if source.id=='rawstone:valley'then setup.rock=20 else setup.minerals[source.id]=20 end end
 -- Above quantities are declared visual scaffold, not earned gameplay resources.
 local files={};local store=Store.new({now=function()return 1000 end,read=function(k)return files[k]end,write=function(k,v)files[k]=v;return true end})
 assert(store:save(setup,true));Game.UseStore(store);s,view,hud=Game.Inspect();hud.dismissIntro();s.paused=true;b=s.buildings[id]
 view.zoom(-100);view.zoom(1);view.focus(b.x,b.y-.5);hud.update();SubscribeToEvent('EndAllViewsRender','CaptureLifeSequence')
 V.assert(b.site~=nil,'Visual fixture uses actual registered work points for '..kind)
end)
for frame=12,3212 do V.atFrame(frame,function()
 if not b then return end
 if pending then heldFrames=math.max(0,heldFrames-1);return end
 s.paused=false;s:update(.1);s.paused=true;hud.update()
 local a=s.workers[id..':1'];local l=a and a.life
 if not l then return end
 local p;for _,q in ipairs(Actors.collect(s,history))do if q.key=='worker'..id..':1'then p=q;break end end
 local phase=a.meal and ('meal-'..a.meal.phase)or l.phase
 trace[#trace+1]=cjson.decode(cjson.encode({time=s.elapsed,actor=id..':1',x=a.x,y=a.y,phase=l.phase,clock=l.clock,workSeconds=l.workSeconds,reservation=l.reservation,load=l.load,carrying=a.carrying,meal=a.meal and {phase=a.meal.phase,paid=a.meal.paid,target=a.meal.target},buffer=b.buffer,held=b.lifeOutputHeld,output=b.outputGoods,source=kind~='mason'and H.Dep.source(s,b,H.D.buildings[kind].output)or nil}))
 seenPhase[phase]=true
 if a.meal and a.meal.phase=='eat'then mealSeen=true elseif mealSeen and not a.meal then mealReturned=true end
 local sprite=p and A.actorSprite(p,s.elapsed)
 local mark=phase..':'..(sprite and sprite.path or 'hidden')..':'..(sprite and sprite.frame or 0)..':'..(p and p.direction or 0)
 local moving=phase=='toShore'or phase=='toStack'or phase=='toTank'or phase=='rideIn'or phase=='rideOut'or phase=='toBench'or phase=='toRail'
 if moving then mark=mark..':'..math.floor((l.clock or 0)/.4)end
 local limit=moving and 4 or (phase=='rest'or phase=='cast'or phase=='fish'or phase=='reel'or phase=='cut'or phase=='meal-eat')and 4 or 2
 if not seen[mark]and(counts[phase]or 0)<limit and (not moving or not lastCaptureAt[phase] or s.elapsed-lastCaptureAt[phase]>=.4)then
  lastCaptureAt[phase]=s.elapsed
  seen[mark]=true;counts[phase]=(counts[phase]or 0)+1;record(phase..'-'..counts[phase],p)
 end
 local resource=H.D.buildings[kind].output
 for i,c in ipairs(s.carriers)do local j=c.job
  if not carrierSeen and j and j.b==b and j.resource==resource and j.pickedUp and c.carrying then
   carrierSeen=true
   if not pending then record('real-carrier-pickup',p)end
  end
 end
 if b.buffer~=lastBuffer then
  records[#records+1]={event='shelf-count',time=s.elapsed,before=lastBuffer,after=b.buffer,output=cjson.decode(cjson.encode(b.outputGoods))};lastBuffer=b.buffer
  if not pending then record('shelf-count-'..b.buffer,p)end -- Real shelf before/after, camera explicitly follows storage.
 end
end)end
V.atFrame(3220,function()
 V.assert(seenPhase.rest and seenPhase.rise and seenPhase.stow,'Native same-worker sequence shows rest, departure and actual storage')
 if kind=='fishery'then V.assert(seenPhase.toShore and seenPhase.cast and seenPhase.fish and seenPhase.reel and seenPhase.toTank,'Native fisherman actually visits shore and returns caught fish to tank')
 elseif kind=='mason'then V.assert(seenPhase.toBench and seenPhase.cut and seenPhase.toStack,'Native mason cuts reserved stone and really carries it to the stack')
 else V.assert(seenPhase.rideIn and seenPhase.mine and seenPhase.rideOut and seenPhase.toTank,'Native miner really enters/exits mine and unloads at yard')end
 V.assert(mealSeen and mealReturned,'Same professional really eats and returns without changing identity')
 V.assert(carrierSeen,'Ordinary carrier actually picks up this professional output')
 V.assert(#records>=12,'Native sequence retains held actual-state captures and stock changes')
 local f=File('tests/life/evidence/visual/'..run..'-states.json',FILE_WRITE);f:WriteString(cjson.encode({records=records,trace=trace,clipFrames=clipFrames,site=b.site,seenPhase=seenPhase,controlled=true,capture="Snapshots held>=3 renders; continuous clip every2 renders and tagged with previous render state"}));f:Close();V.finish()
end)
